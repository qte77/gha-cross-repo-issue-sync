#!/usr/bin/env bash
# common.sh — Shared functions for cross-repo issue sync.

# Parse "Source: owner/repo#N" or "Source: owner/repo#N (PR)" from issue body.
# Returns the ref (without PR suffix) or empty.
parse_source_ref() {
  local body="$1"
  echo -e "$body" | sed -n 's/^Source:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1
}

# Check if a mirror body indicates a PR mirror (has "(PR)" suffix).
is_pr_mirror() {
  local body="$1"
  echo -e "$body" | grep -q '^Source:.*[[:space:]]*(PR)$'
}

# Extract a component from a source ref (owner/repo#N).
# Usage: split_source_ref "owner/repo#42" owner|repo|number
split_source_ref() {
  local ref="$1" part="$2"
  [[ "$ref" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]] || return 0
  case "$part" in
    owner)  echo "${BASH_REMATCH[1]}" ;;
    repo)   echo "${BASH_REMATCH[2]}" ;;
    number) echo "${BASH_REMATCH[3]}" ;;
  esac
}

# Check if an event should be skipped to prevent sync loops.
# Returns 0 (true) if loop detected, 1 (false) if safe.
is_loop() {
  local actor="$1" comment="$2"
  [[ "$actor" == "github-actions[bot]" ]] && return 0
  [[ "$comment" == "[sync-bot]"* ]] && return 0
  [[ "$comment" == "[source]"* ]] && return 0
  [[ "$comment" == "[tracker]"* ]] && return 0
  return 1
}

# Check if an issue is tracker-only (no Source ref in body).
# Returns 0 (true) if tracker-only, 1 (false) if mirror.
is_tracker_only() {
  local body="$1"
  local ref
  ref="$(parse_source_ref "$body")"
  [[ -z "$ref" ]]
}

# Build mirror issue title from repo name and source title.
build_mirror_title() {
  local repo="$1" title="$2"
  echo "[$repo] $title"
}

# Build mirror issue body with source reference.
build_mirror_body() {
  local source_ref="$1"
  echo "Source: $source_ref"
}

# Build PR mirror title: [repo] PR#N: title
build_pr_mirror_title() {
  local repo="$1" pr_num="$2" title="$3"
  echo "[$repo] PR#$pr_num: $title"
}

# Build PR mirror body with source reference and PR marker.
build_pr_mirror_body() {
  local source_ref="$1"
  echo "Source: $source_ref (PR)"
}

# Build the list of repos to sync, one name per line on stdout.
# Env vars: REPO_SOURCE (file|account), REPOS_CSV, REPOS_FILE, OWNER, TRACKER_REPO
# Account mode env vars: INCLUDE_FORKS, INCLUDE_ARCHIVED (default: false)
build_repo_list() {
  local mode="${REPO_SOURCE:-file}"

  case "$mode" in
    file)
      if [[ -n "${REPOS_CSV:-}" ]]; then
        IFS=',' read -ra _repos <<< "$REPOS_CSV"
        printf '%s\n' "${_repos[@]}"
      elif [[ -f "${REPOS_FILE:-}" ]]; then
        grep -v '^\s*#' "$REPOS_FILE" | grep -v '^\s*$' | xargs -L1
      fi
      ;;
    account)
      local tracker_name=""
      [[ -n "${TRACKER_REPO:-}" ]] && tracker_name="${TRACKER_REPO##*/}"

      # Use REST API (works with fine-grained PATs, unlike gh repo list which needs GraphQL)
      local jq_filter='.[] | .name'
      [[ "${INCLUDE_ARCHIVED:-false}" != "true" ]] && jq_filter=".[] | select(.archived==false) | .name"
      [[ "${INCLUDE_FORKS:-false}" != "true" ]] && jq_filter=".[] | select(.fork==false)$(
        [[ "${INCLUDE_ARCHIVED:-false}" != "true" ]] && echo " | select(.archived==false)"
      ) | .name"

      local repos api_err
      # Try user endpoint first, fall back to org endpoint
      repos="$(gh api "users/$OWNER/repos?per_page=100" --paginate --jq "$jq_filter" 2>/tmp/gh_api_err)" \
        || repos="$(gh api "orgs/$OWNER/repos?per_page=100" --paginate --jq "$jq_filter" 2>/tmp/gh_api_err)" \
        || { api_err="$(cat /tmp/gh_api_err 2>/dev/null)"; echo "::warning::account mode failed: $api_err" >&2; return 0; }

      while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        [[ -n "$tracker_name" && "$repo" == "$tracker_name" ]] && continue
        echo "$repo"
      done <<< "$repos"
      ;;
    *)
      echo "Unknown repo_source: $mode" >&2
      return 1
      ;;
  esac
}
