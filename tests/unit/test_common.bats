#!/usr/bin/env bats

# Phase 1 TDD: tests for scripts/common.sh
# RED phase — these tests should FAIL until common.sh is implemented.

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
  source "$BATS_TEST_DIRNAME/../../scripts/common.sh"
}

# --- parse_source_ref ---

@test "parse_source_ref extracts owner/repo#N from issue body" {
  body="Some text\nSource: qte77/my-repo#42\nMore text"
  result="$(parse_source_ref "$body")"
  [ "$result" = "qte77/my-repo#42" ]
}

@test "parse_source_ref returns empty for body without Source line" {
  body="This is a tracker-only issue\nNo source reference here"
  result="$(parse_source_ref "$body")"
  [ -z "$result" ]
}

@test "parse_source_ref returns empty for empty body" {
  result="$(parse_source_ref "")"
  [ -z "$result" ]
}

@test "parse_source_ref handles Source line with extra whitespace" {
  body="Source:   qte77/some-repo#7  "
  result="$(parse_source_ref "$body")"
  [ "$result" = "qte77/some-repo#7" ]
}

# --- split_source_ref ---

@test "split_source_ref extracts owner from ref" {
  result="$(split_source_ref "qte77/my-repo#42" owner)"
  [ "$result" = "qte77" ]
}

@test "split_source_ref extracts repo from ref" {
  result="$(split_source_ref "qte77/my-repo#42" repo)"
  [ "$result" = "my-repo" ]
}

@test "split_source_ref extracts number from ref" {
  result="$(split_source_ref "qte77/my-repo#42" number)"
  [ "$result" = "42" ]
}

@test "split_source_ref returns empty for invalid ref" {
  result="$(split_source_ref "not-a-ref" owner)"
  [ -z "$result" ]
}

# --- is_loop ---

@test "is_loop returns 0 for github-actions[bot] actor" {
  is_loop "github-actions[bot]" ""
}

@test "is_loop returns 0 for sync-bot prefixed comment" {
  is_loop "some-human" "[sync-bot] Updated from source"
}

@test "is_loop returns 0 for source prefixed comment" {
  is_loop "some-human" "[source] Original comment text"
}

@test "is_loop returns 0 for tracker prefixed comment" {
  is_loop "some-human" "[tracker] Comment from tracker"
}

@test "is_loop returns 1 for human actor with normal comment" {
  ! is_loop "some-human" "This is a regular comment"
}

@test "is_loop returns 1 for human actor with empty comment" {
  ! is_loop "some-human" ""
}

# --- is_tracker_only ---

@test "is_tracker_only returns 0 when no Source ref in body" {
  is_tracker_only "Just a tracker issue, no source"
}

@test "is_tracker_only returns 1 when Source ref present" {
  ! is_tracker_only "Source: qte77/repo#1"
}

# --- build_mirror_title ---

@test "build_mirror_title formats [repo] title" {
  result="$(build_mirror_title "my-repo" "Fix the bug")"
  [ "$result" = "[my-repo] Fix the bug" ]
}

@test "build_mirror_title handles empty title" {
  result="$(build_mirror_title "repo" "")"
  [ "$result" = "[repo] " ]
}

# --- build_mirror_body ---

@test "build_mirror_body includes Source ref" {
  result="$(build_mirror_body "qte77/repo#5")"
  echo "$result" | grep -q "Source: qte77/repo#5"
}

# --- is_pr_mirror ---

@test "is_pr_mirror returns 0 for PR mirror body" {
  is_pr_mirror "Source: qte77/repo#5 (PR)"
}

@test "is_pr_mirror returns 1 for issue mirror body" {
  ! is_pr_mirror "Source: qte77/repo#5"
}

# --- build_pr_mirror_title ---

@test "build_pr_mirror_title formats [repo] PR#N: title" {
  result="$(build_pr_mirror_title "my-repo" "42" "Add feature")"
  [ "$result" = "[my-repo] PR#42: Add feature" ]
}

# --- build_pr_mirror_body ---

@test "build_pr_mirror_body includes Source ref with PR marker" {
  result="$(build_pr_mirror_body "qte77/repo#5")"
  echo "$result" | grep -q "Source: qte77/repo#5 (PR)"
}

# --- round-trip: build → parse ---

@test "build_mirror_body round-trips through parse_source_ref" {
  ref="qte77/my-repo#42"
  body="$(build_mirror_body "$ref")"
  result="$(parse_source_ref "$body")"
  [ "$result" = "$ref" ]
}

@test "build_pr_mirror_body round-trips through parse_source_ref and is_pr_mirror" {
  ref="qte77/pr-repo#7"
  body="$(build_pr_mirror_body "$ref")"
  result="$(parse_source_ref "$body")"
  [ "$result" = "$ref" ]
  is_pr_mirror "$body"
}

@test "parse_source_ref finds ref regardless of line position in body" {
  body="Title line\nSome description\nSource: qte77/deep-repo#99\nFooter"
  result="$(parse_source_ref "$body")"
  [ "$result" = "qte77/deep-repo#99" ]
}

# --- build_repo_list ---

@test "build_repo_list file mode returns repos from CSV" {
  export REPO_SOURCE="file"
  export REPOS_CSV="repo-a,repo-b"
  mapfile -t result < <(build_repo_list)
  [ "${#result[@]}" -eq 2 ]
  [ "${result[0]}" = "repo-a" ]
  [ "${result[1]}" = "repo-b" ]
}

@test "build_repo_list file mode reads repos_file skipping comments and blanks" {
  local tmpfile="$BATS_TMPDIR/repos_$$.txt"
  printf '%s\n' "# comment" "repo-x" "" "  repo-y  " "# another comment" > "$tmpfile"
  export REPO_SOURCE="file"
  export REPOS_CSV=""
  export REPOS_FILE="$tmpfile"
  mapfile -t result < <(build_repo_list)
  rm -f "$tmpfile"
  [ "${#result[@]}" -eq 2 ]
  [ "${result[0]}" = "repo-x" ]
  [ "${result[1]}" = "repo-y" ]
}

@test "build_repo_list file mode returns empty when no CSV and no file" {
  export REPO_SOURCE="file"
  export REPOS_CSV=""
  export REPOS_FILE="/nonexistent/repos.txt"
  mapfile -t result < <(build_repo_list)
  [ "${#result[@]}" -eq 0 ]
}

@test "build_repo_list defaults to file mode when REPO_SOURCE unset" {
  unset REPO_SOURCE
  export REPOS_CSV="default-repo"
  mapfile -t result < <(build_repo_list)
  [ "${#result[@]}" -eq 1 ]
  [ "${result[0]}" = "default-repo" ]
}

@test "build_repo_list account mode returns repos from gh repo list" {
  source "$BATS_TEST_DIRNAME/../test_helper/gh_mock.bash"
  export REPO_SOURCE="account"
  export OWNER="test-org"
  export TRACKER_REPO=""
  mapfile -t result < <(build_repo_list)
  [ "${#result[@]}" -eq 3 ]
  [ "${result[0]}" = "repo-a" ]
}

@test "build_repo_list account mode calls gh repo list with correct owner" {
  export GH_MOCK_LOG="$BATS_TMPDIR/gh_mock_brl_$$.log"
  rm -f "$GH_MOCK_LOG"
  source "$BATS_TEST_DIRNAME/../test_helper/gh_mock.bash"
  export REPO_SOURCE="account"
  export OWNER="test-org"
  export TRACKER_REPO=""
  build_repo_list > /dev/null
  grep -q "gh repo list test-org" "$GH_MOCK_LOG"
  rm -f "$GH_MOCK_LOG"
}

@test "build_repo_list account mode excludes tracker repo" {
  source "$BATS_TEST_DIRNAME/../test_helper/gh_mock.bash"
  export GH_MOCK_REPO_LIST=$'repo-a\nrepo-b\ntracker'
  export REPO_SOURCE="account"
  export OWNER="test-org"
  export TRACKER_REPO="test-org/tracker"
  mapfile -t result < <(build_repo_list)
  [ "${#result[@]}" -eq 2 ]
  [[ " ${result[*]} " != *" tracker "* ]]
}

@test "build_repo_list returns error for invalid repo_source" {
  export REPO_SOURCE="invalid"
  run build_repo_list
  [ "$status" -ne 0 ]
}
