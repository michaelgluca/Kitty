# Shared helper. Sourced, not executed.
#
# scan <description> <file-list> <extended-regex>
#   Prints matches and returns 1 if any were found, 0 otherwise.
#   Uses OUTPUT, not exit status: `git ls-files | xargs -r grep` exits 0 when the
#   input is empty because xargs never runs grep, which silently inverts the test.
scan() {
  local desc="$1" files="$2" pattern="$3" hits
  [ -z "$files" ] && return 0
  hits=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -nE "$pattern" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $desc"
    printf '%s\n' "$hits" | sed 's/^/    /'
    return 1
  fi
  return 0
}
