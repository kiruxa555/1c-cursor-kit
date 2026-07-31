# 1c-cursor-kit

Единый набор **rules** и **skills** для разработки 1С в Cursor без дублирования upstream-репозиториев.

## Источники (merge, не fork всего подряд)

| Upstream | Роль | Лицензия |
|----------|------|----------|
| [Desko77/cursor-1c-skills](https://github.com/Desko77/cursor-1c-skills) | Canonical: skills + rules | MIT |
| [comol/ai_rules_1c](https://github.com/comol/ai_rules_1c) | Workflow: `caveman`, `handoff`, agents, commands | informal («берите и используйте») |
| [fairballer-rgb/universal_1c_rules](https://github.com/fairballer-rgb/universal_1c_rules) | Routing: `agent_routing`, `bsp_libraries` | MIT |

Подробности: [NOTICE](NOTICE). Лицензия этого репозитория: [LICENSE](LICENSE) (MIT).

## Быстрый старт

```powershell
# После clone репозитория:
cd <путь-к-клону>\1c-cursor-kit

# 1. Синхронизация из upstream (нужен git + сеть)
.\tools\Sync-Upstream.ps1

# При необходимости очистить перед повторным sync:
# .\tools\Clean-Kit.ps1

# 2. Установка в глобальный Cursor
.\install.ps1 -Profile Standard

# 3. Проверка
.\tools\Inventory-Kit.ps1 -CompareInstalled
```

## Профили установки

| Профиль | Rules | Skills | Когда |
|---------|-------|--------|-------|
| **Minimal** | 3 core BSL | router + bsl-review | Лёгкий контекст, ревью кода |
| **Standard** | все rules | platform + domain | УТ/CFE, расширения, обработки |
| **Full** | все | + workflow + optional | OpenSpec, agents, утилиты |

## Проектные rules

Глобальный kit **не заменяет** проектный контекст. В каждом репозитории 1С:

1. Скопировать `templates/project-rule.mdc.template` → `.cursor/rules/<project>-project.mdc`
2. Заполнить плейсхолдеры (`{{PROJECT_NAME}}`, docs anchor, архитектура)
3. **Не** копировать полный набор skills в `.cursor` проекта — rules/skills уже глобально после `install.ps1`

## Обновление

```powershell
.\tools\Sync-Upstream.ps1 -Force    # перезаписать при конфликте размера
.\install.ps1 -Profile Standard
```

## Принципы дедупликации

1. **Один canonical skill** на `name` из frontmatter
2. **Rules по id** (имя файла); при конфликте — более полный файл (больше байт)
3. **Проект** = 1× `alwaysApply` project rule + глобальные `agent_requestable`
4. **User rules** в Cursor Settings — только личные предпочтения, не дублировать BSL-стандарты
5. **Kit-owned** skills (см. `skillKitOwned` в manifest) не перезаписываются sync

## Версия

См. `manifest.yaml` → `version`. После sync обновляйте вручную при существенных изменениях.
