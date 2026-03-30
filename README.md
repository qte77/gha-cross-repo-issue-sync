# gha-cross-repo-issue-sync

[![CodeFactor](https://www.codefactor.io/repository/github/qte77/gha-cross-repo-issue-sync/badge)](https://www.codefactor.io/repository/github/qte77/gha-cross-repo-issue-sync)
[![CodeQL](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/codeql.yml/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/codeql.yml)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-blue?logo=dependabot)](https://github.com/qte77/gha-cross-repo-issue-sync/security/dependabot)

Bidirectional GitHub issue sync across repos. Composite GitHub Action.

- **Pull sync**: repo issues → tracker mirror issues + TODO.md/DONE.md
- **Push sync**: tracker issue events → source repo (close, reopen, labels, assignees, title, comments)
- **Tracker-only issues**: private tasks visible only in the tracker repo

## Usage

### Pull sync (scheduled — repos → tracker)

```yaml
# .github/workflows/sync-pull.yml
name: Pull sync
on:
  schedule:
    - cron: '*/15 * * * *'
  workflow_dispatch:
permissions:
  contents: write
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
          token: ${{ secrets.PROJECT_TRACKER_PAT }}
      - name: Commit markdown
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add TODO.md DONE.md
          git diff --cached --quiet && exit 0
          git commit -m "chore: sync TODO/DONE"
          git push
```

### Push sync (event-driven — tracker → repos)

```yaml
# .github/workflows/sync-push.yml
name: Push sync
on:
  issues:
    types: [closed, reopened, edited, labeled, unlabeled, assigned, unassigned]
  issue_comment:
    types: [created]
jobs:
  sync:
    runs-on: ubuntu-latest
    if: github.actor != 'github-actions[bot]'
    steps:
      - uses: qte77/gha-cross-repo-issue-sync@v1
        with:
          direction: push
          tracker_repo: ${{ github.repository }}
          token: ${{ secrets.PROJECT_TRACKER_PAT }}
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `direction` | Yes | — | `pull` (repos→tracker), `push` (tracker→repos), or `both` |
| `tracker_repo` | Yes | — | Tracker repo (`owner/repo`) |
| `repos_file` | No | `repos.txt` | File listing tracked repos |
| `repos` | No | — | Comma-separated repo list (alternative to file) |
| `owner` | No | `github.repository_owner` | GitHub owner for tracked repos |
| `token` | Yes | `github.token` | PAT with Issues read+write |
| `project_id` | No | — | GitHub Projects board ID |
| `generate_markdown` | No | `true` | Generate TODO.md/DONE.md |
| `dry_run` | No | `false` | Preview without changes |

## How it works

```
Source repos (issues = SOT)
    ↕ bidirectional sync
Tracker repo (mirror issues + TODO.md + DONE.md)
```

**Forward** (batch, scheduled): reads issues from all repos, creates/closes/updates mirrors, generates markdown.

**Reverse** (event-driven, instant): fires on issue events in the tracker repo, propagates state changes back to source repos via `Source: owner/repo#N` reference in the mirror issue body.

**Loop prevention**: bot actor check + comment prefix guards (`[source]`, `[tracker]`, `[sync-bot]`).

**Tracker-only issues**: issues without a `Source:` ref are private to the tracker — visible in TODO.md under `## tracker`, ignored by reverse sync.

**GitHub Projects board**: use the built-in [auto-add workflow][gh-auto-add] to import tracker issues into a Kanban board. The board reflects issue state (close → Done) but dragging cards does NOT change issue state — the GHA reverse sync handles that direction. See [adding items to projects][gh-add-items] for bulk import options.

**Projects API limitations**: fine-grained PATs [do not support user-owned projects][gh-pat-projects] — only org-owned projects via [REST API][gh-projects-rest]. For user-owned projects, use the UI auto-add workflow or a [classic PAT with `project` scope][gh-pat-classic]. See [fine-grained PAT feature gaps][gh-pat-ga] for current status.

[gh-auto-add]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically
[gh-add-items]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-items-in-your-project/adding-items-to-your-project
[gh-pat-projects]: https://github.com/actions/add-to-project/issues/289#issuecomment-1906032637
[gh-projects-rest]: https://docs.github.com/en/rest/projects/items
[gh-pat-classic]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic
[gh-pat-ga]: https://github.blog/changelog/2025-03-18-fine-grained-pats-are-now-generally-available/

## PAT requirements

| Scope | Why |
|---|---|
| Issues (read+write) on tracked repos | Forward: read. Reverse: write. |
| Issues (read+write) on tracker repo | Forward: create/edit mirrors |
| Contents (write) on tracker repo | Commit TODO.md/DONE.md |
| `read:org` + `project` ([classic PAT][gh-pat-classic], optional) | Projects board aggregation (org-owned projects only) |

## Development

```bash
# Run all tests
bats tests/unit/

# Run specific phase
bats tests/unit/test_common.bats
bats tests/unit/test_sync_back.bats
bats tests/unit/test_sync_forward.bats
```

## License

Apache-2.0
