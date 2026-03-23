#!/usr/bin/env bash
# sync-back.sh — Reverse sync: tracker issue events → source repo.
# Requires common.sh to be sourced first.

DRY_RUN="${DRY_RUN:-false}"

# Extract issue number from source ref.
_issue_num() {
  split_source_ref "$1" number
}

# Extract owner/repo from source ref.
_issue_repo() {
  local owner repo
  owner="$(split_source_ref "$1" owner)"
  repo="$(split_source_ref "$1" repo)"
  [[ -n "$owner" && -n "$repo" ]] && echo "$owner/$repo"
}

handle_issue_closed() {
  local ref="$1" repo="$2"
  [[ -z "$ref" ]] && return 0
  local num
  num="$(_issue_num "$ref")"
  gh issue close "$num" -R "$repo"
}

handle_issue_reopened() {
  local ref="$1" repo="$2"
  [[ -z "$ref" ]] && return 0
  local num
  num="$(_issue_num "$ref")"
  gh issue reopen "$num" -R "$repo"
}

handle_issue_labeled() {
  local ref="$1" repo="$2" label="$3"
  local num
  num="$(_issue_num "$ref")"
  gh issue edit "$num" -R "$repo" --add-label "$label"
}

handle_issue_unlabeled() {
  local ref="$1" repo="$2" label="$3"
  local num
  num="$(_issue_num "$ref")"
  gh issue edit "$num" -R "$repo" --remove-label "$label"
}

handle_issue_edited() {
  local ref="$1" repo="$2" title="$3"
  local num
  num="$(_issue_num "$ref")"
  gh issue edit "$num" -R "$repo" --title "$title"
}

handle_issue_assigned() {
  local ref="$1" repo="$2" assignee="$3"
  local num
  num="$(_issue_num "$ref")"
  gh issue edit "$num" -R "$repo" --add-assignee "$assignee"
}

handle_issue_unassigned() {
  local ref="$1" repo="$2" assignee="$3"
  local num
  num="$(_issue_num "$ref")"
  gh issue edit "$num" -R "$repo" --remove-assignee "$assignee"
}

handle_issue_comment() {
  local ref="$1" repo="$2" comment="$3"
  local num
  num="$(_issue_num "$ref")"
  gh issue comment "$num" -R "$repo" --body "[tracker] $comment"
}

# Dispatch an event to the appropriate handler.
# Args: action ref repo label title assignee [comment]
dispatch_event() {
  local action="$1" ref="$2" repo="$3" label="$4" title="$5" assignee="$6" comment="${7:-}"

  # Guard: skip tracker-only issues
  [[ -z "$ref" ]] && return 0

  # Guard: dry run
  [[ "$DRY_RUN" == "true" ]] && { echo "[dry-run] Would dispatch: $action for $ref"; return 0; }

  case "$action" in
    closed)           handle_issue_closed "$ref" "$repo" ;;
    reopened)         handle_issue_reopened "$ref" "$repo" ;;
    labeled)          handle_issue_labeled "$ref" "$repo" "$label" ;;
    unlabeled)        handle_issue_unlabeled "$ref" "$repo" "$label" ;;
    edited)           handle_issue_edited "$ref" "$repo" "$title" ;;
    assigned)         handle_issue_assigned "$ref" "$repo" "$assignee" ;;
    unassigned)       handle_issue_unassigned "$ref" "$repo" "$assignee" ;;
    comment_created)  handle_issue_comment "$ref" "$repo" "$comment" ;;
    *) echo "Unknown action: $action" >&2 ;;
  esac
}
