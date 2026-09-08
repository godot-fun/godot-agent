---
name: git-commit-message
description: Generate single-line Conventional Commits messages by analyzing git diffs and repository history. Use when the user asks for commit messages or help writing commits.
---

# Git Commit Message

## Rules

When inspecting changes for commit messages or change summaries:

- **Only** `git diff HEAD` defines what changed (all local changes vs last commit)
- Never run `git diff --staged`, `git diff --cached`, or `git diff HEAD --cached`
- Never infer changes from `git status` "Changes to be committed"
- Never warn about or analyze index vs working-tree mismatches from the staged list
- If `git diff HEAD` is empty, there is nothing to commit — stop

## Quick Start

When the user needs a commit message:

1. Inspect changes: `git status`, `git diff HEAD` (all local changes vs last commit)
2. Read recent style: `git log --oneline -15`
3. Draft a single-line Conventional Commits message matching repo conventions
4. Return the message only — do not commit unless explicitly asked

Run status, diff, and log in parallel when possible.

## Message Format

Single line only — **no body**:

```
<type>[<scope>]: <subject>
```

| Part | Rules |
|------|-------|
| **type** | Required. One of: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `build`, `style`, `revert` |
| **scope** | Optional. Module or area in square brackets (e.g. `[auth]`, `[api]`, `[ui]`). Omit brackets entirely if unclear |
| **subject** | Imperative mood, lowercase, no trailing period, ≤72 chars. Must stand alone — pack intent into this line |

**Never** add a blank line or body paragraph after the subject.

### Type Selection

| Type | When |
|------|------|
| `feat` | New user-facing capability |
| `fix` | Bug fix |
| `refactor` | Code change without behavior change |
| `docs` | Documentation only |
| `test` | Tests only |
| `chore` | Maintenance, deps, tooling |
| `perf` | Performance improvement |
| `ci` | CI/CD config |
| `build` | Build system or external deps |
| `style` | Formatting, whitespace (no logic change) |
| `revert` | Revert a prior commit |

### Scope Guidelines

- Use existing scopes from recent commits when present
- Prefer short, stable names: `auth`, `db`, `config`, `deps`
- Drop scope rather than guess incorrectly

## Workflow

```
Task Progress:
- [ ] Run git status + `git diff HEAD`
- [ ] Read recent git log for style alignment
- [ ] Identify primary change type and scope
- [ ] Draft single-line subject (imperative, self-contained)
- [ ] Check for secrets or files that should not be committed
- [ ] Present message to user
```

### Split vs Single Commit

- **One logical change** → one commit
- **Unrelated changes** (feat + fix in different areas) → suggest splitting
- **Large refactor + feature** → suggest separate commits

## Safety

- Never include secrets (.env, credentials, tokens) in the commit
- Warn if changed files look sensitive
- Do not run `git commit` unless the user explicitly requests it

## Output

Present exactly one line in a copy-paste block:

```
feat[auth]: add jwt token refresh endpoint
```

```
fix[ui]: prevent double submit on checkout form
```

## CLI

Copy-paste commands: [cli/git-commit-message.md](../../../cli/git-commit-message.md)

## Additional Resources

- More examples: [examples.md](examples.md)
