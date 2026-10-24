# gha-cross-repo-issue-sync

> Bidirectional GitHub issue sync across repos into one tracker repo. Composite GitHub Action.

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.4.4-blue)](CHANGELOG.md)
[![CodeQL](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/codeql.yml/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/codeql.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/qte77/gha-cross-repo-issue-sync/badge)](https://www.codefactor.io/repository/github/qte77/gha-cross-repo-issue-sync)
[![BATS](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/test.yml/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/test.yml)
[![Lint MD and Links](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/lint-md-links.yml/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/lint-md-links.yml)
[![Dependabot](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/dependabot/dependabot-updates)

## What

- **Pull sync**: repo issues → tracker mirror issues + TODO.md/DONE.md
- **Push sync**: tracker issue events → source repo (close, reopen, labels, assignees, title, comments)
- **Tracker-only issues**: private tasks visible only in the tracker repo

## How

```yaml
# .github/workflows/sync-pull.yml  (in the tracker repo)
on:
  schedule:
    - cron: '*/15 * * * *'
permissions:
  issues: write
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: qte77/gha-cross-repo-issue-sync@v1
        with:
          direction: pull
          tracker_repo: owner/.github-private-project-tracker
          repos_file: repos.txt
          generate_markdown: 'false'
          token: ${{ secrets.PROJECT_TRACKER_PAT }}
```

See [docs/usage.md](docs/usage.md) for push sync, account mode, event-driven sync, all inputs, PAT
scopes and internals.

## Why

GitHub has no native way to mirror issues from many repos into one place. Webhook bridges need
infrastructure to host. This action runs entirely in GitHub Actions, syncs both directions, and
keeps private tracker-only tasks next to the mirrors.

## Refs

- [Adding items to a project automatically][gh-auto-add]
- [Adding items to your project][gh-add-items]
- [Fine-grained PATs and user-owned projects][gh-pat-projects]
- [REST API: project items][gh-projects-rest]
- [Creating a classic PAT][gh-pat-classic]
- [Fine-grained PATs GA][gh-pat-ga]

## License

[Apache-2.0](LICENSE)

[gh-auto-add]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically
[gh-add-items]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-items-in-your-project/adding-items-to-your-project
[gh-pat-projects]: https://github.com/actions/add-to-project/issues/289#issuecomment-1906032637
[gh-projects-rest]: https://docs.github.com/en/rest/projects/items
[gh-pat-classic]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic
[gh-pat-ga]: https://github.blog/changelog/2025-03-18-fine-grained-pats-are-now-generally-available/
