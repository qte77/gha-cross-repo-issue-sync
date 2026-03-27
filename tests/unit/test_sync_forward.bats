#!/usr/bin/env bats

# Phase 3 TDD: tests for scripts/sync-forward.sh
# Tests forward sync (repo issues → tracker mirrors + markdown).

FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
  export GH_MOCK_LOG="$BATS_TMPDIR/gh_mock_$$.log"
  export GH_MOCK_TRACKER_REPO="qte77/.github-private-project-tracker"
  export TRACKER_REPO="$GH_MOCK_TRACKER_REPO"
  export OWNER="qte77"
  export MARKDOWN_DIR="$BATS_TMPDIR/md_$$"
  mkdir -p "$MARKDOWN_DIR"
  rm -f "$GH_MOCK_LOG"

  export GH_MOCK_SOURCE_JSON="$(cat "$FIXTURES/source_issues.json")"
  export GH_MOCK_MIRROR_JSON="$(cat "$FIXTURES/mirror_issues.json")"

  source "$BATS_TEST_DIRNAME/../test_helper/gh_mock.bash"
  source "$BATS_TEST_DIRNAME/../../scripts/common.sh"
  source "$BATS_TEST_DIRNAME/../../scripts/sync-forward.sh"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
  rm -rf "$MARKDOWN_DIR"
}

gh_calls() {
  cat "$GH_MOCK_LOG" 2>/dev/null || echo ""
}

# --- find_mirror_for_ref ---

@test "find_mirror_for_ref returns mirror number when match exists" {
  result="$(find_mirror_for_ref "qte77/test-repo#1" "$GH_MOCK_MIRROR_JSON")"
  [ "$result" = "10" ]
}

@test "find_mirror_for_ref returns empty when no match" {
  result="$(find_mirror_for_ref "qte77/test-repo#999" "$GH_MOCK_MIRROR_JSON")"
  [ -z "$result" ]
}

# --- create_mirror ---

@test "create_mirror calls gh issue create with correct title and body" {
  create_mirror "test-repo" "Fix login bug" "qte77/test-repo#1"
  gh_calls | grep -q "gh issue create"
  gh_calls | grep -q "\[test-repo\] Fix login bug"
  gh_calls | grep -q "Source: qte77/test-repo#1"
}

@test "create_mirror adds repo as label" {
  create_mirror "test-repo" "Fix login bug" "qte77/test-repo#1"
  gh_calls | grep -q "\-\-label test-repo"
}

# --- close_mirror ---

@test "close_mirror calls gh issue close on mirror number" {
  close_mirror 10
  gh_calls | grep -q "gh issue close 10"
}

# --- reopen_mirror ---

@test "reopen_mirror calls gh issue reopen on mirror number" {
  reopen_mirror 11
  gh_calls | grep -q "gh issue reopen 11"
}

# --- update_mirror_title ---

@test "update_mirror_title calls gh issue edit with new title" {
  update_mirror_title 10 "[test-repo] New title"
  gh_calls | grep -q "gh issue edit 10"
  gh_calls | grep -q "\-\-title"
}

# --- sync_mirror_labels ---

@test "sync_mirror_labels adds missing labels" {
  sync_mirror_labels 10 "bug,enhancement" "bug"
  gh_calls | grep -q "\-\-add-label enhancement"
}

@test "sync_mirror_labels removes extra labels, skips repo label" {
  sync_mirror_labels 10 "bug" "bug,stale" "test-repo"
  gh_calls | grep -q "\-\-remove-label stale"
  # Should NOT remove the repo label
  ! gh_calls | grep -q "\-\-remove-label test-repo"
}

@test "sync_mirror_labels no-ops when labels match" {
  sync_mirror_labels 10 "bug" "bug"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "issue edit"
}

# --- sync_mirror_assignees ---

@test "sync_mirror_assignees adds missing assignees" {
  sync_mirror_assignees 10 "octocat,alice" "octocat"
  gh_calls | grep -q "\-\-add-assignee alice"
}

@test "sync_mirror_assignees removes extra assignees" {
  sync_mirror_assignees 10 "octocat" "octocat,bob"
  gh_calls | grep -q "\-\-remove-assignee bob"
}

@test "sync_mirror_assignees no-ops when assignees match" {
  sync_mirror_assignees 10 "octocat" "octocat"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "issue edit"
}

# --- sync_repo ---

@test "sync_repo creates mirror for new open issue" {
  sync_repo "test-repo"
  # Issue #2 (Add dark mode) has no mirror → should create
  gh_calls | grep -q "gh issue create"
  gh_calls | grep -q "\[test-repo\] Add dark mode"
}

@test "sync_repo closes mirror for closed source issue" {
  sync_repo "test-repo"
  # Issue #3 (Old feature) is CLOSED, mirror #11 is OPEN → should close
  gh_calls | grep -q "gh issue close 11"
}

@test "sync_repo does not recreate existing mirror" {
  sync_repo "test-repo"
  # Issue #1 already has mirror #10 → should NOT create
  local create_count
  create_count="$(gh_calls | grep -c "gh issue create" || echo 0)"
  # Only 1 create (for issue #2), not 2
  [ "$create_count" -eq 1 ]
}

# --- sync_repo dry run ---

@test "sync_repo in dry-run does not call gh issue create/close" {
  DRY_RUN=true sync_repo "test-repo"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "gh issue create"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "gh issue close"
}

# --- generate_markdown ---

@test "generate_markdown writes TODO.md with open issues" {
  generate_markdown "$MARKDOWN_DIR" "test-repo" "$GH_MOCK_SOURCE_JSON"
  [ -f "$MARKDOWN_DIR/TODO.md" ]
  grep -q "Fix login bug" "$MARKDOWN_DIR/TODO.md"
  grep -q "Add dark mode" "$MARKDOWN_DIR/TODO.md"
}

@test "generate_markdown writes DONE.md with closed issues" {
  generate_markdown "$MARKDOWN_DIR" "test-repo" "$GH_MOCK_SOURCE_JSON"
  [ -f "$MARKDOWN_DIR/DONE.md" ]
  grep -q "Old feature" "$MARKDOWN_DIR/DONE.md"
}

@test "generate_markdown TODO.md does not include closed issues" {
  generate_markdown "$MARKDOWN_DIR" "test-repo" "$GH_MOCK_SOURCE_JSON"
  ! grep -q "Old feature" "$MARKDOWN_DIR/TODO.md"
}

@test "generate_markdown includes tracker-only issues in TODO.md" {
  generate_markdown "$MARKDOWN_DIR" "" "$GH_MOCK_MIRROR_JSON"
  grep -q "Private planning task" "$MARKDOWN_DIR/TODO.md"
}

# --- sync_mirror_comments ---

@test "sync_mirror_comments syncs new source comment to mirror" {
  export GH_MOCK_SOURCE_COMMENTS='[{"id":100,"body":"This needs review","user":{"login":"alice"}}]'
  export GH_MOCK_MIRROR_COMMENTS='[]'
  sync_mirror_comments 1 10 "qte77/test-repo"
  gh_calls | grep -q "gh issue comment 10"
  gh_calls | grep -q "\[source\]"
}

@test "sync_mirror_comments skips already-synced comments" {
  export GH_MOCK_SOURCE_COMMENTS='[{"id":100,"body":"This needs review","user":{"login":"alice"}}]'
  export GH_MOCK_MIRROR_COMMENTS='[{"id":200,"body":"[source] @alice: This needs review","user":{"login":"github-actions[bot]"}}]'
  sync_mirror_comments 1 10 "qte77/test-repo"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "gh issue comment 10"
}

@test "sync_mirror_comments skips bot and prefixed comments" {
  export GH_MOCK_SOURCE_COMMENTS='[{"id":100,"body":"[tracker] synced back","user":{"login":"github-actions[bot]"}}]'
  export GH_MOCK_MIRROR_COMMENTS='[]'
  sync_mirror_comments 1 10 "qte77/test-repo"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "gh issue comment 10"
}

@test "sync_mirror_comments in dry-run does not post" {
  export GH_MOCK_SOURCE_COMMENTS='[{"id":100,"body":"New comment","user":{"login":"alice"}}]'
  export GH_MOCK_MIRROR_COMMENTS='[]'
  DRY_RUN=true sync_mirror_comments 1 10 "qte77/test-repo"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "gh issue comment 10"
}

# --- sync_repo_prs ---

@test "sync_repo_prs creates mirror for open PR" {
  export GH_MOCK_PR_JSON='[{"number":5,"title":"Add widget","state":"OPEN","labels":[],"assignees":[]}]'
  sync_repo_prs "test-repo"
  gh_calls | grep -q "gh issue create"
  gh_calls | grep -q "\[test-repo\] PR#5: Add widget"
}

@test "sync_repo_prs closes mirror for merged PR" {
  export GH_MOCK_PR_JSON='[{"number":5,"title":"Add widget","state":"MERGED","labels":[],"assignees":[]}]'
  # Mirror exists for this PR
  export GH_MOCK_MIRROR_JSON='[{"number":20,"title":"[test-repo] PR#5: Add widget","body":"Source: qte77/test-repo#5 (PR)","state":"OPEN","labels":[{"name":"pr"}],"assignees":[]}]'
  sync_repo_prs "test-repo"
  gh_calls | grep -q "gh issue close 20"
}

@test "sync_repo_prs adds pr label to new mirrors" {
  export GH_MOCK_PR_JSON='[{"number":5,"title":"Add widget","state":"OPEN","labels":[],"assignees":[]}]'
  sync_repo_prs "test-repo"
  gh_calls | grep -q "\-\-label.*pr"
}

@test "sync_repo_prs in dry-run does not call gh" {
  export GH_MOCK_PR_JSON='[{"number":5,"title":"Add widget","state":"OPEN","labels":[],"assignees":[]}]'
  DRY_RUN=true sync_repo_prs "test-repo"
  [ ! -f "$GH_MOCK_LOG" ] || ! gh_calls | grep -q "gh issue create"
}
