#!/usr/bin/env bash
# delete_branch_pr_tag.sh — Cleanup on bump workflow failure/cancel.
# Closes PR, deletes branch, release, and tag.
# All commands guarded with || true to prevent cascading failures.
set -euo pipefail

REPO="${GITHUB_REPOSITORY:?}"
BRANCH="${CLEANUP_BRANCH:-}"
TAG="${CLEANUP_TAG:-}"
PR="${CLEANUP_PR_NUMBER:-}"

[[ -n "$PR" ]]     && gh pr close "$PR" -R "$REPO" --delete-branch || true
[[ -n "$BRANCH" ]] && gh api "repos/$REPO/git/refs/heads/$BRANCH" -X DELETE || true
[[ -n "$TAG" ]]    && gh release delete "$TAG" -R "$REPO" --yes || true
[[ -n "$TAG" ]]    && gh api "repos/$REPO/git/refs/tags/$TAG" -X DELETE || true
[[ -n "$BRANCH" ]] && git branch -D "$BRANCH" || true
