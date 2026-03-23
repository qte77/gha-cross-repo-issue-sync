# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

---

## [0.1.0] - 2026-03-23

### Added

- `common.sh`: source ref parsing, loop guards, mirror title/body builders
- `sync-back.sh`: reverse sync (close, reopen, labels, assignees, title, comments)
- `sync-forward.sh`: forward sync with mirror lifecycle, diff-based label/assignee sync, markdown generation
- `action.yml`: composite action with forward/reverse/both directions
- Repo infra: CodeQL, dependabot, bump-and-release, BATS CI, issue/PR templates
- 77 BATS unit tests
