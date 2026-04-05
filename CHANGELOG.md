# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

---

## [0.4.1] - 2026-04-05

### Removed

- Reusable workflows — cross-repo `workflow_call` fails with `startup_failure` when caller has `default_workflow_permissions: read`

## [0.4.0] - 2026-04-05

### Added

- Reusable workflows (`reusable-pull.yml`, `reusable-push.yml`) via `workflow_call` (removed in next release)

## [0.3.0] - 2026-04-05

### Added

- `repo_source` input: choose between `file` (repos.txt/CSV) and `account` (auto-discover all repos for owner)
- `include_forks` and `include_archived` inputs for account mode filtering
- `build_repo_list` function in `common.sh` (extracted from action.yaml inline logic)
- GitHub Projects board aggregation via `project_id` input (`add_to_project` in sync-pull.sh)
- Integration dry-run workflow (`integration.yml`) — smoke tests file and account modes
- Event-driven pull sync via `repository_dispatch` — instant single-repo sync
- `Makefile` with `setup_dev`, `test`, `lint`, `clean` recipes

### Changed

- Refactored test suite for strict TDD compliance (92 → 116 tests)
- Refactored `test_infra_files.bats` to contract tests
- Added error injection support to `gh_mock.bash` (`GH_MOCK_FAIL_CMD`)
- Fixed stale forward/reverse terminology in README

## [0.2.0] - 2026-03-30

### Added

- PR sync: mirror PRs alongside issues with `pr:open`/`pr:merged`/`pr:closed` status labels
- Forward comment sync from source repos to tracker mirrors
- Auto-create repo label before mirror issue creation
- Projects board auto-add documentation and API limitation notes
- Signed commit pattern for bump-and-release via GitHub API

### Changed

- Renamed forward/reverse to pull/push throughout
- Migrated license to Apache-2.0
- Standardized repo scaffold (`.editorconfig`, `SECURITY.md`, `.gitattributes`)
- Renamed `action.yml` to `action.yaml`, added version comment for bumpversion
- Unset `GITHUB_TOKEN` so PAT takes precedence in GHA

### Fixed

- Sanitize event inputs, add CHANGELOG.md
- Align cleanup test with script interface

## [0.1.0] - 2026-03-23

### Added

- `common.sh`: source ref parsing, loop guards, mirror title/body builders
- `sync-back.sh`: reverse sync (close, reopen, labels, assignees, title, comments)
- `sync-forward.sh`: forward sync with mirror lifecycle, diff-based label/assignee sync, markdown generation
- `action.yml`: composite action with forward/reverse/both directions
- Repo infra: CodeQL, dependabot, bump-and-release, BATS CI, issue/PR templates
- 77 BATS unit tests
