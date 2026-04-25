#!/usr/bin/env bash
# Monskills envio-cloud auth gate.
# Usage: check-envio-auth.sh <mode>
#   mode = session-start | pre-tool
#
# envio-cloud requires, in order:
#   1. envio-cloud CLI installed
#   2. gh (GitHub) CLI installed — needed to push indexer repos to GitHub,
#      which is where Envio Cloud deploys from
#   3. gh authenticated
#   4. envio-cloud authenticated
#
# monskills is for interactive developer use, not CI — no headless/token
# bypass is provided.
#
# Fail-safe: on any unhandled error the script exits 0 so the hook never
# blocks the session or a tool call because of a bug in this script.

MODE="${1:-session-start}"

if [ "${MONSKILLS_SKIP_CLI_CHECK:-0}" = "1" ]; then
  exit 0
fi

CACHE_DIR="${HOME}/.cache/monskills"
ENVIO_INSTALL_CACHE="${CACHE_DIR}/envio-install.status"
GH_INSTALL_CACHE="${CACHE_DIR}/gh-install.status"
DEBUG_LOG="${CACHE_DIR}/hook-debug.log"
# Claude Code runs hooks with a stripped PATH that excludes node-version-manager
# bin dirs (nvm, pnpm, volta, etc). "ok" is cached for 24h; "missing" for only
# 60s so a failed probe under stripped PATH doesn't stick if the user later
# runs the hook from an interactive shell.
INSTALL_TTL_OK=86400
INSTALL_TTL_MISSING=60

mkdir -p "$CACHE_DIR" 2>/dev/null

# --- Augment PATH with common node-version-manager bin dirs ---
# Claude Code starts hooks with a minimal PATH. Add the places users commonly
# install global CLIs so `command -v envio-cloud` / `command -v gh` work.
augment_path() {
  local extra="$HOME/.local/bin:$HOME/.volta/bin:$HOME/.pnpm/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin"

  # Current nvm symlink (some setups use ~/.nvm/current, others ~/nvm/current)
  for d in "$HOME/.nvm/current/bin" "$HOME/nvm/current/bin"; do
    [ -d "$d" ] && extra="$d:$extra"
  done

  # Every installed nvm node version (newest first wins)
  if [ -d "$HOME/.nvm/versions/node" ]; then
    for d in "$HOME/.nvm/versions/node"/*/bin; do
      [ -d "$d" ] && extra="$d:$extra"
    done
  fi

  export PATH="$extra:$PATH"
}

augment_path

# --- Generic install check, cached with split TTLs ---
# args: <binary-name> <cache-file>
check_install() {
  local bin="$1"
  local cache="$2"
  if [ -f "$cache" ]; then
    local mtime now age cached
    mtime=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
    [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0
    now=$(date +%s)
    [[ "$now" =~ ^[0-9]+$ ]] || now=0
    age=$((now - mtime))
    cached=$(cat "$cache" 2>/dev/null)
    if [ "$cached" = "ok" ] && [ "$age" -lt "$INSTALL_TTL_OK" ]; then
      printf 'ok'
      return
    fi
    if [ "$cached" = "missing" ] && [ "$age" -lt "$INSTALL_TTL_MISSING" ]; then
      printf 'missing'
      return
    fi
  fi
  if command -v "$bin" >/dev/null 2>&1; then
    printf 'ok' > "$cache" 2>/dev/null
    printf 'ok'
    return
  fi
  # Last-chance fallback: re-probe inside a shell that has sourced the user's
  # nvm / rc files. Catches setups where the binary lives under an nvm version
  # dir that augment_path didn't guess (e.g. a custom NVM_DIR).
  if bash -c '
    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    [ -s "$HOME/.bashrc" ] && . "$HOME/.bashrc" >/dev/null 2>&1
    command -v '"$bin"' >/dev/null 2>&1
  ' 2>/dev/null; then
    printf 'ok' > "$cache" 2>/dev/null
    printf 'ok'
    return
  fi
  printf 'missing' > "$cache" 2>/dev/null
  printf 'missing'
}

check_envio_install() { check_install envio-cloud "$ENVIO_INSTALL_CACHE"; }
check_gh_install()    { check_install gh "$GH_INSTALL_CACHE"; }

# --- Envio auth check, uncached (local file read, fast) ---
check_envio_auth() {
  if command -v envio-cloud >/dev/null 2>&1 && envio-cloud token >/dev/null 2>&1; then
    printf 'ok'
  else
    printf 'logged-out'
  fi
}

# --- gh auth check, uncached ---
check_gh_auth() {
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    printf 'ok'
  else
    printf 'logged-out'
  fi
}

# --- Debug log (writes to ~/.cache/monskills/hook-debug.log, never stdout) ---
debug_log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" >> "$DEBUG_LOG" 2>/dev/null
}

# --- Extract tool_input.command from PreToolUse stdin ---
extract_command() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.command // ""' 2>/dev/null
  else
    # Fallback: shell-regex extraction. Not a full JSON parser, but sufficient
    # to pull the command value for substring matching.
    sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
  fi
}

# --- Decide whether a shell command string invokes envio-cloud ---
# Tokenizes on shell separators, strips leading env-var assignments and npx,
# then checks if the first word is `envio-cloud`.
command_invokes_envio() {
  local cmd="$1"
  [ -z "$cmd" ] && return 1
  local normalized
  normalized=$(printf '%s' "$cmd" | sed -E 's/(&&|\|\||[;|&])/\n/g')
  local chunk trimmed first_word
  while IFS= read -r chunk; do
    trimmed=$(printf '%s' "$chunk" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//; s/^npx[[:space:]]+//')
    first_word=$(printf '%s' "$trimmed" | awk '{print $1}')
    if [ "$first_word" = "envio-cloud" ]; then
      return 0
    fi
  done <<EOF
$normalized
EOF
  return 1
}

# --- JSON-escape a string ---
json_string() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$1"
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rs .
  else
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    printf '"%s"' "$s"
  fi
}

emit_session_context() {
  local envio_install="$1" gh_install="$2" gh_auth="$3" envio_auth="$4"
  if [ "$envio_install" = "ok" ] && [ "$gh_install" = "ok" ] \
     && [ "$gh_auth" = "ok" ] && [ "$envio_auth" = "ok" ]; then
    exit 0
  fi

  local envio_install_line gh_install_line gh_auth_line envio_auth_line

  if [ "$envio_install" = "ok" ]; then
    envio_install_line="- envio-cloud install: OK"
  else
    envio_install_line="- envio-cloud install: NOT INSTALLED. Do NOT install it yourself. Ask the user to run: npm install -g envio-cloud"
  fi

  if [ "$gh_install" = "ok" ]; then
    gh_install_line="- gh (GitHub CLI) install: OK"
  else
    gh_install_line="- gh (GitHub CLI) install: NOT INSTALLED. envio-cloud deploys from GitHub and needs gh to push the repo. Do NOT install it yourself. Ask the user to install gh (e.g. 'brew install gh' on macOS, or see https://cli.github.com/)."
  fi

  if [ "$gh_auth" = "ok" ]; then
    gh_auth_line="- gh login: OK"
  else
    gh_auth_line="- gh login: not detected at session start. Ask the user to run: gh auth login."
  fi

  if [ "$envio_auth" = "ok" ]; then
    envio_auth_line="- envio-cloud login: OK"
  else
    envio_auth_line="- envio-cloud login: not detected at session start. Ask the user to run: envio-cloud login (browser flow, 30-day session)."
  fi

  local msg
  msg="Envio Cloud CLI prereq status (checked at session start):
${envio_install_line}
${gh_install_line}
${gh_auth_line}
${envio_auth_line}

If any item is missing, ask the user to run the suggested command — never run installs or logins yourself. If the user says they've resolved something during this session, go ahead and retry; the tool gate re-checks on each call."
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$(json_string "$msg")"
}

emit_deny() {
  local reason="$1"
  debug_log "DENY: $reason | PATH=$PATH"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$(json_string "$reason")"
}

case "$MODE" in
  session-start)
    envio_install=$(check_envio_install)
    gh_install=$(check_gh_install)
    gh_auth=$(check_gh_auth)
    envio_auth=$(check_envio_auth)
    emit_session_context "$envio_install" "$gh_install" "$gh_auth" "$envio_auth"
    ;;
  pre-tool)
    cmd=$(extract_command)
    if ! command_invokes_envio "$cmd"; then
      exit 0
    fi
    if [ "$(check_envio_install)" != "ok" ]; then
      emit_deny "envio-cloud is not installed. Ask the user to run: npm install -g envio-cloud. Do not install it yourself."
      exit 0
    fi
    if [ "$(check_gh_install)" != "ok" ]; then
      emit_deny "envio-cloud requires the GitHub CLI (gh) to push the indexer repo to GitHub. Ask the user to install gh (e.g. 'brew install gh' on macOS, or see https://cli.github.com/). Do not install it yourself."
      exit 0
    fi
    if [ "$(check_gh_auth)" != "ok" ]; then
      emit_deny "gh is not authenticated. envio-cloud needs gh to push the indexer repo to GitHub. Ask the user to run: gh auth login, then retry."
      exit 0
    fi
    if [ "$(check_envio_auth)" != "ok" ]; then
      emit_deny "envio-cloud requires login. Ask the user to run: envio-cloud login (browser flow, 30-day session), then retry."
      exit 0
    fi
    ;;
esac

exit 0
