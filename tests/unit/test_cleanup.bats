#!/usr/bin/env bats

# Phase 5 TDD: tests for .github/scripts/delete_branch_pr_tag.sh
# Tests cleanup script used on bump workflow failure/cancel.
# Script args: $1 = repo (owner/name), $2 = branch name, $3 = version (no v prefix)

SCRIPT_PATH=".github/scripts/delete_branch_pr_tag.sh"

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
  export GH_MOCK_LOG="$TMPDIR/gh_mock_cleanup_${BATS_TEST_NUMBER}.log"
  rm -f "$GH_MOCK_LOG"

  # Test values matching workflow call: $src "$REPO" "$BRANCH" "$VERSION"
  REPO="qte77/gha-cross-repo-issue-sync"
  BRANCH="bump-42-main"
  VERSION="1.0.1"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
}

gh_calls() {
  cat "$GH_MOCK_LOG" 2>/dev/null || echo ""
}

# Run the cleanup script with mock gh, passing positional args
run_cleanup() {
  # Create a wrapper that defines the mock and then sources the script
  bash -c "
    gh() { echo \"gh \$*\" >> \"$GH_MOCK_LOG\"; }
    export -f gh
    source \"$BATS_TEST_DIRNAME/../../$SCRIPT_PATH\"
  " _ "$@"
}

@test "cleanup script closes PR by branch name" {
  run_cleanup "$REPO" "$BRANCH" "$VERSION"
  gh_calls | grep -q "gh pr close $BRANCH"
}

@test "cleanup script deletes remote branch" {
  run_cleanup "$REPO" "$BRANCH" "$VERSION"
  gh_calls | grep -q "gh api repos/$REPO/git/refs/heads/$BRANCH -X DELETE"
}

@test "cleanup script deletes release by tag" {
  run_cleanup "$REPO" "$BRANCH" "$VERSION"
  gh_calls | grep -q "gh release delete v$VERSION"
}

@test "cleanup script deletes tag" {
  run_cleanup "$REPO" "$BRANCH" "$VERSION"
  gh_calls | grep -q "gh api repos/$REPO/git/refs/tags/v$VERSION -X DELETE"
}

@test "cleanup script does not fail on empty args" {
  run_cleanup "" "" ""
}
