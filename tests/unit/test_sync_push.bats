#!/usr/bin/env bats

# Phase 2 TDD: tests for scripts/sync-push.sh
# Tests push sync (tracker → source repo) using mocked gh CLI.

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
  export GH_MOCK_LOG="$BATS_TMPDIR/gh_mock_$$.log"
  rm -f "$GH_MOCK_LOG"
  source "$BATS_TEST_DIRNAME/../test_helper/gh_mock.bash"
  source "$BATS_TEST_DIRNAME/../../scripts/common.sh"
  source "$BATS_TEST_DIRNAME/../../scripts/sync-push.sh"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
}

# Helper: read what gh was called with
gh_calls() {
  cat "$GH_MOCK_LOG" 2>/dev/null || echo ""
}

# --- handle_issue_closed ---

@test "handle_issue_closed closes source issue" {
  handle_issue_closed "qte77/test-repo#5" "qte77/test-repo"
  gh_calls | grep -q "gh issue close 5 -R qte77/test-repo"
}

@test "handle_issue_closed skips tracker-only (empty ref)" {
  handle_issue_closed "" ""
  [ ! -f "$GH_MOCK_LOG" ] || [ ! -s "$GH_MOCK_LOG" ]
}

# --- handle_issue_reopened ---

@test "handle_issue_reopened reopens source issue" {
  handle_issue_reopened "qte77/test-repo#3" "qte77/test-repo"
  gh_calls | grep -q "gh issue reopen 3 -R qte77/test-repo"
}

# --- handle_issue_labeled ---

@test "handle_issue_labeled adds label to source issue" {
  handle_issue_labeled "qte77/test-repo#7" "qte77/test-repo" "bug"
  gh_calls | grep -q "gh issue edit 7 -R qte77/test-repo --add-label bug"
}

# --- handle_issue_unlabeled ---

@test "handle_issue_unlabeled removes label from source issue" {
  handle_issue_unlabeled "qte77/test-repo#7" "qte77/test-repo" "wontfix"
  gh_calls | grep -q "gh issue edit 7 -R qte77/test-repo --remove-label wontfix"
}

# --- handle_issue_edited ---

@test "handle_issue_edited updates source issue title" {
  handle_issue_edited "qte77/test-repo#2" "qte77/test-repo" "New title"
  gh_calls | grep -q 'gh issue edit 2 -R qte77/test-repo --title New title'
}

@test "handle_issue_edited handles title with special characters" {
  handle_issue_edited "qte77/test-repo#2" "qte77/test-repo" "Fix: handle 'quotes' & \"doubles\""
  gh_calls | grep -q "gh issue edit 2 -R qte77/test-repo --title"
}

# --- handle_issue_assigned ---

@test "handle_issue_assigned adds assignee to source issue" {
  handle_issue_assigned "qte77/test-repo#4" "qte77/test-repo" "octocat"
  gh_calls | grep -q "gh issue edit 4 -R qte77/test-repo --add-assignee octocat"
}

# --- handle_issue_unassigned ---

@test "handle_issue_unassigned removes assignee from source issue" {
  handle_issue_unassigned "qte77/test-repo#4" "qte77/test-repo" "octocat"
  gh_calls | grep -q "gh issue edit 4 -R qte77/test-repo --remove-assignee octocat"
}

# --- handle_issue_comment ---

@test "handle_issue_comment adds prefixed comment to source issue" {
  handle_issue_comment "qte77/test-repo#6" "qte77/test-repo" "Great progress"
  gh_calls | grep -q "gh issue comment 6 -R qte77/test-repo --body"
  # Verify prefix
  gh_calls | grep -q "\[tracker\]"
}

# --- dispatch_event ---

@test "dispatch_event routes closed action to handle_issue_closed" {
  dispatch_event "closed" "qte77/test-repo#1" "qte77/test-repo" "" "" ""
  gh_calls | grep -q "gh issue close 1"
}

@test "dispatch_event routes reopened action" {
  dispatch_event "reopened" "qte77/test-repo#1" "qte77/test-repo" "" "" ""
  gh_calls | grep -q "gh issue reopen 1"
}

@test "dispatch_event routes labeled action" {
  dispatch_event "labeled" "qte77/test-repo#1" "qte77/test-repo" "enhancement" "" ""
  gh_calls | grep -q "gh issue edit 1 -R qte77/test-repo --add-label enhancement"
}

@test "dispatch_event routes unlabeled action" {
  dispatch_event "unlabeled" "qte77/test-repo#1" "qte77/test-repo" "stale" "" ""
  gh_calls | grep -q "gh issue edit 1 -R qte77/test-repo --remove-label stale"
}

@test "dispatch_event routes edited action with title" {
  dispatch_event "edited" "qte77/test-repo#1" "qte77/test-repo" "" "Updated title" ""
  gh_calls | grep -q "gh issue edit 1 -R qte77/test-repo --title Updated title"
}

@test "dispatch_event routes assigned action" {
  dispatch_event "assigned" "qte77/test-repo#1" "qte77/test-repo" "" "" "octocat"
  gh_calls | grep -q "gh issue edit 1 -R qte77/test-repo --add-assignee octocat"
}

@test "dispatch_event routes unassigned action" {
  dispatch_event "unassigned" "qte77/test-repo#1" "qte77/test-repo" "" "" "octocat"
  gh_calls | grep -q "gh issue edit 1 -R qte77/test-repo --remove-assignee octocat"
}

@test "dispatch_event routes comment created action" {
  dispatch_event "comment_created" "qte77/test-repo#1" "qte77/test-repo" "" "" "" "Looks good"
  gh_calls | grep -q "gh issue comment 1"
}

# --- Guard: tracker-only ---

@test "dispatch_event skips when source ref is empty" {
  dispatch_event "closed" "" "" "" "" ""
  [ ! -f "$GH_MOCK_LOG" ] || [ ! -s "$GH_MOCK_LOG" ]
}

# --- Guard: dry run ---

@test "dispatch_event in dry-run mode does not call gh" {
  DRY_RUN=true dispatch_event "closed" "qte77/test-repo#1" "qte77/test-repo" "" "" ""
  [ ! -f "$GH_MOCK_LOG" ] || [ ! -s "$GH_MOCK_LOG" ]
}

@test "dispatch_event dry-run prints preview with action and ref" {
  run bash -c 'DRY_RUN=true; source "'"$BATS_TEST_DIRNAME"'/../../scripts/common.sh"; source "'"$BATS_TEST_DIRNAME"'/../../scripts/sync-push.sh"; dispatch_event "closed" "qte77/test-repo#1" "qte77/test-repo" "" "" ""'
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"closed"* ]]
  [[ "$output" == *"qte77/test-repo#1"* ]]
}

# --- Guard: unknown action ---

@test "dispatch_event prints error for unknown action" {
  run dispatch_event "invalid_action" "qte77/test-repo#1" "qte77/test-repo" "" "" ""
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Unknown action: invalid_action"
  [ ! -f "$GH_MOCK_LOG" ] || [ ! -s "$GH_MOCK_LOG" ]
}

# --- error handling ---

@test "handle_issue_closed does not crash when gh fails" {
  export GH_MOCK_FAIL_CMD="issue close"
  run handle_issue_closed "qte77/test-repo#5" "qte77/test-repo"
  # gh failure propagates but should not cause unexpected behavior
  [ "$status" -ne 0 ]
  gh_calls | grep -q "gh issue close"
}
