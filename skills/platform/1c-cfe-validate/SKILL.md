---
name: 1c-cfe-validate
description: "Валидация расширения конфигурации 1С (CFE). Используй после создания или модификации расширения для проверки корректности"
---

# /cfe-validate — валидация расширения конфигурации (CFE)

Проверяет структурную корректность расширения: XML-формат, свойства, состав, заимствованные объекты, **согласованность `ConfigDumpInfo.xml` и ролей**. Аналог `/cf-validate`, но для расширений.

## Проверка 14 (важно для XML-разработки)

- Каждый объект из `Configuration.xml` / `ChildObjects` должен быть в `ConfigDumpInfo.xml`.
- Объекты в `Roles/*/Ext/Rights.xml`, отсутствующие в дампе, — ошибка (типичное зависание конфигуратора на ~78%).
- Ручные права на **новые** РС/перечисления в расширении — предупреждение (лучше привилегированный режим в BSL).

Подробнее: `1c-meta-compile/reference/extension-cfe-checklist.md`, `rules/metadata/1c-role-rights.mdc`.

## Параметры

| Параметр | Обяз. | Умолч. | Описание |
|---------------|:-----:|---------|-------------------------------------------------|
| ExtensionPath | да | — | Путь к каталогу или Configuration.xml расширения |
| Detailed | нет | — | Подробный вывод (все проверки, включая успешные) |
| MaxErrors | нет | 30 | Остановиться после N ошибок |
| OutFile | нет | — | Записать результат в файл |

## Команда

```powershell
powershell.exe -NoProfile -File skills/1c-cfe-validate/scripts/cfe-validate.ps1 -ExtensionPath "src"
powershell.exe -NoProfile -File skills/1c-cfe-validate/scripts/cfe-validate.ps1 -ExtensionPath "src/Configuration.xml"
```
