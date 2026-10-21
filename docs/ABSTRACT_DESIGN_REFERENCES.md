# Абстрактный язык классов и интерфейса

10 октября 2026. Последний запрос автора: избегать конкретных образов класса, искать уникальность в более сдержанной абстрактной части художественного эскиза. Рассмотреть дополнительные референсы и собственные идеи. Абстрактные потоки и цвет можно оживлять по событию, без перебора.

Предыдущая интерпретация со шлемом отозвана; проверенные игровые действия от визуальной оценки не зависят. Пользовательские портреты, фото и изображения предметов сохраняются как содержимое приложения.

## Референсы

1. [Google Design · Illustrating the Gemini App](https://design.google/library/gemini-ai-visual-design). Направленные градиенты, мягкие цветовые поля и движение, которое визуально поддерживает взаимодействие. Для QDnD интересны локальный поток и переход состояния; конкретная реализация и палитра проектируются самостоятельно.
2. [Endel · приложение и режимы](https://endel.io/focus). Разные режимы представлены различными абстрактными рисунками. Для классов полезна идея собственной пластики/ритма внутри общей системы. Это референс графического языка, не предложение копировать интерфейс приложения или его содержание.
3. [Google Design · M3 Expressive](https://design.google/library/expressive-material-design-google-research). Масштаб, форма, цвет и движение работают вместе с группировкой и доступностью. Уже просмотрены примеры, включая управляемую форму в интерфейсе дыхания.

Снимок первого референса: `evidence/reference-gemini-flows.jpg`; второго: `evidence/reference-endel-patterns.jpg` в каталоге текущих визуализаций `qdnd-cycle-2026-10-06`. Это снимки просмотренных публичных референсов, не продуктовые активы.

## Собственное предложение для QDnD — ещё не принято

Сохраняется понятная композиция пульта. Часть поверхности получает несколько текучих полос или мягких цветовых слоёв. Текст, числа и активные цели касания остаются в спокойной читаемой зоне. Класс различается направлением, ритмом и характером деформации; общие формы, типографика и качество взаимодействия едины.

| Класс | Возможный характер | Возможный отклик на действие |
|---|---|---|
| Воин | Собранные направленные ленты, контролируемое напряжение | Короткий импульс проходит по поверхности после успешного применения приёма |
| Бард | Мягкие ритмические волны | Сдержанный волновой отклик при использовании вдохновения |
| Чародей | Перетекающие цветовые слои | При обмене ресурсов слои сходятся и расходятся в направлении фактического обмена |
| Колдун | Вложенные поля и более сосредоточенный центр | Короткое изменение глубины при расходе Магии договора |

Это гипотезы, а не основание приписывать персонажу новые состояния. Графика не заменяет реальный запас и не вводит фиктивные таймеры/проценты готовности. Композиция и основные взаимодействия каждого класса прорабатываются отдельно.

Предварительный ориентир движения: один локальный отклик длительностью порядка половины секунды после подтверждённого события; значения меняются своевременно и не ждут окончания анимации. Не запускать эффект от простого пролистывания. Учитывать отключение анимаций, невидимые панели, сворачивание, частые действия и энергопотребление. Точные параметры ещё подбираются.

## Визуальный эскиз

Новый эскиз выполнен встроенным imagegen: из предыдущего художественного варианта убраны предметные классовые иллюстрации, сохранены текучие цветовые поверхности. Это **предложение для оценки характера графики**, не снимок приложения и не принятый экран. Площадь, контраст и плотность рисунка ещё требуют адаптации к рабочему листу.

![Эскиз абстрактных поверхностей](/home/quriee/.codex/visualizations/2026/10/05/01a10e5a-a02f-7b93-8865-baa8f99c921c/qdnd-cycle-2026-10-06/evidence/fighter-abstract-design-study.png)

Исходный результат: `exec-53214122-8fbb-4dfe-8d63-8b44fbdc9140.png` в generated_images текущего чата; копия сохранена в `evidence/fighter-abstract-design-study.png`. Код приложения и установленный Pixel не менялись после этого уточнения направления. Следующий шаг определяется оценкой референсов/эскиза автором.

## Запрос последнего эскиза

Последующая итерация после замечания «Пока не совсем то» — [изолированные нативные эскизы D](CLASS_FLOW_STUDIES_2026-10-10.md): три класса, векторный рисунок внутри управляющих поверхностей и один ограниченный отклик по касанию. Этот вариант тоже ожидает визуальной оценки автора.

Режим — встроенный imagegen, редактирование собственного предыдущего эскиза `exec-e69d39e2-317b-4e82-9d4d-fc143b3d611e.png`, непрозрачный фон. Результат сохранён для обсуждения, не используется как растровый экран приложения.

```text
Use case: ui-mockup. Make ONE targeted conceptual revision to the supplied interface: replace every representational CLASS illustration with restrained, beautiful NON-FIGURATIVE FLOW GRAPHICS. The user likes the flowing coloured ribbons, tonal movement and expressive surfaces, but explicitly rejects helmets, shields, weapons, people and themed emblems. Preserve the flowing abstract SECOND layer of the reference, not its foreground figures.

Remove the helmet in the header and in the main tile, the running human figure in Action Surge, the literal shield in Indomitable, and the weapon/shield pictures in passive chips. There must be NO armour, helmets, people, weapons, animals, faces, mascots, shields or figurative class emblems anywhere. Small standard navigation icons are still allowed as functional UI.

Keep the compact control-centre layout: a main Second Wind control, two smaller tactical controls alongside it. All Russian text and the exact remaining-use values "1 / 1" stay readable and semantically unchanged. Use contemporary humanist sans-serif type, a unified family of soft shapes, warm ivory app background and the existing teal/coral/amber palette.

Art direction: subdued flowing colour bands and soft directional light integrated into the surfaces. Their amount and contrast are controlled so this remains an RPG tool, not a gallery of wallpaper artworks. Let the main tile contain two or three fluid teal/cream ribbons that gather quietly toward a corner. Action Surge gets a short directed coral band suggesting acceleration without depicting an object. Indomitable gets a calm amber field with a few nested fluid contours that do NOT make a shield silhouette. These patterns should occupy roughly a quarter to a third of each surface, leaving stable quiet areas for numbers and labels. No figurative focal object is to be substituted. No noisy textures, sparkle storms, ornate borders, heavy skeuomorphism or generic flat empty buttons.

The title header should be clean typography "Воин" and "Чемпион · 9 уровень", no illustrated banner. Passive styles become small quiet text chips with subtle tonal colour, no large artwork. Standard compact sheet navigation remains at the top. Retain a strong class personality through direction, rhythm and colour, not pictures. Imagine these abstract fields could briefly animate after a successful action, then settle; the image shows a calm resting state, not a nonstop effect.

Exact game copy remains: "Воин", "Чемпион · 9 уровень", "Второе дыхание", "1к10 + 9 ОЗ", "Всплеск действий", "Несгибаемый", "Короткий отдых", "Длительный отдых", "Оборона", "Критический удар · 19–20". Each active control has "1 / 1". Do not introduce invented readiness scores, cooldowns, other game values, or marketing slogans. Raw straight-on mobile screen concept, no phone body.
```
