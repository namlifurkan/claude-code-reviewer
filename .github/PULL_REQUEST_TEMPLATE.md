## What this changes

<!-- One or two sentences. If it needs more, it is probably two pull requests. -->

## Why

<!-- The problem, not the patch. Link an issue if there is one. -->

## How it was tested

<!-- Which platform, and against which repo. "Ran it on a throwaway PR on my own repo" is a
     complete answer; "it builds" is not, since this tool posts comments other people see. -->

- [ ] Tested against a real pull request on a repository I control
- [ ] Ran on: <!-- macOS / Linux / WSL / Git Bash -->

## Checklist

- [ ] One change per pull request
- [ ] Scripts still start with `set -euo pipefail` and quote their expansions
- [ ] No GNU-only flags, no `readlink -f` (macOS ships BSD tools)
- [ ] README updated if behaviour or configuration changed
