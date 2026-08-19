# Security

## Reporting a vulnerability

Email **hello@riffiter.com** with `claude-code-reviewer` in the subject. Please do not open a
public issue for anything exploitable.

Expect a first reply within a few days. This is a side project maintained by one person, so
that is a realistic promise rather than an SLA.

## What this tool has access to

Worth understanding before you run it, because the answer is "quite a lot":

- **Your GitHub token**, through `gh`. It reads pull requests and writes comments on every repo
  listed in `config.json`. It uses whatever scopes your `gh` login already has.
- **Your repository contents**, including diffs of unmerged work.
- **Your Claude Code session.** Diffs are sent to Anthropic through the same channel as any
  other Claude Code prompt, under the same terms.

It does not send anything to any other third party, and it has no telemetry.

## Files it refuses to read

`config.json` carries an `exclude_patterns` list, defaulting to `.env*`, private keys, `*.pem`,
`*secret*` and lockfiles. Diffs matching those patterns are dropped before anything is sent.

**That list is a safety net, not a boundary.** It matches on filename, so a secret committed
into a normally-named file will be read like any other line. Do not rely on it to keep
credentials out of a prompt; keep credentials out of the diff.

## Running it safely

- Give it a token scoped to the repositories you actually want reviewed, not a personal token
  with access to everything you can see.
- Review `config.json` before running `setup.sh` on a machine where `gh` is logged in to a work
  account.
- The cron job runs unattended. Check the logs occasionally.
