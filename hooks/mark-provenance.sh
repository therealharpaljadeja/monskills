#!/usr/bin/env bash
# Monskills build-provenance marker.
# Usage: mark-provenance.sh <mode>   (mode = pre-tool)
#
# PreToolUse(Bash): when the agent commits inside a Monad dApp project, rewrite
# the `git commit` command so it carries a `Built-with: monskills` trailer. The
# marker therefore lands in the commit message (permanent git history,
# searchable, survives working-tree cleanup) without writing any file.
#
# This is enforcement that does NOT depend on the model: the harness applies the
# rewrite, so a weak model that "forgets" the provenance step cannot miss it.
# It is silent — `updatedInput` with no `permissionDecision` defers to the
# normal permission flow, and no stdout reaches the transcript.
#
# Fail-safe: on ANY uncertainty or error the script exits 0 with no output, so
# the developer's commit always proceeds UNMODIFIED. It must never block or
# corrupt a commit.

MODE="${1:-pre-tool}"

# Honour the same global escape hatch as the other monskills hooks, plus a
# dedicated one for this marker.
if [ "${MONSKILLS_SKIP_MARK:-0}" = "1" ] || [ "${MONSKILLS_SKIP_CLI_CHECK:-0}" = "1" ]; then
  exit 0
fi

[ "$MODE" = "pre-tool" ] || exit 0

TRAILER="Built-with: monskills"

INPUT=$(cat)
[ -n "$INPUT" ] || exit 0

# --- Extract a field from the PreToolUse stdin JSON ---
json_field() {
  # $1 = jq path (e.g. .tool_input.command)
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$1 // \"\"" 2>/dev/null
  else
    # Best-effort: pull the first matching "key":"value". Only handles the flat
    # shapes we care about; if it fails we just don't mark (fail-safe).
    local key
    key=$(printf '%s' "$1" | sed -E 's/.*\.([A-Za-z_]+)$/\1/')
    printf '%s' "$INPUT" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\(\([^\"\\]\|\\\\.\)*\)\".*/\1/p" | head -n1
  fi
}

# --- JSON-encode a string for safe emission ---
json_string() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read()))' <<< "$1"
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

CMD=$(json_field '.tool_input.command')
CWD=$(json_field '.cwd')
[ -n "$CMD" ] || exit 0

# Only act on a `git commit ...` invocation. Global options may sit between
# `git` and the `commit` subcommand — `git -C <path> commit`, `git -c k=v
# commit`, `git --git-dir <path> commit`, `git -p commit`, etc. — and agents
# pick whichever form is convenient, so the matcher must allow them.
#
# An option "unit" is either an arg-taking global option plus its value
# (-C/-c/--git-dir/... <arg>) or any other lone `-flag`. We require a trailing
# separator after `commit` (every agent-issued `git commit -m ...` has one),
# which also excludes the distinct `git commit-tree` / `git commit-graph`
# subcommands.
GIT_COMMIT_RE='(^|[^[:alnum:]_])git[[:space:]]+((((-C|-c|--git-dir|--work-tree|--namespace|--super-prefix|--exec-path)[[:space:]]+[^[:space:]]+|-[^[:space:]]+)[[:space:]]+)*)commit[[:space:]]'

printf '%s' "$CMD" | grep -Eq "$GIT_COMMIT_RE" || exit 0

# Idempotent: never double-stamp.
case "$CMD" in
  *"$TRAILER"*) exit 0 ;;
esac

# Resolve the repo root so the fingerprint check is scoped to the project.
[ -n "$CWD" ] && [ -d "$CWD" ] || CWD="$PWD"
ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
[ -n "$ROOT" ] || ROOT="$CWD"

# --- Only stamp genuine Monad dApp projects ---
# Skips the monskills repo / the plugin itself, and any repo that shows no Monad
# fingerprint. A miss just means no marker (safe); a rare false positive only
# adds an innocuous trailer.
is_monad_project() {
  local root="$1"
  [ -d "$root" ] || return 1

  # Never stamp the monskills repo or any Claude plugin repo.
  [ -f "$root/.claude-plugin/marketplace.json" ] && return 1
  [ -f "$root/.claude-plugin/plugin.json" ] && return 1

  # Monad fingerprint. Restricted to code/config files; markdown is excluded so
  # prose mentioning "monad" never triggers it. We deliberately do NOT match a
  # bare "monad" (collides with fp-ts/category-theory code). Signals:
  #   - named chains, camelCase + hyphen + underscore: monadTestnet,
  #     monad-testnet, monad_testnet (the underscore form is how Foundry
  #     [rpc_endpoints] keys are conventionally written), same for mainnet.
  #   - the official monad.xyz domain — catches RPC URLs like
  #     testnet-rpc.monad.xyz / rpc.monad.xyz even when no chain name/id is present
  #     (e.g. a contracts-only Foundry project before any frontend exists).
  #   - explicit testnet id 10143, or a chainId of 143 (mainnet).
  local pat='monadTestnet|monadMainnet|monad[-_](testnet|mainnet)|monad\.xyz|10143|(chainId|"chainId"|id)[[:space:]]*[:=][[:space:]]*143([^0-9]|$)'

  if command -v git >/dev/null 2>&1 &&
     git -C "$root" grep -I -l -E "$pat" -- \
       '*.ts' '*.tsx' '*.js' '*.jsx' '*.cjs' '*.mjs' '*.json' '*.toml' '*.sol' >/dev/null 2>&1; then
    return 0
  fi

  # Fallback for untracked files (e.g. a brand-new scaffold not yet added).
  if grep -rIlE "$pat" \
       --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
       --include='*.cjs' --include='*.mjs' --include='*.json' --include='*.toml' --include='*.sol' \
       "$root" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

is_monad_project "$ROOT" || exit 0

# --- Rewrite: insert the trailer flag into the FIRST `git commit` invocation ---
# Inserting right after the `commit` token (not at the end of the line) keeps it
# from bleeding into a later chained command such as `&& git push`. \2 re-emits
# any global options (`-C <path>`, `-c k=v`, ...) verbatim so the rewritten form
# is `git <global-opts> commit --trailer "..." ...`.
NEWCMD=$(printf '%s' "$CMD" | sed -E "s/${GIT_COMMIT_RE}/\1git \2commit --trailer \"${TRAILER}\" /")

# If nothing changed (unusual command shape), leave it alone.
[ "$NEWCMD" != "$CMD" ] || exit 0

# Emit the rewrite WITHOUT a permissionDecision so the normal permission flow
# still applies (we are not auto-approving the commit).
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":%s}}}\n' "$(json_string "$NEWCMD")"
exit 0
