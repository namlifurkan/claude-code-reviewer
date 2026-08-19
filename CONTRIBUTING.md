# Contributing

Thanks for looking. This is a small shell tool, so the bar for contributing is low and the
review is friendly.

## Before you open a PR

- **Open an issue first for anything larger than a fix.** It saves you writing code that goes
  in a direction the project is not taking.
- **One change per PR.** A rename and a feature in the same diff is two reviews.
- **Test it against a real repo.** This tool posts comments on GitHub. A bug here is visible to
  other people, so "it runs" is not the same as "it works".

## Running it locally

```bash
git clone https://github.com/namlifurkan/claude-code-reviewer.git
cd claude-code-reviewer
cp config.json config.local.json      # point it at a repo you own
./setup.sh
./scripts/review-pr.sh <repo-name> <pr-number>
```

Use a throwaway PR on a repo you control. Do not test against someone else's project.

## Shell conventions

The scripts target bash and are expected to run on macOS, Linux, and Windows under WSL or Git
Bash. That rules out a few conveniences:

- `set -euo pipefail` at the top of every script.
- Quote every expansion. Paths contain spaces on Windows more often than you would like.
- No GNU-only flags. `sed -i` differs on BSD and macOS ships BSD; use a temp file or `perl -pi`.
- No `readlink -f`. macOS does not have it.
- Prefer `jq` over string parsing for anything JSON, since `jq` is already a dependency.
- Check exit codes on anything destructive. A silent failure that leaves state behind is worse
  than a loud one.

## Adding a skill

Skills live in `skills/<name>/skill.md` and describe how a repo should be reviewed. The
existing ones are examples rather than defaults; copy the closest and edit.

A good skill file is specific about what to flag and, more importantly, what to ignore. The
failure mode of an automated reviewer is not missing things, it is commenting on everything
until people stop reading it.

## What this project is not

It is not trying to become a general CI platform, a hosted service, or a replacement for human
review. It reads a diff, asks Claude Code about it, and posts inline comments. Contributions
that keep it that size are the easiest to merge.
