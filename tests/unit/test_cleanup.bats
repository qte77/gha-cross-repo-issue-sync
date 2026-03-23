#!/usr/bin/env bats

# Phase 5 TDD: tests for .github/scripts/delete_branch_pr_tag.sh
# Tests cleanup script used on bump workflow failure/cancel.

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
  export GH_MOCK_LOG="$BATS_TMPDIR/gh_mock_cleanup_$$.log"
  rm -f "$GH_MOCK_LOG"

  # Mock gh CLI
  gh() {
    echo "gh $*" >> "$GH_MOCK_LOG"
    echo ""
  }
  export -f gh

  # Mock git CLI
  git() {
    echo "git $*" >> "$GH_MOCK_LOG"
    echo ""
  }
  export -f git

  # Required env vars for cleanup script
  export GITHUB_REPOSITORY="qte77/gha-cross-repo-issue-sync"
  export CLEANUP_BRANCH="bump-42-main"
  export CLEANUP_TAG="v1.0.1"
  export CLEANUP_PR_NUMBER="10"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
}

gh_calls() {
  cat "$GH_MOCK_LOG" 2>/dev/null || echo ""
}

@test "cleanup script closes PR" {
  source "$BATS_TEST_DIRNAME/../../.github/scripts/delete_branch_pr_tag.sh"
  gh_calls | grep -q "gh pr close 10"
}

@test "cleanup script deletes remote branch" {
  source "$BATS_TEST_DIRNAME/../../.github/scripts/delete_branch_pr_tag.sh"
  gh_calls | grep -q "gh api repos/$GITHUB_REPOSITORY/git/refs/heads/$CLEANUP_BRANCH -X DELETE"
}

@test "cleanup script deletes release by tag" {
  source "$BATS_TEST_DIRNAME/../../.github/scripts/delete_branch_pr_tag.sh"
  gh_calls | grep -q "gh release delete $CLEANUP_TAG"
}

@test "cleanup script deletes tag" {
  source "$BATS_TEST_DIRNAME/../../.github/scripts/delete_branch_pr_tag.sh"
  gh_calls | grep -q "gh api repos/$GITHUB_REPOSITORY/git/refs/tags/$CLEANUP_TAG -X DELETE"
}

@test "cleanup script deletes local branch" {
  source "$BATS_TEST_DIRNAME/../../.github/scripts/delete_branch_pr_tag.sh"
  gh_calls | grep -q "git branch -D $CLEANUP_BRANCH"
}

@test "cleanup script does not fail on missing vars" {
  unset CLEANUP_PR_NUMBER
  CLEANUP_PR_NUMBER=""
  # Should still run without error (|| true guards)
  source "$BATS_TEST_DIRNAME/../../.github/scripts/delete_branch_pr_tag.sh"
}
