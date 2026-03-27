#!/usr/bin/env bash
# gh_mock.bash — Mock gh CLI for BATS tests.
# Records calls to GH_MOCK_LOG for assertion. Returns canned responses.
# Set GH_MOCK_SOURCE_JSON / GH_MOCK_MIRROR_JSON for issue list responses.

export GH_MOCK_LOG="${GH_MOCK_LOG:-$BATS_TMPDIR/gh_mock.log}"

gh() {
  echo "gh $*" >> "$GH_MOCK_LOG"

  case "$1 $2" in
    "issue list")
      # Detect which repo is being queried via -R flag
      local args="$*"
      if [[ "$args" == *"$GH_MOCK_TRACKER_REPO"* && -n "${GH_MOCK_MIRROR_JSON:-}" ]]; then
        echo "$GH_MOCK_MIRROR_JSON"
      elif [[ -n "${GH_MOCK_SOURCE_JSON:-}" ]]; then
        echo "$GH_MOCK_SOURCE_JSON"
      else
        echo "[]"
      fi
      ;;
    "issue create") echo "https://github.com/mock/repo/issues/99" ;;
    "issue close")  echo "" ;;
    "issue reopen") echo "" ;;
    "issue edit")   echo "" ;;
    "issue comment") echo "" ;;
    "pr list")
      if [[ -n "${GH_MOCK_PR_JSON:-}" ]]; then
        echo "$GH_MOCK_PR_JSON"
      else
        echo "[]"
      fi
      ;;
    "issue view")
      if [[ -n "${GH_MOCK_ISSUE_JSON:-}" ]]; then
        echo "$GH_MOCK_ISSUE_JSON"
      else
        echo '{"body":"Source: qte77/test-repo#1","title":"Test issue","number":10}'
      fi
      ;;
    "project item-add") echo "" ;;
    "api "*)
      local args="$*"
      # Return mock comments for issue API calls
      if [[ "$args" == *"/comments"* ]]; then
        if [[ "$args" == *"$GH_MOCK_TRACKER_REPO"* && -n "${GH_MOCK_MIRROR_COMMENTS:-}" ]]; then
          echo "$GH_MOCK_MIRROR_COMMENTS"
        elif [[ -n "${GH_MOCK_SOURCE_COMMENTS:-}" ]]; then
          echo "$GH_MOCK_SOURCE_COMMENTS"
        else
          echo "[]"
        fi
      else
        echo "{}"
      fi
      ;;
    *)
      echo "UNMOCKED: gh $*" >&2
      return 1
      ;;
  esac
}
export -f gh
