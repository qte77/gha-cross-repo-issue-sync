# gha-cross-repo-issue-sync

Bidirectional GitHub issue sync across repos. Composite GitHub Action.

![Version](https://img.shields.io/badge/version-0.4.4-8A2BE2)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![CodeFactor](https://www.codefactor.io/repository/github/qte77/gha-cross-repo-issue-sync/badge)](https://www.codefactor.io/repository/github/qte77/gha-cross-repo-issue-sync)
[![CodeQL](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/codeql.yml/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/codeql.yml)
[![Dependabot](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/dependabot/dependabot-updates)
[![BATS](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/test.yml/badge.svg)](https://github.com/qte77/gha-cross-repo-issue-sync/actions/workflows/test.yml)

- **Pull sync**: repo issues → tracker mirror issues + TODO.md/DONE.md
- **Push sync**: tracker issue events → source repo (close, reopen, labels, assignees, title, comments)
- **Tracker-only issues**: private tasks visible only in the tracker repo

## Usage

### Pull sync (scheduled — repos → tracker)

```yaml
# .github/workflows/sync-pull.yml  (in the tracker repo)
name: Pull sync
on:
  schedule:
    - cron: '*/15 * * * *'
  workflow_dispatch:
  repository_dispatch:
    types: [sync-repo]
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
          # Override with single repo from dispatch payload
          repos: ${{ github.event.client_payload.repo || '' }}
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

### Pull sync with account mode (all repos for owner)

```yaml
# .github/workflows/sync-pull-account.yml
name: Pull sync (all repos)
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
          repo_source: account
          token: ${{ secrets.PROJECT_TRACKER_PAT }}
```

### Event-driven pull sync (instant — source repo → tracker)

For low-latency sync, add this workflow to each source repo. On issue events it fires `repository_dispatch` to the tracker repo, triggering an immediate pull sync for that single repo.

```yaml
# .github/workflows/notify-tracker.yml  (in each source repo)
name: Notify tracker
on:
  issues:
    types: [opened, closed, reopened, edited, labeled, unlabeled, assigned, unassigned]
jobs:
  dispatch:
    runs-on: ubuntu-latest
    if: github.actor != 'github-actions[bot]'
    steps:
      - run: |
          gh api repos/owner/.github-private-project-tracker/dispatches \
            -f event_type=sync-repo \
            -f 'client_payload[repo]=${{ github.event.repository.name }}'
        env:
          GH_TOKEN: ${{ secrets.PROJECT_TRACKER_PAT }}
```

### Push sync (event-driven — tracker → repos)

```yaml
# .github/workflows/sync-push.yml  (in the tracker repo)
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

| Name | Required | Default | Description |
|---|---|---|---|
| `direction` | Yes | — | `pull` (repos→tracker), `push` (tracker→repos), or `both` |
| `tracker_repo` | Yes | — | Tracker repo (`owner/repo`) |
| `repos_file` | No | `repos.txt` | File listing tracked repos |
| `repos` | No | — | Comma-separated repo list (alternative to file) |
| `repo_source` | No | `file` | `file` (repos_file/repos) or `account` (auto-discover all repos for owner) |
| `include_forks` | No | `false` | Include forked repos in account mode |
| `include_archived` | No | `false` | Include archived repos in account mode |
| `owner` | No | `github.repository_owner` | GitHub owner for tracked repos |
| `token` | Yes | `github.token` | PAT with Issues read+write |
| `project_id` | No | — | GitHub Projects board ID |
| `generate_markdown` | No | `true` | Generate TODO.md/DONE.md |
| `dry_run` | No | `false` | Preview without changes |
| `event_action` | No | `github.event.action` | Issue event action (push sync) |
| `event_issue_number` | No | — | Issue number that triggered the event (push sync) |
| `event_label` | No | — | Label name from labeled/unlabeled event (push sync) |
| `event_assignee` | No | — | Assignee login from assigned/unassigned event (push sync) |

## How it works

```
Source repos (issues = SOT)
    ↕ bidirectional sync
Tracker repo (mirror issues + TODO.md + DONE.md)
```

1. **Pull sync** (batch, scheduled) reads issues from all tracked repos, creates/closes/updates mirror issues in the tracker, and generates TODO.md/DONE.md
2. **Push sync** (event-driven, instant) fires on issue events in the tracker repo and propagates state changes back to source repos via the `Source: owner/repo#N` reference in the mirror issue body
3. **Loop prevention** uses bot actor checks and comment prefix guards (`[source]`, `[tracker]`, `[sync-bot]`) to avoid infinite sync cycles
4. **Tracker-only issues** (those without a `Source:` ref) remain private to the tracker, appear in TODO.md under `## tracker`, and are ignored by push sync
5. **GitHub Projects board** integration (when `project_id` is set) automatically adds all open tracker issues to the board via `gh project item-add`. The board reflects issue state (close -> Done) but dragging cards does NOT change issue state — push sync handles that direction. See [adding items to projects][gh-add-items] for bulk import options
6. **Projects API limitations**: fine-grained PATs [do not support user-owned projects][gh-pat-projects] — only org-owned projects via [REST API][gh-projects-rest]. For user-owned projects, use the UI [auto-add workflow][gh-auto-add] or a [classic PAT with `project` scope][gh-pat-classic]. See [fine-grained PAT feature gaps][gh-pat-ga] for current status

[gh-auto-add]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically
[gh-add-items]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-items-in-your-project/adding-items-to-your-project
[gh-pat-projects]: https://github.com/actions/add-to-project/issues/289#issuecomment-1906032637
[gh-projects-rest]: https://docs.github.com/en/rest/projects/items
[gh-pat-classic]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic
[gh-pat-ga]: https://github.blog/changelog/2025-03-18-fine-grained-pats-are-now-generally-available/

## PAT requirements

The default `GITHUB_TOKEN` handles account mode repo discovery (public read) and markdown commits (same-repo write). A PAT is only needed for **cross-repo** issue operations.

| Scope | Why |
|---|---|
| Issues (read+write) on tracked repos | Pull: read. Push: write. |
| Issues (read+write) on tracker repo | Pull: create/edit mirrors |
| Contents (write) on tracker repo | Commit TODO.md/DONE.md |
| `read:org` + `project` ([classic PAT][gh-pat-classic], optional) | Projects board aggregation (org-owned projects only) |

## Development

```bash
# Run all tests
bats tests/unit/

# Run specific phase
bats tests/unit/test_common.bats
bats tests/unit/test_sync_push.bats
bats tests/unit/test_sync_pull.bats
```

## License

[Apache-2.0](LICENSE)
