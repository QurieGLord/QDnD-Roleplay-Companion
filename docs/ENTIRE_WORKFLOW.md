# Работа с Entire

[Entire](https://entire.com) записывает сессии агентов (Claude Code и др.) как **чекпоинты** — промпты, ответы, вызовы инструментов, изменения файлов — и привязывает их к коммитам. Страница проекта: [entire.com/gh/QurieGLord/QDnD-Roleplay-Companion](https://entire.com/gh/QurieGLord/QDnD-Roleplay-Companion) — вкладки Overview, Commits, **Sessions** (чекпоинты) и Analytics.
Документация: [docs.entire.com](https://docs.entire.com) (полный индекс — `docs.entire.com/llms.txt`).

Подключено 29 октября 2026, Entire CLI 0.12.2.

## Как устроено в этом репозитории

| Что | Где | В Git |
|---|---|---|
| Настройки проекта: включено, чекпоинты — в приватный репозиторий, хранение `git-refs`, привязка коммитов без вопроса, телеметрия выключена | `.entire/settings.json` | да |
| Что Entire не коммитит (логи, личные настройки) | `.entire/.gitignore` | да |
| 10 хуков Claude Code (начало и конец сессии, промпт, остановка, субагенты) | `.claude/settings.json` | да |
| Навык для агентов «как пользоваться Entire» | `.claude/skills/entire/SKILL.md` | да |
| Git-хуки (`prepare-commit-msg`, `commit-msg`, `post-commit`, `post-rewrite`, `pre-push`) | `.git/hooks/` | нет — ставятся `entire enable` на каждой машине |
| Личные настройки машины | `.entire/settings.local.json` | нет |

**Чекпоинты уходят только в приватный репозиторий** [QurieGLord/QDnD-Roleplay-Companion-sessions](https://github.com/QurieGLord/QDnD-Roleplay-Companion-sessions). Основной репозиторий публичный, а расшифровки сессий содержат всё сказанное агенту и все пути. Поэтому направлять чекпоинты в `origin` нельзя.

Хуки безопасны без CLI: если `entire` не установлен, они молча пропускаются.

## Для автора

### Один раз (на этой машине CLI уже стоит)

1. Войти: `entire login` — откроется браузер (на машине без графики — `entire login --device`, код вводится в браузере). Проверка: `entire auth status`.
2. Дать Entire доступ к обоим репозиториям: на entire.com в настройке репозиториев — **Configure GitHub App** → выбрать `QDnD-Roleplay-Companion` и `QDnD-Roleplay-Companion-sessions` (или «All repositories») → сохранить. Без доступа к `-sessions` вкладка Sessions останется пустой.
3. Проверить: `entire status` — должно быть «Enabled · Claude Code · Checkpoints sync to: dedicated checkpoint remote».
4. По желанию — забрать историю последних 30 дней (в т. ч. сессии редизайна): `entire import claude-code`. Импортированные чекпоинты только для чтения.
5. По желанию — Git через ближайшее зеркало Entire: `entire repo remote add entire`, затем `git push entire` наряду с `origin`. Не обязательно: GitHub остаётся основным.

### Новая машина или новый клон

```bash
curl -fsSL https://entire.com/install.sh | bash   # ставит в ~/.local/bin
git clone https://github.com/QurieGLord/QDnD-Roleplay-Companion.git
cd QDnD-Roleplay-Companion
entire enable --agent claude-code                 # настройки уже в репозитории, ставит git-хуки
entire login
```

Обновить CLI — тот же установщик. Версия — `entire version`.

### Каждый день

- Работаете с агентом как обычно. Сессия пишется сама: Claude Code нужно запустить **после** `entire enable` (уже запущенная сессия хуки не подхватит).
- Коммитите как обычно. Git-хук сам добавит в сообщение строку `Entire-Checkpoint: …` и свяжет коммит с сессией (настройка `commit_linking: always`, вопрос не задаётся).
- `git push` — код уходит в `origin`, чекпоинты — в приватный `-sessions`.
- Смотреть: entire.com → проект → **Sessions** / **Commits**; или в терминале:

| Действие | Команда |
|---|---|
| Состояние | `entire status` |
| Чекпоинты текущей ветки | `entire checkpoint list` |
| Что было в коммите/сессии | `entire checkpoint explain <id или коммит>` |
| Поиск по истории сессий | `entire search "запрос"` |
| Сводка недавней работы | `entire recap` |
| Все сессии / текущая | `entire session list`, `entire session current` |
| Продолжить остановленную сессию | `entire session resume` (выбор) или `entire session resume <ветка>` — выдаст `claude -r …` |
| Расход токенов | `entire session tokens`, `entire checkpoint tokens <id>` |
| Ваша активность по всем репозиториям | `entire activity` |
| Что-то не пишется | `entire doctor` |

### Если нужно остановить

- Не отправлять сессии с этой машины: `entire configure --local --skip-push-sessions`.
- Удалить чекпоинт отовсюду: `entire checkpoint delete <id>`.
- Выключить Entire в репозитории: `entire disable` (включить снова — `entire enable`).

## Правила приватности

- Чекпоинты — **только** в `QDnD-Roleplay-Companion-sessions`, репозиторий остаётся приватным. Не менять `checkpoint_remote` и не делать `-sessions` публичным.
- Маскировка секретов (ключи, токены, строки подключения) работает «по возможности»; картинки не маскируются вовсе. Пароли, токены и личные данные агенту не вставлять.
- Личные файлы (`Компендиум.zip`, `Кюри.xml`) по-прежнему не коммитятся; упоминания в сессиях попадают только в приватный репозиторий.

## Правила для агентов

Краткая версия — в `.docs/CLAUDE.md` / `AGENTS.md` / `GEMINI.md`, раздел «Entire». Машиночитаемая справка всегда соответствует установленной версии: `entire agent-help`.

- Сессия записывается хуками сама; агенту ничего не нужно запускать.
- Не править `.entire/settings.json`, хуки в `.claude/settings.json`, `.git/hooks/*` и не менять назначение чекпоинтов без прямой просьбы автора.
- Коммиты — по-прежнему только по просьбе автора. Строку `Entire-Checkpoint:` не добавлять и не удалять вручную: её ставит хук.
- Не пушить чекпоинты вручную и не направлять их в `origin`.
- Чтобы восстановить контекст прошлой работы («почему так сделано», «что решили»), сначала — `entire search`, `entire checkpoint explain`, `entire recap`, затем отчёты в `docs/`.
- Если хук или `entire status` сообщает об ошибке — сказать автору и предложить `entire doctor`; не отключать Entire самостоятельно.
