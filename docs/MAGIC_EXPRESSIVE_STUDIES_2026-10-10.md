# Вкладка магии — Expressive в действующей палитре

10 октября 2026. Статус: два художественных эксперимента для оценки автора; не нативный интерфейс и не установленная сборка.

Прямой запрос автора: сохранить удачную композицию, типографику и интерактивные элементы предыдущего эскиза, приблизив их к Google Expressive, мягкости iOS и небольшому локальному glassmorphism. Существующие палитры и распределение функций по разделам сохраняются. Иллюстрированный персонаж как часть интерфейса исключён; пользовательский аватар остаётся в своей карточке.

## Что показано

- [Вариант 1 — асимметрия и раскрытие умения](/home/quriee/.codex/visualizations/2026/10/05/01a10e5a-a02f-7b93-8865-baa8f99c921c/qdnd-cycle-2026-10-06/evidence/magic-expressive-study-v2.png). Основное действие слева, два приёма справа; раскрытие Второго дыхания показывает выражение до броска.
- [Вариант 2 — цельная панель и отклик](/home/quriee/.codex/visualizations/2026/10/05/01a10e5a-a02f-7b93-8865-baa8f99c921c/qdnd-cycle-2026-10-06/evidence/magic-expressive-study-v3.png). Второе дыхание занимает верхнюю часть, два приёма объединены снизу. После расхода показаны 0/1 и фактическое восстановление +14 ОЗ (пример броска 5 + уровень воина 9); остальные запасы остаются 1/1.

Взяты светлые цвета Monokai из lib/core/theme/app_palettes.dart, существующий порядок пяти навигационных иконок и расположение классового модуля из AbilitiesTab. На вкладке магии нет перенесённых ОЗ/КД/атак/отдыха из Обзора. Навигационный островок — единственный предлагаемый стеклянный элемент.

## Визуальная проверка и границы

Числа, порядок вкладок, три умения, уровень 9 и подкласс сохранены в обоих рисунках. Второй вариант обходится без ошибочной к20 рядом с выражением к10: пиктограмма здесь условная и требует нативной векторной отрисовки. В первом генератор оставил многогранник, напоминающий к20 — это не утверждённый символ для к10. Рендер не гарантирует точных hex-цветов, размеров шрифта, blur или зон касания; в коде используются ColorScheme и действующие темы. Градиенты не становятся обязательными фоновыми анимациями.

Показанные строки пассивных умений — краткое содержание, подробное правило должно открываться по касанию. Число 8 — иллюстрация счётчика, нативный виджет получает его из фактических умений. Положительная обратная связь автора о предыдущем эскизе не означает приёмку этих вариантов.

После применения умения отклик показывает именно фактически восстановленные ОЗ, с учётом максимума/формы и возможной ошибки сохранения; число +14 в картинке не означает обещания всегда лечить на полный результат броска. Ручные превышения запасов сохраняются по действующей политике. Временный отклик не заменяет выражение умения навсегда. Ни один рисунок не добавляет отмену действия или повторное бесплатное применение.

Нативная реализация требует RU/EN, большого шрифта, всех тем, уменьшенного движения, состояний пустого/повышенного запаса, нескольких классов и проверки сохранения. Макеты не меняют эти требования и сами их не подтверждают.

## Генерация

Встроенный imagegen. Первый вариант — генерация с предыдущим эскизом и двумя снимками приложения как референсами. Второй — редактирование первого с изменением композиции и демонстрацией состояния после действия. Сохранены отдельными файлами без перезаписи предыдущего эскиза.

### Промпт варианта 1

```text
Use case: ui-mockup.
Asset: refined, high fidelity QDnD mobile app design experiment. Create TWO large, flat portrait app screens side by side in a single crisp image on a subdued neutral backdrop, no hardware mockup, no perspective. Each screen 390x844 logical px aspect ratio, text comfortably readable at normal phone size. Outside captions only: "Магия · умения воина" under left, "Второе дыхание" under right.

Input reference roles:
Image 1 (adventure-sheet-study-v1.png): preserve the praised expressive typographic hierarchy, scale contrasts, intelligent connected grouping, sculpted touch controls and meaningful interaction, but CHANGE the palette, remove portrait illustration, remove Overview contents, and put class abilities on the MAGIC tab as specified below.
Image 2 (fighter-console-final-light.png): reference ONLY for actual EXISTING app warm Monokai colors, icon-only top navigation island, class header and correct class abilities screen architecture. This old layout was rejected as too plain; do NOT copy its huge empty card, helmet, homogenous rounded rectangles or weak typography.
Image 3 (journal-main-sheet.png): reference ONLY for continuity with current app warmth, compactness and restrained color; do NOT copy its Overview HP content to this Magic screen.

User constraints take priority: Google's Material 3 Expressive in composition, iOS softness, VERY SMALL localized glassmorphism as a cherry on top. Keep existing color schemes and existing division into tabs. Large character illustrations are entirely unwanted: NO person, portrait, silhouette, helmet, class illustration or decorative hero image anywhere. User avatar would belong to the existing character card on Overview, which is collapsed/absent on this Magic page. Do not invent a new persistent header. This is a modern adventure player companion, not a fitness dashboard or a fantasy poster.

Actual app light MONOKAI palette, adhere faithfully:
background #FCFAF4, text #49483E; surfaces #F8F5EC and #F1EDE2;
soft cyan container #E0F1F1 with deeper cyan #008EA6 for small accents;
soft pink container #F6DEE4 with #F92672 ONLY for tiny action emphasis, not large saturated areas;
soft sand/ochre container #F2E5CF with #C26900 for small reserve accents.
No large black/dark green blocks, no orange marketing color, no high contrast surface split. Text contrast must remain readable. Personality comes from hierarchy, interlocking soft shapes and useful controls, not arbitrarily added textures or ribbons. Soft restrained elevation, no heavy outlines. Use Roboto-style contemporary humanist sans, assertive headings and disciplined secondary text.

LEFT: believable complete current MAGIC/abilities tab, fighter9 Champion.
At top safe area a single compact horizontal capsule navigation island containing exactly five aligned icons, no text: home, bar chart, magic wand (selected with small dot), backpack, book. The island is the ONLY glass area: subtly frosted pale cyan, delicate top-edge light, slight optical blur of the quiet background underneath, conservative transparency. No shining chrome or transparent text backgrounds elsewhere. This existing nav stays at top.
Below this island: beautifully composed header "Воин", large 30px bold left, smaller cyan "Чемпион ›" under it, a quiet "9-й уровень" chip on the right and an overflow control. Not multiple repeated headings. No QD&D marketing masthead, no avatar card.
Hero class control composition: one beautifully connected expressive group with precisely THREE usable ability areas, confidently designed but calm in color. Dominant SECOND WIND on left about 58% width, two quieter abilities stacked on right. Avoid independent equal bento rectangles: make a coordinated family of subtly interlocking curved shapes with a shared visual rhythm, enough clear separation for tap targets. Left primarily soft cyan; right upper subtle pink, right lower soft sand. Preserve previous successful draft's carefully aligned labels/figures and asymmetry, but now calm and integrated in current app.
SECOND WIND area:
top compact heart/pulse pictogram in consistent icon family;
title "Второе дыхание" bold, intentional 2-line typography, not squeezed;
resource "1 / 1" clearly attached;
a dedicated attractive small FACETED k10 die control with "1к10 + 9" and separate small "ОЗ", not a giant literal 3D die or k20 icon;
compact footer "Короткий отдых" and purposeful arrow on same baseline. Touchable sculpted inset action, no bland empty square button.
UPPER RIGHT area:
small consistent lightning icon;
"Всплеск действий" arranged neatly 2 lines;
reserve "1 / 1" and restrained one-dot availability cue;
footer "Короткий отдых".
LOWER RIGHT area:
small consistent circular-arrow/save icon, NOT a helmet;
"Несгибаемый", do not truncate;
reserve "1 / 1";
footer "Долгий отдых".
All reserves exact, readable and purposeful. No HP, AC, weapons, movement, initiative, spell slots for this fighter9 Champion who cannot cast.
Below the hero group: TWO modest informative chips "Оборона" and "Улучшенный критический удар". They fit neatly with legible font; wrap into two rows as needed. Do not use dumb tiny illegible overflow pills.
Below a calmer section "Пассивные умения" with a modest count "8" and chevron. Show two clean text rows with breathing room, not an enormous inner card: "Дополнительная атака" · "Две атаки за действие"; "Замечательный атлет" · "Половина бонуса мастерства". These are existing abilities of this level, not separate manual resource counters. Prefer real content to meaningless filler lines.
Leave a little breathing room at screen bottom. One consistent scroll page, no duplicate bottom nav, no rest buttons added here. No navigation labels or sections migrated from Overview.

RIGHT: exact same MAGIC page behind a compact softly dimmed bottom sheet opened by tapping Second Wind. Keep same nav and underlying composition. The background dimming should be mild, not black-out or dark theme.
A warm opaque rounded sheet in lower ~40% of screen, generous drag affordance at top, with subtle coordinated shape/elevation. Header "Второе дыхание", secondary "Восстановить 1к10 + 9 ОЗ". A clean large typographic dice expression "1к10 + 9" in a beautiful small faceted k10-control zone, tiny "Доступно: 1 из 1". Primary action is a soft-cyan filled rounded wide button, darker cyan text, label "Бросить и восстановить", cohesive small die icon. This is before the roll: no made-up result, no fake resource changes, no keyboard.
The hierarchy should feel lively, polished and coherent with the main action composition, not a calculator.

Quality: distinctive practical UI design, refined layout and elegant contemporary touch controls. Preserve the previous concept's strong typography and intentional hierarchy while respecting established calm app tones, real screen architecture and absence of character imagery. Glass ONLY on nav. No random flowing bands, arbitrary rings, fake charts, thin fantasy borders, paper texture, image gallery, marketing illustration or uniformly repeated blank pills. Accurate Cyrillic labels, especially ОЗ, умения (not навыки), 1к10 (not d20).
```

### Промпт варианта 2

```text
Use case: ui-mockup, targeted composition refinement.
Input image is an EDIT TARGET: the just-created two-screen QDnD light Monokai MAGIC abilities screen and Second Wind sheet. Preserve exact palette, content, native app navigation architecture, typography quality, restrained soft depth, and absence of portraits. Produce a NEW alternative design, not an identical copy. Still TWO large readable 390x844 portrait screens side by side, flat crisp image, no phone hardware. Left caption "Цельная панель", right "Отклик на действие". This explores a more compact, more ORIGINAL integrated class control.

Main required change: RECOMPOSE the hero abilities group. Currently it is a tall cyan card next to two stacked pink/sand rounded boxes. Replace that generic layout with a SINGLE beautifully shaped, compact connected control panel, approx 350 logical px wide and 250 high. Three purposeful tap regions joined into a coherent expressive soft surface. Primary Second Wind takes the entire upper 55%, pale cyan with soft angled/curved lower edge. Its title "Второе дыхание" prominent left, resource "1 / 1" small top-right. Below title "1к10 + 9 ОЗ" strong, with "Короткий отдых" small. A discrete, beautiful 54px touchable sculpted die control sits right, with exact text "к10". Make the die a SIMPLE faceted kite/bipyramid suggestion, NOT an icosahedron (k20). This is the primary action control; a useful play/arrow cue may accompany it.
Lower 45% consists of two adjacent subordinate action regions, pale rose on left and pale sand on right, their upper contours nest gently with upper main action. NO gaps creating three independent equal rectangles. A shared coordinated soft silhouette and careful contours, clear enough to distinguish the tappable areas. Left exact "Всплеск действий", reserve "1 / 1", small lightning pictogram. Right exact "Несгибаемый", reserve "1 / 1", consistent simple circular-arrow pictogram. Their small footers read "Короткий отдых" and "Долгий отдых". All labels readable, comfortably spaced, no clipped text. Do not decorate panel with waves, ribbons, botanical flow or arbitrary charts. Originality from functional composition and form, not graphic pattern.
The whole group should be lively, characterful, composed, more compact than reference, not an Apple wellness dashboard.

Preserve navigation island with exactly 5 icons, magic wand selected with small dot. ONLY this island has subtle iOS-like frosted glass: pale cyan softly translucent, restrained edge highlight, small believable blur. Under it class heading "Воин", subtitle "Чемпион ›", quiet "9-й уровень", overflow menu. No new character card/avatar, no hero illustration. Existing section architecture and tab selection remain.

Because compact group now uses less height, arrange "Оборона" and "Улучшенный критический удар" as calmly placed text chips below, then passive section with "Пассивные умения", count "8", rows "Дополнительная атака" / "Две атаки за действие", "Замечательный атлет" / "Половина бонуса мастерства". Good editorial rhythm and clean breathing room, keep real content not fillers.
Main warm background #FCFAF4, text #49483E, soft cyan #E0F1F1 with small #008EA6 accents, pink #F6DEE4 with tiny #F92672 accents, sand #F2E5CF with #C26900 accents. No black/dark green/orange surface blocks. Soft container depth, no heavy outline. Great font scale hierarchy; non-title content readable at phone scale.

RIGHT screen: instead of a modal covering half the page, show exact same redesigned page AFTER Second Wind was used, demonstrating a restrained functional inline response. Primary Second Wind region now shows resource "0 / 1", used state with quieter tone, its label still readable. Within the same primary action area an integrated compact feedback strip says "+14 ОЗ" with small text "Восстановлено". Correct example: roll k10 result 5 + fighter9 = 14, no other HP figures shown on this Magic page. The actual recovery is linked to the specific ability. Small discreet last roll expression "5 + 9" below; no fake busy toast or confetti or global modal. Other two abilities still "1 / 1". A calm compact informational affordance may read "До короткого отдыха". Do not add a duplicate Second Wind below or a button claiming to undo; user explicitly does NOT want Ctrl-Z mechanics. No new expenditures or restoring unavailable charges. After-action state should be recognizable at a glance without making all content wash out. Glass remains ONLY navigation. No keyboard. Clearly intelligible action-state design.
Cyrillic labels exact. Output is a refined visual proposal, no explanatory paragraphs inside UI.
```

