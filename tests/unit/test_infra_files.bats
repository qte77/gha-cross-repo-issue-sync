#!/usr/bin/env bats

# Phase 5 TDD: validation tests for repo infra files.
# Checks that required files exist with correct structure.

REPO_ROOT="$BATS_TEST_DIRNAME/../.."

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
}

# --- action.yaml ---

@test "action.yaml exists and has required branding fields" {
  [ -f "$REPO_ROOT/action.yaml" ]
  grep -q "^name:" "$REPO_ROOT/action.yaml"
  grep -q "^description:" "$REPO_ROOT/action.yaml"
  grep -q "icon:" "$REPO_ROOT/action.yaml"
  grep -q "color:" "$REPO_ROOT/action.yaml"
}

@test "action.yaml unsets GITHUB_TOKEN so PAT takes precedence" {
  # gh CLI resolves GITHUB_TOKEN > GH_TOKEN; must unset in GHA
  local count
  count="$(grep -c "GITHUB_TOKEN: ''" "$REPO_ROOT/action.yaml")"
  [ "$count" -eq 2 ]
}

# --- dependabot ---

@test "dependabot.yml exists and covers github-actions ecosystem" {
  [ -f "$REPO_ROOT/.github/dependabot.yml" ]
  grep -q "github-actions" "$REPO_ROOT/.github/dependabot.yml"
}

# --- codeql ---

@test "codeql workflow exists" {
  [ -f "$REPO_ROOT/.github/workflows/codeql.yml" ]
}

# --- bump-my-version ---

@test "bump-and-release workflow exists" {
  [ -f "$REPO_ROOT/.github/workflows/bump-and-release.yml" ]
  grep -q "bump-my-version" "$REPO_ROOT/.github/workflows/bump-and-release.yml"
}

@test "pyproject.toml has bumpversion config" {
  [ -f "$REPO_ROOT/pyproject.toml" ]
  grep -q "tool.bumpversion" "$REPO_ROOT/pyproject.toml"
}

# --- cleanup script ---

@test "cleanup script exists and is executable" {
  [ -f "$REPO_ROOT/.github/scripts/delete_branch_pr_tag.sh" ]
  [ -x "$REPO_ROOT/.github/scripts/delete_branch_pr_tag.sh" ]
}

# --- .gitmessage ---

@test ".gitmessage exists with conventional commit hint" {
  [ -f "$REPO_ROOT/.gitmessage" ]
  grep -qi "feat\|fix\|chore\|docs" "$REPO_ROOT/.gitmessage"
}

# --- issue template ---

@test "issue template exists" {
  [ -f "$REPO_ROOT/.github/ISSUE_TEMPLATE/bug_report.md" ] || \
  [ -f "$REPO_ROOT/.github/ISSUE_TEMPLATE/bug_report.yml" ] || \
  [ -d "$REPO_ROOT/.github/ISSUE_TEMPLATE" ]
}

# --- PR template ---

@test "PR template exists" {
  [ -f "$REPO_ROOT/.github/pull_request_template.md" ]
}

# --- BATS CI ---

@test "CI workflow runs bats tests" {
  [ -f "$REPO_ROOT/.github/workflows/test.yml" ]
  grep -q "bats" "$REPO_ROOT/.github/workflows/test.yml"
}

# --- LICENSE ---

@test "LICENSE exists with Apache-2.0" {
  [ -f "$REPO_ROOT/LICENSE" ]
  grep -q "Apache License" "$REPO_ROOT/LICENSE"
}
