#!/usr/bin/env bash
# Monskills para CLI auth gate.
# Usage: check-para-auth.sh <mode>
#   mode = session-start | pre-tool
#
# `para` (@getpara/cli) requires:
#   1. CLI installed (`npm install -g @getpara/cli`)
#   2. Logged in (`para login` — browser OAuth, only the user can complete it)
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
PARA_INSTALL_CACHE="${CACHE_DIR}/para-install.status"
DEBUG_LOG="${CACHE_DIR}/hook-debug.log"
# Claude Code runs hooks with a stripped PATH that excludes node-version-manager
# bin dirs. "ok" is cached for 24h; "missing" for only 60s so a failed probe
# under stripped PATH doesn't stick if the user later runs the hook from an
# interactive shell.
INSTALL_TTL_OK=86400
INSTALL_TTL_MISSING=60

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

check_para_install() { check_install para "$PARA_INSTALL_CACHE"; }

# --- Para auth check, uncached. `para auth status` is the canonical session
#     check (server round-trip). Exit 0 = valid session.
check_para_auth() {
  if command -v para >/dev/null 2>&1 && para auth status >/dev/null 2>&1; then
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

emit_session_context() {
  local para_install="$1" para_auth="$2"
  if [ "$para_install" = "ok" ] && [ "$para_auth" = "ok" ]; then
    exit 0
  fi

  local para_install_line para_auth_line

  if [ "$para_install" = "ok" ]; then
    para_install_line="- para (@getpara/cli) install: OK"
  else
    para_install_line="- para (@getpara/cli) install: NOT INSTALLED. Do NOT install it yourself. Ask the user to run: npm install -g @getpara/cli (or pnpm add -g @getpara/cli)."
  fi

  if [ "$para_auth" = "ok" ]; then
    para_auth_line="- para login: OK"
  else
    para_auth_line="- para login: not detected at session start. Ask the user to run: para login (browser OAuth flow — only the user can complete it)."
  fi

  local msg
  msg="Para CLI prereq status (checked at session start):
${para_install_line}
${para_auth_line}

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
    para_install=$(check_para_install)
    para_auth=$(check_para_auth)
    emit_session_context "$para_install" "$para_auth"
    ;;
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
