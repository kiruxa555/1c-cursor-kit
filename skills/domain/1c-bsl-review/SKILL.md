---
name: 1c-bsl-review
description: "Ревью и рефакторинг BSL: расширения CFE, внешние обработки EPF, модули конфигурации. Режимы quick/standard/full, делегирование explore, формат ответа. Используй когда пользователь присылает фрагмент 1С на ревью или просит рефакторинг."
---

# BSL Code Review — CFE, EPF, конфигурация

## When to use

- Пользователь прислал фрагмент `.bsl` / `.os` на ревью или рефакторинг.
- Запрос: «проверь код», «найди проблемы», «улучши реализацию».
- Контекст: **расширение (CFE)**, **внешняя обработка (EPF)** или типовая конфигурация.

## Preconditions

1. Прочитать project rule с `alwaysApply` (если есть в workspace) — якорь docs, границы архитектуры.
2. Подтянуть специализированные rules по globs — не дублировать их в ответе.

## Workflow

```
1. Parse request
   - mode: quick | standard | full (default: standard)
   - artifact: CFE | EPF | CF
   - extension name, object, borrowed: yes/no

2. Context (delegate, don't bloat parent context)
   - Need original method / callers / similar code → Task explore readonly
   - Project docs anchor → read from project rule / docs/
   - CFE borrow/patch/diff → skills 1c-cfe-* only when task requires metadata changes
   - BSP alternative → 1c-ssl-patterns / search_ssl before suggesting custom code

3. Review (apply silently)
   - 1c-coding-standards, form_module_rules, anti_patterns
   - 1c-security-checklist (injection, RLS, secrets, privileged mode)
   - CFE: 1c-extension-patterns
   - code-review-checklist for severity + linkage integrity
   - standard/full: change-impact-review (callers, contracts, regress scenarios)

4. Respond
   - Verdict → Context → Linkage integrity (table) → Problems table → Solution → Code → Checklist
   - Three variants ONLY if mode=full or user asked

5. If files edited → read_lints on changed paths
```

## Do NOT

- Repeat full checklist in the response.
- Propose edits to base configuration when the task is extension/EPF-only — respect project boundaries.
- Add obvious comments (see 1c-coding-standards).
- Run Cursor `/review-security` / bugbot unless user asked (security checklist rule — always apply silently).
- Paste entire subagent reports — synthesize findings only.

## Mode hints

| Signal | Mode |
|--------|------|
| Small snippet, typo, naming | quick |
| Default refactor / review | standard |
| &ИзменениеИКонтроль on Post/Write/Conduct, multi-module architecture | full |

## User message template

```markdown
Режим: standard
Артефакт: CFE / Extensions/<ИмяРасширения>
Объект: Обработка.Имя, модуль формы
Заимствование: нет
Задача: ревью + рефакторинг

```bsl
...
```
```
