#!/usr/bin/env bash
# Monskills para CLI auth gate.
# Usage: check-para-auth.sh <mode>
#   mode = pre-tool
#
# `para` (@getpara/cli) requires:
#   1. CLI installed (`npm install -g @getpara/cli`)
#   2. Logged in (`para login` — browser OAuth, only the user can complete it)
#
# monskills is for interactive developer use, not CI — no headless/token
# bypass is provided. Operators can set MONSKILLS_SKIP_CLI_CHECK=1 to skip all
# monskills CLI gates for a local emergency or tightly controlled environment.
#
# No SessionStart hook is registered. Checks run only when a Bash command
# actually invokes para, and each external CLI probe is time-bounded.
#
# Fail-safe: on any unhandled error the script exits 0 so the hook never
# blocks the session or a tool call because of a bug in this script.

MODE="${1:-pre-tool}"

if [ "${MONSKILLS_SKIP_CLI_CHECK:-0}" = "1" ]; then
  exit 0
fi

CACHE_DIR="${HOME}/.cache/monskills"
PARA_INSTALL_CACHE="${CACHE_DIR}/para-install.status"
DEBUG_LOG="${CACHE_DIR}/hook-debug.log"
AUTH_TIMEOUT_SECONDS="${MONSKILLS_HOOK_AUTH_TIMEOUT_SECONDS:-8}"
# Claude Code runs hooks with a stripped PATH that excludes node-version-manager
# bin dirs. "ok" is cached for 24h; "missing" for only 60s so a failed probe
# under stripped PATH doesn't stick if the user later runs the hook from an
# interactive shell.
INSTALL_TTL_OK=86400
INSTALL_TTL_MISSING=60

mkdir -p "$CACHE_DIR" 2>/dev/null

# Run an external probe with a small wall-clock bound. Hooks must never hang the
# session because a CLI waits on the network or tries to prompt interactively.
run_bounded() {
  local seconds="$1"
  shift

  [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=8
  [ "$seconds" -gt 0 ] || seconds=8

  "$@" >/dev/null 2>&1 &
  local pid=$!
  ( sleep "$seconds"; kill "$pid" 2>/dev/null ) &
  local watcher=$!
  local status
  wait "$pid" >/dev/null 2>&1
  status=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  return "$status"
}

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
    cached=$(sed -n '1p' "$cache" 2>/dev/null)
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

check_para_install() { check_install para "$PARA_INSTALL_CACHE"; }

# --- Para auth check, uncached and bounded. `para auth status` is the
#     canonical session check. Exit 0 = valid session.
check_para_auth() {
  if command -v para >/dev/null 2>&1 && run_bounded "$AUTH_TIMEOUT_SECONDS" para auth status; then
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
    jq -er 'if (.tool_input.command | type) == "string" then .tool_input.command else "" end' 2>/dev/null || printf ''
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    cmd = data.get("tool_input", {}).get("command", "")
    sys.stdout.write(cmd if isinstance(cmd, str) else "")
except Exception:
    pass
' 2>/dev/null
  else
    sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
  fi
}

# --- Decide whether a shell command string invokes para ---
# Tokenizes on shell separators, strips leading env-var assignments and npx,
# then checks if the first word is `para`. Also matches `npx @getpara/cli`
# (and yarn/pnpm dlx variants) so users running without a global install are
# still gated.
command_invokes_para() {
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

    # Direct `para ...`
    if [ "$first_word" = "para" ]; then
      return 0
    fi

    # `npx @getpara/cli@... <subcommand>` or `npx @getpara/cli <subcommand>`
    if [ "$first_word" = "npx" ]; then
      case "$second_word" in
        @getpara/cli|@getpara/cli@*) return 0 ;;
      esac
    fi

    # `pnpm dlx @getpara/cli ...` / `yarn dlx @getpara/cli ...` / `bunx @getpara/cli ...`
    if { [ "$first_word" = "pnpm" ] || [ "$first_word" = "yarn" ]; } && [ "$second_word" = "dlx" ]; then
      case "$third_word" in
        @getpara/cli|@getpara/cli@*) return 0 ;;
      esac
    fi
    if [ "$first_word" = "bunx" ]; then
      case "$second_word" in
        @getpara/cli|@getpara/cli@*) return 0 ;;
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

emit_deny() {
  local reason="$1"
  debug_log "DENY: $reason | PATH=$PATH"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$(json_string "$reason")"
}

case "$MODE" in
  pre-tool)
    cmd=$(extract_command)
    if ! command_invokes_para "$cmd"; then
      exit 0
    fi
    if [ "$(check_para_install)" != "ok" ]; then
      emit_deny "para (@getpara/cli) is not installed. Ask the user to run: npm install -g @getpara/cli. Do not install it yourself."
      exit 0
    fi
    if [ "$(check_para_auth)" != "ok" ]; then
      emit_deny "para requires login. Ask the user to run: para login (browser OAuth flow, only the user can complete it), then retry."
      exit 0
    fi
    ;;
esac

exit 0
