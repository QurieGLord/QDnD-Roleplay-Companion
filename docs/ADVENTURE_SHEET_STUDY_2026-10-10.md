# Приключенческий лист — новое визуальное исследование

Статус: автор положительно оценил композицию, интерактивные элементы и типографику. Палитра/контраст, портрет и перенос классовых умений в Обзор не приняты. Макет не установлен в приложение. Коррективы закреплены в [дизайн-коде](DESIGN_LANGUAGE.md), следующий эксперимент — [вкладка магии в действующей палитре](MAGIC_EXPRESSIVE_STUDIES_2026-10-10.md). Предыдущий поиск D отклонён.

Основа — четыре изображения, приложенных автором 10 октября: масштаб и глубина голубой доски, мягкость мятно-персикового интерфейса, редакционная собранность TwoWheels Story и контрастная композиция Meetgen. Переносим принципы, разрабатывая собственный лист для игры.

Показываем целый обзор воина и раскрытие Второго дыхания. В обоих состояниях ОЗ остаются 24/76: бросок и лечение ещё не выполнены. Доступность зарядов и эффект каждого действия должны быть понятны до касания. Палитра, расположение и форма — эксперимент, не обязательные новые правила приложения.

Границы: растровый эскиз не подтверждает реальные размеры зон касания, работу правил, доступность, RU/EN, большой шрифт или анимации. Эти требования сохраняются для нативного прототипа. Сгенерированный текст сверяется визуально; возможные неточности не становятся правилами продукта.

Результат: [макет листа и раскрытия умения](/home/quriee/.codex/visualizations/2026/10/05/01a10e5a-a02f-7b93-8865-baa8f99c921c/qdnd-cycle-2026-10-06/evidence/adventure-sheet-study-v1.png).

Проверка результата: числа 24/76, КД 19, инициатива +2, скорость 30 фт, три запаса 1/1 и атака +7 с уроном 1к8+3 сохранены. На раскрытии умения ОЗ не меняются до броска. Портрет — пример пользовательского аватара, не обязательная классовая иллюстрация. Рендер добавил предметный знак к Несгибаемому и неодинаковый вес иконок: это не новое правило дизайн-кода. При переносе выбранного направления нужна единая семья пиктограмм; значок броска не должен ошибочно обозначать к20 для броска к10. Дублирующий процент ОЗ и декоративный рисунок за портретом также не обязательны. Точное размещение классовой панели между Обзором и Магией обсуждается отдельно от художественной композиции; макет не подтверждает перенос функций.

## Запрос генерации

Встроенный imagegen, четыре изображения автора переданы как визуальные референсы. Промпт:

```text
Use case: ui-mockup.
Create ONE polished, distinctive mobile UI design proposal for QDnD, a Dungeons & Dragons player companion. This is an adventure character sheet for active play, not a wellness tracker, generic dashboard, productivity app or fantasy artwork gallery. Output a crisp portrait design board with TWO large, readable flat app screens side by side, on a quiet warm-gray background. No perspective, no device hardware. Main screen on left, contextual interaction on right. Small captions outside screens: "Лист героя" and "Касание умения". Design at realistic 390x844 logical px proportions; sharp Cyrillic typography.

Input images are STYLE REFERENCES only, never edit targets:
Image 1: borrow composed variation in scale, beautiful soft surfaces, integrated large numerical controls, coherent visual hierarchy; not its gibberish copy.
Image 2: borrow controlled depth, touchable surfaces, gentle ambient color and clarity; avoid fitness rings and fitness dashboard composition.
Image 3: borrow editorial rhythm and sense of journey, compact believable information and grounded functional elegance.
Image 4: strongest reference for bold contrast, original connected shapes and restrained graphic personality; do not copy its logo, calendar, orange background or exact layout.
Produce an ORIGINAL art direction that combines these qualities and belongs to an adventurer's sheet.

Design character: confident, modern, expressive, intimate. A crafted field companion, with the understated visual tension of a tactical folio. Warm pale chalk and muted pale lichen for large surfaces, deep ink-green for contrasting interactive regions, selective ember-orange to identify the available primary action. Use a warm modern humanist sans with strong weight/size hierarchy. Soft coordinated curves, a few purposeful offset/interlocking shapes, almost no borders. Rich composition with asymmetry and negative space serving reading. Solid high-contrast legible text. No faux parchment, bevelled fantasy hardware, swords/helmets/shields as giant artwork, flowing decorative ribbons, meaningless gauges, excessive glass, concentric decorative rings, 3D scene or photos around phones. A few subtle geometric cuts/marks may reinforce tactical identity only when linked to state. Not an array of equal rectangular cards.

LEFT SCREEN — actual overview of a level-9 fighter named Эйрик:
Top compact back arrow, small QD&D wordmark, overflow menu. Header "Эйрик" in beautiful large type, secondary "Человек · Воин 9" and a compact "Чемпион" tag. Name and status should be part of a single composed hero region, not a tall banner.
A clear slim navigation island near the top with five compact familiar icons and Russian labels: "Обзор" selected, "Статы", "Магия", "Вещи", "Журнал". Small but accessible, no duplicate bottom navigation.
Main vitals region uses one ORIGINAL, beautifully composed connected surface rather than 4 identical tiles: dominant "24" with "/ 76" and label "ОЗ"; beside it integrated compact metrics "19" "КД", "+2" "Инициатива", "30 фт" "Скорость". A single simple segmented/continuous HP meter accurately filled about 32%; this is a real gameplay value, not generic decoration. Small condition chip "Отравлен" with discreet x, visually separate from buttons.
Below, class-specific section title "Тактика воина", small helper "Приёмы и запас сил". This is the defining designed region. One sculpted dark-ink surface integrates three abilities in a composed asymmetric hierarchy, not a list of 3 identical buttons:
- prominent ember/lichen action area "Второе дыхание", readable reserve "1 / 1", compact "1к10 + 9 ОЗ", small directional arrow implying tap.
- quieter adjacent small regions "Всплеск действий" with "1 / 1" and "Несгибаемый" with "1 / 1". All labels fully readable. Resource counts visually belong to actions.
Available versus spent states use tone and a small functional resource dot, not four arbitrary stripes. Provide enough space for comfortable tapping.
Below a short "Атаки" section, one elegantly integrated attack row: "Длинный меч", prominent "+7", smaller "1к8 + 3 · рубящий", a discreet die-shaped roll control. No giant illustrated weapon.
At bottom a quiet paired rest control "Короткий отдых" and "Долгий отдых". Keep lower content comfortably contained, not cut off. Overall should feel like a real character sheet usable during a tense tabletop session, with practical information prioritized and personality achieved by composition.

RIGHT SCREEN — SAME design and same underlying character, showing tap on "Второе дыхание":
Underlying sheet visible but dimmed, recognizably same layout. A beautiful compact rounded lower sheet occupies lower 40%, with generous drag handle, clear heading "Второе дыхание", secondary "Восстановить 1к10 + 9 ОЗ". A large central "1к10 + 9" roll expression, attractive ember filled primary button "Бросить и восстановить", small reserve "Доступно: 1 из 1". This is a proposed before-roll interaction, so HP is STILL 24/76 and no fake result yet. No keyboard, no input focus, no magic swipe with undiscoverable interaction. The visual affordance is clear. Bottom sheet need not fill the whole screen.

Quality bar: an award-quality BUT IMPLEMENTABLE interface with thoughtful scale, rhythm, visual emphasis and originality comparable to the attached references. Make real game content central. Accurate clear Russian text, intentional alignment, comfortable spacing, distinct typography. Avoid generic calorie planner look, generic stacked bento tiles or blank minimalist pill buttons. No explanatory prose inside the screens beyond specified UI text.
```
