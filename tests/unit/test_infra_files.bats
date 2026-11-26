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

@test "release workflows call the qte77/.github reusables" {
  grep -qE 'uses: qte77/\.github/\.github/workflows/bump-version\.yml@[0-9a-f]{40}' "$REPO_ROOT/.github/workflows/bump-and-release.yml"
  grep -qE 'uses: qte77/\.github/\.github/workflows/tag-release\.yml@[0-9a-f]{40}' "$REPO_ROOT/.github/workflows/tag-release.yml"
  grep -qE 'uses: qte77/\.github/\.github/workflows/publish-release\.yml@[0-9a-f]{40}' "$REPO_ROOT/.github/workflows/tag-release.yml"
  grep -qE 'uses: qte77/\.github/\.github/workflows/publish-release\.yml@[0-9a-f]{40}' "$REPO_ROOT/.github/workflows/publish-release.yml"
}

@test "floating major tag moves only for vX.Y.Z tags" {
  for f in tag-release.yml publish-release.yml; do
    grep -qF '^v[0-9]+\.[0-9]+\.[0-9]+$' "$REPO_ROOT/.github/workflows/$f"
  done
}

@test "Integration dry-run workflow exists" {
  [ -f "$REPO_ROOT/.github/workflows/integration.yml" ]
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

@test "no tag-deleting cleanup script (the reusables never delete tags, qte77/.github#23)" {
  [ ! -e "$REPO_ROOT/.github/scripts/delete_branch_pr_tag.sh" ]
}

# --- contributor templates ---

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
