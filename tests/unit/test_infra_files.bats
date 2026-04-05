#!/usr/bin/env bats

# Contract tests: required repo infrastructure files exist.
# Tests file presence and executability — NOT content details.

REPO_ROOT="$BATS_TEST_DIRNAME/../.."

setup() {
  export TMPDIR="${BATS_TMPDIR:-/tmp/claude-1000/bats-tmp}"
}

# --- action definition ---

@test "action.yaml exists with required marketplace fields" {
  [ -f "$REPO_ROOT/action.yaml" ]
  grep -q "^name:" "$REPO_ROOT/action.yaml"
  grep -q "^description:" "$REPO_ROOT/action.yaml"
  grep -q "icon:" "$REPO_ROOT/action.yaml"
  grep -q "color:" "$REPO_ROOT/action.yaml"
}

# --- CI/CD workflows ---

@test "CI workflow exists for running tests" {
  [ -f "$REPO_ROOT/.github/workflows/test.yml" ]
}

@test "release workflow exists for version bumps" {
  [ -f "$REPO_ROOT/.github/workflows/bump-and-release.yml" ]
}

@test "CodeQL security scanning workflow exists" {
  [ -f "$REPO_ROOT/.github/workflows/codeql.yml" ]
}

@test "Dependabot configuration exists" {
  [ -f "$REPO_ROOT/.github/dependabot.yml" ]
}

# --- version management ---

@test "pyproject.toml exists with bumpversion config" {
  [ -f "$REPO_ROOT/pyproject.toml" ]
  grep -q "tool.bumpversion" "$REPO_ROOT/pyproject.toml"
}

# --- scripts ---

@test "cleanup script exists and is executable" {
  [ -f "$REPO_ROOT/.github/scripts/delete_branch_pr_tag.sh" ]
  [ -x "$REPO_ROOT/.github/scripts/delete_branch_pr_tag.sh" ]
}

# --- contributor templates ---

@test "issue template directory exists" {
  [ -d "$REPO_ROOT/.github/ISSUE_TEMPLATE" ]
}

@test "PR template exists" {
  [ -f "$REPO_ROOT/.github/pull_request_template.md" ]
}

@test "commit message template exists" {
  [ -f "$REPO_ROOT/.gitmessage" ]
}

# --- license ---

@test "LICENSE file exists" {
  [ -f "$REPO_ROOT/LICENSE" ]
}
