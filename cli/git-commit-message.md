# git-commit-message

Agent-only skill — draft Conventional Commits messages. No bundled script under `.ai/`.

Inspect changes before drafting (run in parallel when possible):

```bash
git status
git diff HEAD
git log --oneline -15
```

Commit only when the user explicitly asks:

```bash
git commit -m "type[scope]: subject"
```
