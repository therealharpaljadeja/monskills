#!/bin/bash

# Vercel Deployment Script (via claimable deploy endpoint)
# Usage: ./deploy.sh [project-path]
# No Vercel CLI or authentication required.
# Returns: Preview URL and Claim URL

set -euo pipefail

DEPLOY_ENDPOINT="https://claude-skills-deploy.vercel.com/api/deploy"

# Detect framework from package.json
detect_framework() {
  local pkg_json="$1"

  if [ ! -f "$pkg_json" ]; then
    echo "null"
    return
  fi

  local content=$(cat "$pkg_json")

  has_dep() { echo "$content" | grep -q "\"$1\""; }
  has_prefix() { echo "$content" | grep -q "\"$1"; }

  # Order matters — check more specific frameworks first
  if has_dep "next"; then echo "nextjs"; return; fi
  if has_prefix "@remix-run/"; then echo "remix"; return; fi
  if has_dep "gatsby"; then echo "gatsby"; return; fi
  if has_prefix "@react-router/"; then echo "react-router"; return; fi
  if has_dep "astro"; then echo "astro"; return; fi
  if has_dep "@sveltejs/kit"; then echo "sveltekit-1"; return; fi
  if has_dep "svelte"; then echo "svelte"; return; fi
  if has_dep "nuxt"; then echo "nuxtjs"; return; fi
  if has_dep "@solidjs/start"; then echo "solidstart-1"; return; fi
  if has_dep "@angular/core"; then echo "angular"; return; fi
  if has_dep "react-scripts"; then echo "create-react-app"; return; fi
  if has_dep "vite"; then echo "vite"; return; fi

  echo "null"
}

# Parse arguments
INPUT_PATH="${1:-.}"

# Create temp directory for packaging
TEMP_DIR=$(mktemp -d)
TARBALL="$TEMP_DIR/project.tgz"
CLEANUP_TEMP=true

cleanup() {
  if [ "$CLEANUP_TEMP" = true ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

echo "Preparing deployment..." >&2

FRAMEWORK="null"

if [ -f "$INPUT_PATH" ] && [[ "$INPUT_PATH" == *.tgz ]]; then
  echo "Using provided tarball..." >&2
  TARBALL="$INPUT_PATH"
  CLEANUP_TEMP=false
elif [ -d "$INPUT_PATH" ]; then
  PROJECT_PATH=$(cd "$INPUT_PATH" && pwd)
  FRAMEWORK=$(detect_framework "$PROJECT_PATH/package.json")

  echo "Packaging project..." >&2
  # Use git ls-files to archive only source-controlled files.
  # This is safer than a denylist (--exclude) because it ensures build artifacts,
  # secrets, and other untracked files are never sent to Vercel — matching how
  # Vercel's standard build flow works (it only sees your git repo).
  # Unlike `git archive`, `git ls-files` includes uncommitted changes to tracked files.
  git -C "$PROJECT_PATH" ls-files -z | tar -czf "$TARBALL" --null -T - -C "$PROJECT_PATH"
else
  echo "Error: Input must be a directory or a .tgz file" >&2
  exit 1
fi

if [ "$FRAMEWORK" != "null" ]; then
  echo "Detected framework: $FRAMEWORK" >&2
fi

# Deploy
echo "Deploying..." >&2
RESPONSE=$(curl -s -X POST "$DEPLOY_ENDPOINT" -F "file=@$TARBALL" -F "framework=$FRAMEWORK")

# Check for error
if echo "$RESPONSE" | grep -q '"error"'; then
  ERROR_MSG=$(echo "$RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "Error: $ERROR_MSG" >&2
  exit 1
fi

# Extract URLs
PREVIEW_URL=$(echo "$RESPONSE" | grep -o '"previewUrl":"[^"]*"' | cut -d'"' -f4)
CLAIM_URL=$(echo "$RESPONSE" | grep -o '"claimUrl":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PREVIEW_URL" ]; then
  echo "Error: Could not extract preview URL from response" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "Deployment started. Waiting for build to complete..." >&2

# Poll until build completes (5xx = still building)
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$PREVIEW_URL")
  if [ "$HTTP_STATUS" -lt 500 ]; then
    echo "" >&2
    echo "Deployment ready!" >&2
    break
  fi
  echo "Building... (attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS)" >&2
  sleep 5
  ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "" >&2
  echo "Warning: Timed out waiting for deployment, but it may still be building." >&2
fi

echo "" >&2
echo "Preview URL: $PREVIEW_URL" >&2
echo "Claim URL:   $CLAIM_URL" >&2

# Output JSON for programmatic use
echo "$RESPONSE"
