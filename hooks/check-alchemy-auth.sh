#!/usr/bin/env bash
# Monskills alchemy CLI auth gate.
# Usage: check-alchemy-auth.sh <mode>
#   mode = session-start | pre-tool
#
# `alchemy` (@alchemy/cli) requires:
#   1. CLI installed at v0.17.0 or newer (`npm install -g @alchemy/cli@latest`)
#   2. Logged in (`alchemy auth` — browser OAuth, only the user can complete it)
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
ALCHEMY_INSTALL_CACHE="${CACHE_DIR}/alchemy-install.status"
DEBUG_LOG="${CACHE_DIR}/hook-debug.log"
# Claude Code runs hooks with a stripped PATH that excludes node-version-manager
# bin dirs. "ok" is cached for 24h; "missing" for only 60s so a failed probe
# under stripped PATH doesn't stick if the user later runs the hook from an
# interactive shell.
INSTALL_TTL_OK=86400
INSTALL_TTL_MISSING=60

# Minimum @alchemy/cli version monskills supports.
MIN_ALCHEMY_VERSION="0.17.0"

mkdir -p "$CACHE_DIR" 2>/dev/null

# --- Augment PATH with common node-version-manager bin dirs ---
augment_path() {
  local extra="$HOME/.local/bin:$HOME/.volta/bin:$HOME/.pnpm/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin"

  for d in "$HOME/.nvm/current/bin" "$HOME/nvm/current/bin"; do
    [ -d "$d" ] && extra="$d:$extra"
  done

  if [ -d "$HOME/.nvm/versions/node" ]; then
    for d in "$HOME/.nvm/versions/node"/*/bin; do
      [ -d "$d" ] && extra="$d:$extra"
    done
  fi

  export PATH="$extra:$PATH"
}

augment_path

# --- Generic install check, cached with split TTLs ---
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

check_alchemy_install() { check_install alchemy "$ALCHEMY_INSTALL_CACHE"; }

# --- Semver compare: version_ge A B -> 0 (true) if A >= B, else 1 ---
version_ge() {
  local a="$1" b="$2" i x y
  local IFS=.
  local -a av=($a) bv=($b)
  for i in 0 1 2; do
    x=${av[i]:-0}; y=${bv[i]:-0}
    x=${x%%[!0-9]*}; y=${y%%[!0-9]*}
    x=${x:-0}; y=${y:-0}
    if [ "$x" -gt "$y" ]; then return 0; fi
    if [ "$x" -lt "$y" ]; then return 1; fi
  done
  return 0
}

# --- Alchemy CLI version check, uncached. ---
# Returns: "ok" | "outdated:<found>" | "unknown".
# Fail-open: returns "unknown" when the version can't be determined, so the
# gate never blocks on an ambiguous probe (consistent with the fail-safe
# philosophy above). Only a positively-detected old version blocks.
check_alchemy_version() {
  local found
  command -v alchemy >/dev/null 2>&1 || { printf 'unknown'; return; }
  found=$(alchemy --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  [ -n "$found" ] || { printf 'unknown'; return; }
  if version_ge "$found" "$MIN_ALCHEMY_VERSION"; then
    printf 'ok'
  else
    printf 'outdated:%s' "$found"
  fi
}

# --- Alchemy auth check, uncached. `alchemy auth status` is the canonical
#     session check. Exit 0 = signed in.
check_alchemy_auth() {
  if command -v alchemy >/dev/null 2>&1 && alchemy auth status >/dev/null 2>&1; then
    printf 'ok'
  else
    printf 'logged-out'
  fi
}

debug_log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" >> "$DEBUG_LOG" 2>/dev/null
}

# --- Extract tool_input.command from PreToolUse stdin ---
extract_command() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.command // ""' 2>/dev/null
  else
    sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
  fi
}

# --- Decide whether a shell command string invokes alchemy ---
# Tokenizes on shell separators, strips leading env-var assignments,
# then checks if the first word is `alchemy`. Also matches `npx @alchemy/cli`
# (and yarn/pnpm dlx / bunx variants) so users running without a global
# install are still gated.
command_invokes_alchemy() {
  local cmd="$1"
  [ -z "$cmd" ] && return 1
  local normalized
  normalized=$(printf '%s' "$cmd" | sed -E 's/(&&|\|\||[;|&])/\n/g')
  local chunk trimmed first_word second_word third_word
  while IFS= read -r chunk; do
    trimmed=$(printf '%s' "$chunk" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//')
    first_word=$(printf '%s' "$trimmed" | awk '{print $1}')
    second_word=$(printf '%s' "$trimmed" | awk '{print $2}')
    third_word=$(printf '%s' "$trimmed" | awk '{print $3}')

    # Direct `alchemy ...`
    if [ "$first_word" = "alchemy" ]; then
      return 0
    fi

    # `npx @alchemy/cli@... <subcommand>` or `npx @alchemy/cli <subcommand>`
    if [ "$first_word" = "npx" ]; then
      case "$second_word" in
        @alchemy/cli|@alchemy/cli@*) return 0 ;;
      esac
    fi

    # `pnpm dlx @alchemy/cli ...` / `yarn dlx @alchemy/cli ...` / `bunx @alchemy/cli ...`
    if { [ "$first_word" = "pnpm" ] || [ "$first_word" = "yarn" ]; } && [ "$second_word" = "dlx" ]; then
      case "$third_word" in
        @alchemy/cli|@alchemy/cli@*) return 0 ;;
      esac
    fi
    if [ "$first_word" = "bunx" ]; then
      case "$second_word" in
        @alchemy/cli|@alchemy/cli@*) return 0 ;;
      esac
    fi
  done <<EOF
$normalized
EOF
  return 1
}

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
  local alchemy_install="$1" alchemy_auth="$2" alchemy_version="$3"
  local version_outdated=0
  case "$alchemy_version" in outdated:*) version_outdated=1 ;; esac

  if [ "$alchemy_install" = "ok" ] && [ "$alchemy_auth" = "ok" ] && [ "$version_outdated" = 0 ]; then
    exit 0
  fi

  local alchemy_install_line alchemy_auth_line alchemy_version_line=""

  if [ "$alchemy_install" = "ok" ]; then
    alchemy_install_line="- alchemy (@alchemy/cli) install: OK"
  else
    alchemy_install_line="- alchemy (@alchemy/cli) install: NOT INSTALLED. Do NOT install it yourself. Ask the user to run: npm install -g @alchemy/cli@latest (or pnpm add -g @alchemy/cli)."
  fi

  if [ "$version_outdated" = 1 ]; then
    alchemy_version_line="
- alchemy (@alchemy/cli) version: ${alchemy_version#outdated:} is too old — monskills requires v${MIN_ALCHEMY_VERSION} or newer. Do NOT upgrade it yourself. Ask the user to run: npm install -g @alchemy/cli@latest."
  fi

  if [ "$alchemy_auth" = "ok" ]; then
    alchemy_auth_line="- alchemy auth: OK"
  else
    alchemy_auth_line="- alchemy auth: not detected at session start. Ask the user to run: alchemy auth (browser OAuth flow — only the user can complete it). After signing in the CLI will prompt to pick an Alchemy app for RPC."
  fi

  local msg
  msg="Alchemy CLI prereq status (checked at session start):
${alchemy_install_line}${alchemy_version_line}
${alchemy_auth_line}

If any item is missing or outdated, ask the user to run the suggested command — never run installs, upgrades, or logins yourself. If the user says they've resolved something during this session, go ahead and retry; the tool gate re-checks on each call."
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$(json_string "$msg")"
}

emit_deny() {
  local reason="$1"
  debug_log "DENY: $reason | PATH=$PATH"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$(json_string "$reason")"
}

case "$MODE" in
  session-start)
    alchemy_install=$(check_alchemy_install)
    alchemy_auth=$(check_alchemy_auth)
    if [ "$alchemy_install" = "ok" ]; then
      alchemy_version=$(check_alchemy_version)
    else
      alchemy_version="unknown"
    fi
    emit_session_context "$alchemy_install" "$alchemy_auth" "$alchemy_version"
    ;;
  pre-tool)
    cmd=$(extract_command)
    if ! command_invokes_alchemy "$cmd"; then
      exit 0
    fi
    if [ "$(check_alchemy_install)" != "ok" ]; then
      emit_deny "alchemy (@alchemy/cli) is not installed. Ask the user to run: npm install -g @alchemy/cli@latest. Do not install it yourself."
      exit 0
    fi
    alchemy_version=$(check_alchemy_version)
    case "$alchemy_version" in
      outdated:*)
        emit_deny "alchemy (@alchemy/cli) is v${alchemy_version#outdated:}, but monskills requires v${MIN_ALCHEMY_VERSION} or newer. Ask the user to run: npm install -g @alchemy/cli@latest (do not upgrade it yourself), then retry."
        exit 0
        ;;
    esac
    if [ "$(check_alchemy_auth)" != "ok" ]; then
      emit_deny "alchemy requires sign-in. Ask the user to run: alchemy auth (browser OAuth flow, only the user can complete it), then retry."
      exit 0
    fi
    ;;
esac

exit 0
