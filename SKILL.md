---
name: pr-review-prep
description: "Prep a GitHub pull-request review by pulling the diff with `gh`, flagging risky files via heuristics, and emitting a reviewer checklist. Use when: (1) the user pastes a GitHub PR URL and asks for a review/checklist, (2) the user wants a pre-review summary before a 1:1 code review, (3) the user asks \"what should I look for in this PR?\". NOT for: merging PRs, writing code review comments that auto-post to GitHub, or reviewing non-GitHub PRs (GitLab/Bitbucket)."
metadata:
  {
    "openclaw":
      {
        "emoji": "🦞",
        "requires": { "bins": ["gh", "bash"] },
        "install":
          [
            {
              "id": "brew",
              "kind": "brew",
              "formula": "gh",
              "bins": ["gh"],
              "label": "Install GitHub CLI (brew)",
            },
            {
              "id": "apt",
              "kind": "apt",
              "package": "gh",
              "bins": ["gh"],
              "label": "Install GitHub CLI (apt)",
            },
          ],
      },
  }
---

# PR Review Prep

Produce a structured review checklist for a GitHub pull request, with risk flags
derived from file paths rather than model guesswork. Use the `gh` CLI for all
GitHub reads; use `scripts/risk-scan.sh` for the deterministic risk heuristic.

## When to use (trigger phrases)

Use this skill immediately when the user asks any of:

- "review prep for <PR URL>"
- "what should I look at in <PR URL>?"
- "give me a checklist for <PR URL>"
- "is <PR URL> safe to merge?"

## Output contract

The skill returns a markdown document with these sections, in order:

1. **Header** — `PR #N — <title>` with author, base → head branch, additions/deletions, changed-file count.
2. **Risk flags** — every flag emitted by `scripts/risk-scan.sh` as a bullet, or "No heuristic risks found." if none.
3. **Reviewer checklist** — 4–8 action-oriented items combining:
   - one item per risk flag (from the heuristic),
   - at least one item covering test coverage for the diff,
   - one item asking "what is the rollback plan if this ships broken?" if any risk flag fires.
4. **Open questions** — 0–3 items the reviewer should ask the author, derived from the PR body or missing context.

Keep each bullet a single line. No prose paragraphs in the output.

## Quick start

```bash
# Dependencies: gh (authenticated), bash
gh auth status

# Run the skill against a PR URL
PR_URL="https://github.com/owner/repo/pull/123"
gh pr view "$PR_URL" --json number,title,author,baseRefName,headRefName,additions,deletions,changedFiles,body \
  > /tmp/pr.json

gh pr diff "$PR_URL" --name-only > /tmp/pr-files.txt

bash scripts/risk-scan.sh /tmp/pr-files.txt
```

Then combine the JSON summary + risk flags into the output contract above.

## Heuristic rules (source of truth: `scripts/risk-scan.sh`)

The script emits one flag per line. Current rules:

| Pattern                                                            | Flag                                                |
| ------------------------------------------------------------------ | --------------------------------------------------- |
| `**/application*.yml`, `**/application*.yaml`, `.env*`             | `config-change` — confirm per-env overrides exist   |
| `*Migration.java`, `**/migrations/**`, `*.sql`                     | `db-migration` — check rollback and dual-write plan |
| `**/security/**`, `**/auth/**`, `**/authz/**`                      | `security-sensitive` — require second reviewer      |
| `Dockerfile`, `**/*.tf`, `**/helm/**`, `**/k8s/**`                 | `infra-change` — request SRE eyes                   |
| `**/*.lock`, `package-lock.json`, `go.sum`, `Gemfile.lock`         | `dependency-update` — scan for new transitive CVEs  |
| PR body contains `BREAKING CHANGE` or title starts with `feat!:`   | `breaking-change` — check consumer compatibility    |
| Diff touches >20 files OR >500 changed lines                       | `large-diff` — suggest splitting before merging     |

Rules live in the script so they are auditable in git history. When the user
asks to tune the rules, edit `scripts/risk-scan.sh`, not this SKILL.md.

## Example invocation

User: "review prep for https://github.com/example/api/pull/42"

Agent runs the three `gh`/`bash` commands above, gets (a) PR JSON metadata and
(b) risk flags. The agent then emits:

```markdown
# PR #42 — Add tenant-scoped rate limits

Author: @jane · `main` ← `feat/rate-limit-v2` · +384 −27 across 14 files

## Risk flags

- `config-change` — confirm per-env overrides exist
- `security-sensitive` — require second reviewer

## Reviewer checklist

- [ ] Verify `application-prod.yml` has the new `ratelimit.*` keys set (config-change)
- [ ] Require a second reviewer with security context (security-sensitive)
- [ ] Confirm unit and integration tests exist for the new limiter branches
- [ ] Ask author for the rollback plan if the limits misfire in prod
- [ ] Check that metrics/alerts are wired for `ratelimit_rejected_total`

## Open questions

- What happens to in-flight requests when a tenant hits its limit mid-stream?
- Is there a feature flag so this can be dark-launched per tenant?
```

## When NOT to use

- **Non-GitHub PRs** — GitLab/Bitbucket use different CLIs. Tell the user so.
- **Posting comments to GitHub** — this skill only drafts. Use the `github` skill with explicit consent to post.
- **Deep code semantics** — the heuristic is path-based on purpose. For "does this code have a bug?" hand off to `coding-agent`.

## Design notes

- **Heuristic over LLM for risk tagging**: file-path patterns are cheap,
  deterministic, and auditable. The LLM is used only to compose the checklist
  prose and the open questions, where judgement helps.
- **Never auto-post**: the output is always a draft for the human reviewer.
  This is a deliberate policy choice, not an oversight.
- **Tune in the open**: new risk patterns are PRs against `scripts/risk-scan.sh`.
  A team adopting this skill should fork the repo and add their own rules.
