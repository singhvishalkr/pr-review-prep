# pr-review-prep

An [OpenClaw](https://github.com/openclaw/openclaw) skill that turns a GitHub
pull-request URL into a structured review checklist, with risk flags derived
from file-path heuristics rather than model guesswork.

This is the companion skill to the DEV.to post
[_Why This Backend Engineer Stopped Calling LLM APIs From Every Service And Started Running a Local Agent Instead_](https://dev.to/).

## Why this exists

Pull-request review is the place where your organisation's risk tolerance shows
up in practice. Most "AI PR reviewer" tools fail the same way: they make the LLM
decide _what is risky_, which is the one thing the LLM is actually bad at, because
your risk model is not in the training data.

This skill inverts that:

- **Deterministic heuristics** (a small bash script, ~60 lines) decide which
  files are risky. Every rule is one line of `grep -E` you can read in git.
- **The LLM** composes the human-readable checklist and open questions _from
  those flags_, where language-model judgement actually helps.

The split means you can audit the risk logic in a PR, and the skill's behaviour
is predictable enough to trust in a team setting.

## Install

```bash
# 1. Clone next to your other OpenClaw skills
git clone https://github.com/<you>/pr-review-prep.git \
  ~/.openclaw/skills/pr-review-prep

# 2. Ensure prerequisites
gh auth status              # must be authenticated
which bash && which grep    # standard POSIX tools

# 3. Reload skills in the OpenClaw dashboard or run:
openclaw skill reload pr-review-prep
```

The skill advertises its dependencies in `SKILL.md` under `metadata.openclaw.requires`,
so OpenClaw will offer to install `gh` via Homebrew or apt on first use.

## Use

In any channel wired to OpenClaw (CLI, Slack, iMessage):

```text
> review prep for https://github.com/openclaw/openclaw/pull/123
```

The agent pulls the diff with `gh`, runs `scripts/risk-scan.sh` against the file
list, and returns a markdown checklist with:

- PR header (title, author, branches, +/− line counts)
- Risk flags from the heuristic
- Reviewer checklist (one item per flag + test coverage + rollback)
- Open questions derived from the PR body

See [`SKILL.md`](SKILL.md) for the full output contract and an example.

## Extend

Teams should fork and add their own heuristics. Good candidates:

- Flag changes to cron schedules or retry configuration.
- Flag PRs that touch a "golden file" that only two engineers own.
- Flag PRs that modify the PR-template itself (so the person reviewing the
  template is aware it will propagate).

All of these are one-line additions to `scripts/risk-scan.sh`. Open a PR and the
rules become part of your team's reviewable policy, not a prompt hiding inside
an agent config.

## License

MIT. See [LICENSE](LICENSE).
