#!/usr/bin/env bash
# gh_mock.bash — Mock gh CLI for BATS tests.
# Records calls to GH_MOCK_LOG for assertion. Returns canned responses.

export GH_MOCK_LOG="${GH_MOCK_LOG:-$BATS_TMPDIR/gh_mock.log}"

gh() {
  echo "gh $*" >> "$GH_MOCK_LOG"

  case "$1 $2" in
    "issue close")   echo "" ;;
    "issue reopen")  echo "" ;;
    "issue edit")    echo "" ;;
    "issue comment") echo "" ;;
    "issue view")
      # Return canned issue JSON if fixture exists
      if [[ -n "${GH_MOCK_ISSUE_JSON:-}" ]]; then
        echo "$GH_MOCK_ISSUE_JSON"
      else
        echo '{"body":"Source: qte77/test-repo#1","title":"Test issue","number":10}'
      fi
      ;;
    *)
      echo "UNMOCKED: gh $*" >&2
      return 1
      ;;
  esac
}
export -f gh
