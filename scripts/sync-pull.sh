#!/usr/bin/env bash
# sync-pull.sh — Pull sync: repo issues → tracker mirrors + markdown.
# Requires common.sh to be sourced first.

DRY_RUN="${DRY_RUN:-false}"
TRACKER_REPO="${TRACKER_REPO:-}"
OWNER="${OWNER:-}"

# Find mirror issue number for a source ref in cached mirror JSON.
# Args: $1 = source ref, $2 = mirror issues JSON array
find_mirror_for_ref() {
  local ref="$1" mirrors="$2"
  echo "$mirrors" | jq -r --arg ref "$ref" \
    '.[] | select(.body | contains($ref)) | .number' 2>/dev/null | head -1
}

# Get mirror state for a source ref.
_mirror_state() {
  local ref="$1" mirrors="$2"
  echo "$mirrors" | jq -r --arg ref "$ref" \
    '.[] | select(.body | contains($ref)) | .state' 2>/dev/null | head -1
}

# Get mirror title for a source ref.
_mirror_title() {
  local ref="$1" mirrors="$2"
  echo "$mirrors" | jq -r --arg ref "$ref" \
    '.[] | select(.body | contains($ref)) | .title' 2>/dev/null | head -1
}

# Get comma-separated labels from mirror.
_mirror_labels() {
  local ref="$1" mirrors="$2"
  echo "$mirrors" | jq -r --arg ref "$ref" \
    '.[] | select(.body | contains($ref)) | [.labels[].name] | join(",")' 2>/dev/null | head -1
}

# Get comma-separated assignees from mirror.
_mirror_assignees() {
  local ref="$1" mirrors="$2"
  echo "$mirrors" | jq -r --arg ref "$ref" \
    '.[] | select(.body | contains($ref)) | [.assignees[].login] | join(",")' 2>/dev/null | head -1
}

create_mirror() {
  local repo="$1" title="$2" ref="$3"
  local mirror_title mirror_body
  mirror_title="$(build_mirror_title "$repo" "$title")"
  mirror_body="$(build_mirror_body "$ref")"
  # Ensure repo label exists in tracker
  gh label create "$repo" -R "$TRACKER_REPO" --color "ededed" 2>/dev/null || true
  gh issue create -R "$TRACKER_REPO" \
    --title "$mirror_title" \
    --body "$mirror_body" \
    --label "$repo"
}

close_mirror() {
  local mirror_num="$1"
  gh issue close "$mirror_num" -R "$TRACKER_REPO"
}

reopen_mirror() {
  local mirror_num="$1"
  gh issue reopen "$mirror_num" -R "$TRACKER_REPO"
}

update_mirror_title() {
  local mirror_num="$1" new_title="$2"
  gh issue edit "$mirror_num" -R "$TRACKER_REPO" --title "$new_title"
}

# Check if a value exists in a comma-separated list.
_in_csv() {
  local needle="$1" haystack="$2"
  [[ ",$haystack," == *",$needle,"* ]]
}

# Sync labels between source and mirror.
# Args: mirror_num source_labels mirror_labels [repo_label]
# Labels are comma-separated strings.
sync_mirror_labels() {
  local mirror_num="$1" src_labels="$2" mir_labels="$3" repo_label="${4:-}"

  # Add missing labels
  while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    _in_csv "$label" "$mir_labels" || gh issue edit "$mirror_num" -R "$TRACKER_REPO" --add-label "$label"
  done <<< "${src_labels//,/$'\n'}"

  # Remove extra labels (skip repo label)
  while IFS= read -r label; do
    [[ -z "$label" || "$label" == "$repo_label" ]] && continue
    _in_csv "$label" "$src_labels" || gh issue edit "$mirror_num" -R "$TRACKER_REPO" --remove-label "$label"
  done <<< "${mir_labels//,/$'\n'}"
}

# Sync assignees between source and mirror.
# Args: mirror_num source_assignees mirror_assignees
sync_mirror_assignees() {
  local mirror_num="$1" src_assignees="$2" mir_assignees="$3"

  while IFS= read -r assignee; do
    [[ -z "$assignee" ]] && continue
    _in_csv "$assignee" "$mir_assignees" || gh issue edit "$mirror_num" -R "$TRACKER_REPO" --add-assignee "$assignee"
  done <<< "${src_assignees//,/$'\n'}"

  while IFS= read -r assignee; do
    [[ -z "$assignee" ]] && continue
    _in_csv "$assignee" "$src_assignees" || gh issue edit "$mirror_num" -R "$TRACKER_REPO" --remove-assignee "$assignee"
  done <<< "${mir_assignees//,/$'\n'}"
}

# Sync a single repo's issues to tracker mirrors.
# Args: $1 = repo name
sync_repo() {
  local repo="$1"

  # Fetch source issues
  local source_json
  source_json="$(gh issue list -R "$OWNER/$repo" --state all --limit 200 \
    --json number,title,state,labels,assignees 2>/dev/null || echo "[]")"

  # Fetch existing mirrors
  local mirror_json
  mirror_json="$(gh issue list -R "$TRACKER_REPO" --state all --limit 500 \
    --json number,title,body,state,labels,assignees 2>/dev/null || echo "[]")"

  # Process each source issue
  while IFS= read -r issue; do
    local src_num src_title src_state src_ref
    src_num="$(echo "$issue" | jq -r '.number')"
    src_title="$(echo "$issue" | jq -r '.title')"
    src_state="$(echo "$issue" | jq -r '.state')"
    src_ref="$OWNER/$repo#$src_num"

    local mirror_num
    mirror_num="$(find_mirror_for_ref "$src_ref" "$mirror_json")"
    local mirror_state
    mirror_state="$(_mirror_state "$src_ref" "$mirror_json")"

    if [[ "$src_state" == "OPEN" ]]; then
      if [[ -z "$mirror_num" ]]; then
        # New issue — create mirror
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[dry-run] Would create mirror: [$repo] $src_title"
        else
          create_mirror "$repo" "$src_title" "$src_ref"
        fi
      else
        # Existing mirror — sync state and metadata
        [[ "$mirror_state" == "CLOSED" && "$DRY_RUN" != "true" ]] && reopen_mirror "$mirror_num"

        # Sync title
        local expected_title
        expected_title="$(build_mirror_title "$repo" "$src_title")"
        local current_title
        current_title="$(_mirror_title "$src_ref" "$mirror_json")"
        [[ "$current_title" != "$expected_title" && "$DRY_RUN" != "true" ]] && \
          update_mirror_title "$mirror_num" "$expected_title"

        # Sync labels
        if [[ "$DRY_RUN" != "true" ]]; then
          local src_labels mir_labels
          src_labels="$(echo "$issue" | jq -r '[.labels[].name] | join(",")')"
          mir_labels="$(_mirror_labels "$src_ref" "$mirror_json")"
          sync_mirror_labels "$mirror_num" "$src_labels" "$mir_labels" "$repo"
        fi

        # Sync assignees
        if [[ "$DRY_RUN" != "true" ]]; then
          local src_assignees mir_assignees
          src_assignees="$(echo "$issue" | jq -r '[.assignees[].login] | join(",")')"
          mir_assignees="$(_mirror_assignees "$src_ref" "$mirror_json")"
          sync_mirror_assignees "$mirror_num" "$src_assignees" "$mir_assignees"
        fi

        # Sync comments
        sync_mirror_comments "$src_num" "$mirror_num" "$OWNER/$repo"
      fi
    elif [[ "$src_state" == "CLOSED" ]]; then
      if [[ -n "$mirror_num" && "$mirror_state" == "OPEN" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[dry-run] Would close mirror #$mirror_num"
        else
          close_mirror "$mirror_num"
        fi
      fi
    fi
  done < <(echo "$source_json" | jq -c '.[]')
}

# Update PR status label on a mirror issue.
# Args: $1 = mirror issue number, $2 = PR state (OPEN|MERGED|CLOSED)
update_pr_status_label() {
  local mirror_num="$1" pr_state="$2"
  local status_label

  case "$pr_state" in
    OPEN)   status_label="pr:open" ;;
    MERGED) status_label="pr:merged" ;;
    CLOSED) status_label="pr:closed" ;;
    *) return 0 ;;
  esac

  # Ensure status label exists
  gh label create "$status_label" -R "$TRACKER_REPO" --color "0e8a16" 2>/dev/null || true

  # Add the current status label
  gh issue edit "$mirror_num" -R "$TRACKER_REPO" --add-label "$status_label"

  # Remove other status labels
  for other in "pr:open" "pr:merged" "pr:closed"; do
    [[ "$other" != "$status_label" ]] && \
      gh issue edit "$mirror_num" -R "$TRACKER_REPO" --remove-label "$other" 2>/dev/null || true
  done
}

# Sync a single repo's PRs to tracker mirrors.
# Args: $1 = repo name
sync_repo_prs() {
  local repo="$1"

  # Fetch source PRs
  local pr_json
  pr_json="$(gh pr list -R "$OWNER/$repo" --state all --limit 200 \
    --json number,title,state,labels,assignees 2>/dev/null || echo "[]")"

  # Fetch existing mirrors (includes PR mirrors)
  local mirror_json
  mirror_json="$(gh issue list -R "$TRACKER_REPO" --state all --limit 500 \
    --json number,title,body,state,labels,assignees 2>/dev/null || echo "[]")"

  # Process each source PR
  while IFS= read -r pr; do
    [[ -z "$pr" || "$pr" == "null" ]] && continue

    local pr_num pr_title pr_state pr_ref
    pr_num="$(echo "$pr" | jq -r '.number')"
    pr_title="$(echo "$pr" | jq -r '.title')"
    pr_state="$(echo "$pr" | jq -r '.state')"
    pr_ref="$OWNER/$repo#$pr_num"

    # Find existing mirror by PR ref in body (includes "(PR)" marker)
    local mirror_num mirror_state
    mirror_num="$(echo "$mirror_json" | jq -r --arg ref "$pr_ref (PR)" \
      '.[] | select(.body | contains($ref)) | .number' 2>/dev/null | head -1)"
    mirror_state="$(echo "$mirror_json" | jq -r --arg ref "$pr_ref (PR)" \
      '.[] | select(.body | contains($ref)) | .state' 2>/dev/null | head -1)"

    if [[ "$pr_state" == "OPEN" ]]; then
      if [[ -z "$mirror_num" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[dry-run] Would create PR mirror: [$repo] PR#$pr_num: $pr_title"
        else
          local mirror_title mirror_body
          mirror_title="$(build_pr_mirror_title "$repo" "$pr_num" "$pr_title")"
          mirror_body="$(build_pr_mirror_body "$pr_ref")"
          gh label create "$repo" -R "$TRACKER_REPO" --color "ededed" 2>/dev/null || true
          gh label create "pr" -R "$TRACKER_REPO" --color "0e8a16" 2>/dev/null || true
          gh issue create -R "$TRACKER_REPO" \
            --title "$mirror_title" \
            --body "$mirror_body" \
            --label "$repo" --label "pr"
        fi
      else
        # Existing open mirror — ensure pr:open status label
        [[ "$DRY_RUN" != "true" ]] && update_pr_status_label "$mirror_num" "OPEN"
      fi
    elif [[ "$pr_state" == "MERGED" || "$pr_state" == "CLOSED" ]]; then
      if [[ -n "$mirror_num" && "$mirror_state" == "OPEN" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[dry-run] Would close PR mirror #$mirror_num"
        else
          update_pr_status_label "$mirror_num" "$pr_state"
          close_mirror "$mirror_num"
        fi
      fi
    fi
  done < <(echo "$pr_json" | jq -c '.[]')
}

# Sync comments from source issue to mirror issue.
# Args: $1 = source issue number, $2 = mirror issue number, $3 = source repo (owner/repo)
sync_mirror_comments() {
  local src_num="$1" mirror_num="$2" src_repo="$3"

  # Fetch comments from source and mirror
  local src_comments mirror_comments
  src_comments="$(gh api "repos/$src_repo/issues/$src_num/comments" --jq '.' 2>/dev/null || echo "[]")"
  mirror_comments="$(gh api "repos/$TRACKER_REPO/issues/$mirror_num/comments" --jq '.' 2>/dev/null || echo "[]")"

  # Process each source comment
  while IFS= read -r comment; do
    [[ -z "$comment" || "$comment" == "null" ]] && continue

    local body author
    body="$(echo "$comment" | jq -r '.body')"
    author="$(echo "$comment" | jq -r '.user.login')"

    # Skip bot and prefixed comments (loop prevention)
    is_loop "$author" "$body" && continue

    # Check if this comment is already synced (search for body text in mirror comments)
    local already_synced
    already_synced="$(echo "$mirror_comments" | jq -r --arg body "$body" \
      '[.[] | select(.body | contains($body))] | length')"
    [[ "$already_synced" -gt 0 ]] && continue

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would sync comment from @$author to mirror #$mirror_num"
    else
      gh issue comment "$mirror_num" -R "$TRACKER_REPO" --body "[source] @$author: $body"
    fi
  done < <(echo "$src_comments" | jq -c '.[]')
}

# Generate TODO.md and DONE.md from issues JSON.
# Args: $1 = output dir, $2 = repo name (empty = tracker-only), $3 = issues JSON
generate_markdown() {
  local out_dir="$1" repo="$2" issues_json="$3"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local section_header=""
  [[ -n "$repo" ]] && section_header="## $repo"

  # Open issues → TODO.md
  local open_md
  if [[ -n "$repo" ]]; then
    open_md="$(echo "$issues_json" | jq -r \
      '.[] | select(.state == "OPEN") | "- [ ] \(.title) (#\(.number))"')"
  else
    # Tracker-only: filter issues without Source ref in body
    open_md="$(echo "$issues_json" | jq -r \
      '.[] | select(.state == "OPEN") | select(.body | contains("Source:") | not) | "- [ ] \(.title) (#\(.number))"')"
    section_header="## tracker"
  fi

  if [[ -n "$open_md" ]]; then
    if [[ -f "$out_dir/TODO.md" ]]; then
      echo -e "\n$section_header\n\n$open_md" >> "$out_dir/TODO.md"
    else
      echo -e "# TODO\n\n_Last sync: ${timestamp}_\n\n$section_header\n\n$open_md" > "$out_dir/TODO.md"
    fi
  fi

  # Closed issues → DONE.md
  local closed_md
  if [[ -n "$repo" ]]; then
    closed_md="$(echo "$issues_json" | jq -r \
      '.[] | select(.state == "CLOSED") | "- [x] \(.title) (#\(.number))"')"
  else
    closed_md="$(echo "$issues_json" | jq -r \
      '.[] | select(.state == "CLOSED") | select(.body | contains("Source:") | not) | "- [x] \(.title) (#\(.number))"')"
  fi

  if [[ -n "$closed_md" ]]; then
    if [[ -f "$out_dir/DONE.md" ]]; then
      echo -e "\n$section_header\n\n$closed_md" >> "$out_dir/DONE.md"
    else
      echo -e "# DONE\n\n_Last sync: ${timestamp}_\n\n$section_header\n\n$closed_md" > "$out_dir/DONE.md"
    fi
  fi
}

# Add all open tracker issues to a GitHub Projects board.
# Reads PROJECT_ID, TRACKER_REPO, DRY_RUN from env.
add_to_project() {
  [[ -z "${PROJECT_ID:-}" ]] && return 0

  local issues_json
  issues_json="$(gh issue list -R "$TRACKER_REPO" --state open --limit 500 \
    --json number 2>/dev/null || echo "[]")"

  while IFS= read -r num; do
    [[ -z "$num" || "$num" == "null" ]] && continue
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would add issue #$num to project $PROJECT_ID"
    else
      gh project item-add "$PROJECT_ID" --owner "${TRACKER_REPO%%/*}" \
        --url "https://github.com/$TRACKER_REPO/issues/$num" 2>/dev/null || true
    fi
  done < <(echo "$issues_json" | jq -r '.[].number')
}
