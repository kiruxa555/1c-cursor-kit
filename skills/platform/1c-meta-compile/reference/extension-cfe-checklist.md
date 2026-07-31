# Расширение (CFE): чеклист после meta-compile

Типичная ошибка: объекты есть в `Configuration.xml`, но конфигуратор **зависает на ~78%** («Завершение загрузки конфигурации») или падает без явной ошибки.

## Причины

| Проблема | Симптом | Решение |
|----------|---------|---------|
| Объект не в `ConfigDumpInfo.xml` | Зависание при загрузке из файлов | Добавить запись в дамп или пересохранить объект в конфигураторе |
| Права в `Roles/.../Rights.xml` на новый объект без дампа | Зависание на финальном этапе | **Не править Rights.xml вручную** для новых РС/перечислений |
| Устаревший `configVersion` в дампе | Предупреждения, иногда сбой | После правок — выгрузка из конфигуратора или обновление версий |

## Обязательный порядок после `meta-compile` в расширении

1. **Проверить `ConfigDumpInfo.xml`** — для каждого нового элемента `ChildObjects` в `Configuration.xml` должна быть строка:
   ```xml
   <Metadata name="InformationRegister.Имя" id="uuid" configVersion="..."/>
   ```
   Плюс вложенные `Dimension` / `Resource` / `ManagerModule` / `Module` по образцу соседних объектов.

2. **Запустить `/cfe-validate`** на каталог расширения — проверка 14 ловит рассинхрон дампа и ролей.

3. **Права на новые объекты**
   - Предпочтительно: `УстановитьПривилегированныйРежим(Истина)` в менеджерах РС.
   - Если права нужны в роли — добавлять **только через конфигуратор** после успешной первой загрузки расширения, не правкой `Rights.xml` в Git.
   - На **Enum** права в роли не давать — см. `rules/metadata/1c-role-rights.mdc`.

4. **Загрузка в базу** — только после пунктов 1–2.

## Быстрая ручная проверка (PowerShell)

```powershell
$cfg = [xml](Get-Content "Extensions\MyExt\Configuration.xml" -Encoding UTF8)
$dump = [xml](Get-Content "Extensions\MyExt\ConfigDumpInfo.xml" -Encoding UTF8)
$expected = $cfg.MetaDataObject.Configuration.ChildObjects.ChildNodes |
  Where-Object { $_.NodeType -eq 'Element' } |
  ForEach-Object { "$($_.LocalName).$($_.InnerText)" }
$inDump = $dump.ConfigDumpInfo.ConfigVersions.Metadata | ForEach-Object { $_.name }
$expected | Where-Object { $_ -notin $inDump }
```

Пустой вывод — все верхнеуровневые объекты учтены в дампе.

## Когда не трогать дамп вручную

Если сомневаетесь в UUID и `configVersion` — создайте объект в конфигураторе/EDT и сделайте **выгрузку в файлы**: платформа сама заполнит `ConfigDumpInfo.xml`.
