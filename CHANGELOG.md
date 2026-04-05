# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- `repo_source` input: choose between `file` (repos.txt/CSV) and `account` (auto-discover all repos for owner)
- `include_forks` and `include_archived` inputs for account mode filtering
- `build_repo_list` function in `common.sh` (extracted from action.yaml inline logic)
- GitHub Projects board aggregation via `project_id` input (`add_to_project` in sync-pull.sh)
- Integration dry-run workflow (`integration.yml`) — smoke tests file and account modes on every PR
- Event-driven pull sync via `repository_dispatch` — instant single-repo sync from source repos

### Changed

- Refactored test suite for strict TDD behavior-first compliance (92 → 104 tests)
- Refactored `test_infra_files.bats` from brittle content matching to contract tests
- Added round-trip tests for `build_mirror_body` → `parse_source_ref`
- Added dry-run preview message verification tests
- Added multiline comment sync test
- Added markdown format validation tests (checkbox format, section headers, multi-repo append)
- Added error injection support to `gh_mock.bash` (`GH_MOCK_FAIL_CMD`)
- Added error handling tests for `sync_repo` and `handle_issue_closed`
- Added edge case tests for special characters in titles

### Added

- `Makefile` with `setup_dev`, `test`, `lint`, `clean` recipes

---

## [0.2.0] - 2026-03-30

## [0.1.0] - 2026-03-23

### Added

- `common.sh`: source ref parsing, loop guards, mirror title/body builders
- `sync-back.sh`: reverse sync (close, reopen, labels, assignees, title, comments)
- `sync-forward.sh`: forward sync with mirror lifecycle, diff-based label/assignee sync, markdown generation
- `action.yml`: composite action with forward/reverse/both directions
- Repo infra: CodeQL, dependabot, bump-and-release, BATS CI, issue/PR templates
- 77 BATS unit tests
