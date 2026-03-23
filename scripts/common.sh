#!/usr/bin/env bash
# common.sh — Shared functions for cross-repo issue sync.

# Parse "Source: owner/repo#N" from issue body. Returns the ref or empty.
parse_source_ref() {
  local body="$1"
  echo -e "$body" | grep -oP '(?<=Source:\s{0,10})\S+' | head -1
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
