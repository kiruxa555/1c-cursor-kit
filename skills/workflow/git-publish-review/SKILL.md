---
name: git-publish-review
description: "Проверка перед commit/push/PR: секреты, личные пути, blocklist, LICENSE/NOTICE. Используй перед публикацией на GitHub, force-push, orphan rewrite."
---

# Git Publish Review

## When to use

- Пользователь просит commit / push / PR / «залей на GitHub».
- Force-push, orphan branch, rewrite history.
- Публикация нового публичного репозитория.

## Workflow

```
1. Read rule git-publish-hygiene.mdc
2. Run scanner:
   - before commit:  .\tools\Test-PublishHygiene.ps1 -Scope Staged
   - before push/CI: .\tools\Test-PublishHygiene.ps1 -Scope Tree
3. Classify findings (Critical / Warning)
4. Fix Critical or ask user; for public repo close LICENSE/NOTICE warnings
5. Only then propose git commands (still no commit/push without explicit ask)
```

## Do NOT

- Commit or push without explicit user request.
- Force-push without explicit request.
- Ignore Critical findings «чтобы быстрее залить».
- Путать с ревью BSL (`1c-bsl-review` / `1c-security-checklist`).

## Optional

```powershell
.\tools\Install-GitHooks.ps1          # local pre-commit
.\tools\Test-PublishHygiene.ps1 -Scope Tree -FailOnWarning
```

Blocklist (gitignored): скопировать `templates/publish-blocklist.txt.example` → `publish-blocklist.txt`.
