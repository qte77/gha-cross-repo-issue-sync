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
