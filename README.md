# pr-review-prep

OpenClaw skill for turning a GitHub pull request into a structured reviewer checklist.

The useful part is deliberately deterministic: a shell script scans the changed file list and emits risk flags before any model writes prose. That keeps the review policy auditable in git instead of hiding it inside a prompt.

## Why This Exists

Most automated PR-review tools mix two different jobs:

- deciding what is risky
- explaining what the reviewer should check

This repo keeps those jobs separate.

- `scripts/risk-scan.sh` owns risk detection through readable path and size heuristics.
- `SKILL.md` defines how OpenClaw should turn those flags into a concise review checklist.

That split makes the behavior predictable enough for team use. If a rule is wrong, edit the script and review the change like normal code.

## Current Risk Flags

| Flag | Trigger |
| --- | --- |
| `config-change` | Spring-style app config or `.env` files |
| `db-migration` | SQL files, migration directories, or Java migration classes |
| `security-sensitive` | `security`, `auth`, `authn`, or `authz` paths |
| `infra-change` | Docker, Terraform, Helm, Kubernetes, or k8s paths |
| `dependency-update` | Lockfiles and dependency manifests |
| `breaking-change` | Optional PR body scan for breaking-change language |
| `large-diff` | Optional stats scan for >20 files or >500 changed lines |

## Install

```bash
git clone https://github.com/singhvishalkr/pr-review-prep.git \
  ~/.openclaw/skills/pr-review-prep

gh auth status
openclaw skill reload pr-review-prep
```

Required tools:

- `gh`
- `bash`
- `grep`

## Use

```text
review prep for https://github.com/owner/repo/pull/123
```

The skill reads PR metadata with `gh`, scans changed files with `scripts/risk-scan.sh`, and returns:

- PR title, author, branches, line counts, and changed-file count.
- Deterministic risk flags.
- Reviewer checklist.
- Open questions for the author.

## Run The Scanner Directly

```bash
gh pr diff https://github.com/owner/repo/pull/123 --name-only > /tmp/pr-files.txt
bash scripts/risk-scan.sh /tmp/pr-files.txt
```

With PR body and size inputs:

```bash
bash scripts/risk-scan.sh /tmp/pr-files.txt \
  --body /tmp/pr-body.txt \
  --stats 384 27 14
```

## Test

```bash
bash test/run.sh
```

The fixture tests cover risky file paths, clean PRs, breaking-change body text, and large-diff thresholds.

## Extend

Teams should fork the repo and add their own rules. Good candidates:

- Flag changes to retry configuration or cron schedules.
- Flag files owned by a narrow group of maintainers.
- Flag generated files that should only change through a specific build step.
- Flag API-contract files that require backward-compatibility checks.

Each new rule should be a small addition to `scripts/risk-scan.sh` plus a fixture in `test/`.

## License

MIT. See [LICENSE](LICENSE).
