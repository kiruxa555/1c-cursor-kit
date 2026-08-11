---
name: change-impact-review
description: "Карта влияния и проверка целостности связей перед правкой и при ревью BSL/CFE. Используй при доработке, исправлении бага, рефакторинге, когда правка может сломать другое место."
---

# Change Impact Review

## When to use

- Доработка или исправление логики (не только косметика).
- Ревью PR/фрагмента: «не сломает ли это другие места».
- Изменение контракта (структура, JSON, HTML, параметры процедуры).
- CFE: перехватчики, переопределяемые модули.

## Preconditions

1. Rule `change-impact-analysis.mdc` — карта **до** правки.
2. Rule `code-review-checklist.mdc` — секция «Целостность связей» при **ревью**.
3. Project rule + `docs/architecture.md` — критичные цепочки проекта.

## Workflow

```
1. Anchor
   - object, module, method(s), layer (client/server/form)

2. Impact map (explore readonly if needed)
   - callers, callees, same metadata reads/writes
   - subscriptions, commands, HTTP handlers
   - CFE: borrow/patch/override modules
   - contracts: JSON/HTML field names, ids, version

3. Regression scenarios (3–5)
   - happy path + edge + error/rollback + rights if relevant

4. Change OR review diff
   - map each diff hunk → impact map row
   - flag orphan callers, broken contracts, duplicated logic

5. Verdict
   - PASS: map covered, scenarios listed, no High linkage gaps
   - NEEDS_WORK: missing callers check or contract mismatch
   - FAIL: known breakage in linked path

6. After fix (if editing)
   - rerun scenarios; read_lints; update docs/changelog
```

## Review output (add to 1c-bsl-review report)

Краткий блок **Linkage integrity** (не дублировать весь чеклист):

```markdown
### Linkage integrity
| Связь | Статус | Комментарий |
|-------|--------|-------------|
| Вызовы <метод> | OK / RISK | ... |
| Контракт JSON/HTML | OK / RISK | ... |
| Регресс-сценарии | N listed | ... |
```

Severity: разрыв связи без обновления consumer → **High**; неполная проверка вызовов → **Medium**.

## Do NOT

- Claim «ничего не сломается» без списка вызовов.
- Skip impact map on «small fix» in export API.
- Replace manual acceptance — only prepare map + scenarios.

## Related

- `code-exploration-guide.mdc` — как искать цепочки
- `agent-verification-patterns.mdc` — reconciliation loop для больших реестров
- `1c-bsl-review` — формат ответа ревью
