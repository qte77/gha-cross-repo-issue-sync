# gha-cross-repo-issue-sync

Bidirectional GitHub issue sync across repos. Composite GitHub Action.

- **Forward sync**: repo issues → tracker mirror issues + TODO.md/DONE.md
- **Reverse sync**: tracker issue events → source repo (close, reopen, labels, assignees, title, comments)
- **Tracker-only issues**: private tasks visible only in the tracker repo

## Usage

### Forward sync (scheduled)

```yaml
# .github/workflows/sync-forward.yml
name: Forward sync
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
          direction: forward
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

### Reverse sync (event-driven)

```yaml
# .github/workflows/sync-back.yml
name: Reverse sync
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
          direction: reverse
          tracker_repo: ${{ github.repository }}
          token: ${{ secrets.PROJECT_TRACKER_PAT }}
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `direction` | Yes | — | `forward`, `reverse`, or `both` |
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

**GitHub Projects board**: use the built-in [auto-add workflow][gh-auto-add] to import issues from the tracker repo into a Kanban board. The board auto-reflects issue state (close → Done) but dragging cards does NOT change issue state — the GHA reverse sync handles that direction.

[gh-auto-add]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically

## PAT requirements

| Scope | Why |
|---|---|
| Issues (read+write) on tracked repos | Forward: read. Reverse: write. |
| Issues (read+write) on tracker repo | Forward: create/edit mirrors |
| Contents (write) on tracker repo | Commit TODO.md/DONE.md |
| `read:org` + `project` (classic, optional) | Projects board aggregation |

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

MIT
