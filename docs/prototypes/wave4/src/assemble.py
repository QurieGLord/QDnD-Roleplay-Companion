"""Assembles docs/prototypes/wave4/index.html from the wave 2 foundation
(tokens, sheets, drums, dice, peeks) and the wave 4 css/js."""
import sys
W = sys.argv[1]
src = open('docs/prototypes/wave2/index.html').read().split('\n')
L = lambda a, b: '\n'.join(src[a - 1:b])
css_base = L(19, 116) + '\n' + L(146, 150) + '\n' + L(171, 173) + '\n' + L(232, 300) + '\n' + L(888, 906) + '\n' + L(1137, 1162) + '\n' + L(182, 230) + '\n' + L(301, 359) + '\n' + L(526, 617) + '\n' + L(659, 703) + '\n' + L(960, 995)
start = next(i for i, l in enumerate(src) if l.startswith('<svg width="0"'))
end = next(i for i in range(start, len(src)) if src[i].strip() == '</svg>')
symbols = '\n'.join(src[start:end]) + '\n' + open(W + '/symbols.svg').read() + '\n</svg>'
js_base = L(1275, 1384) + '\n' + L(1571, 1692)
fonts = '\n'.join(f'@font-face{{font-family:{f};font-weight:{w};src:url(../../../assets/fonts/{n})}}' for f, w, n in [
    ('Rubik', 400, 'Rubik-Regular.ttf'), ('Rubik', 500, 'Rubik-Medium.ttf'), ('Rubik', 600, 'Rubik-SemiBold.ttf'),
    ('Inter', 400, 'Inter-Regular.ttf'), ('Inter', 500, 'Inter-Medium.ttf'), ('Inter', 600, 'Inter-SemiBold.ttf'), ('Inter', 700, 'Inter-Bold.ttf')])
html = f'''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content">
<title>QDnD · Волна 4</title>
<style>
/* Wave 4 prototype: the journal — the chronicle of notes and quests, the
   entry page, the writing sheet and the Atlas of people, places and
   events. Built on the accepted wave 0–3 language: the app's fonts,
   AppPalettes colours, AppMotion springs. */
{fonts}
{css_base}
{open(W + '/w4.css').read()}
</style>
</head>
<body>
{symbols}

<div class="stage">
  <div class="phone" id="phone">
    <div class="layer" id="app"></div>
    <div class="modal" id="modal"></div>
    <div class="toast glass" id="toast" role="status"></div>
  </div>
  <aside class="panel" aria-label="Варианты">
    <span style="font:600 12px/1 var(--body);letter-spacing:.12em;text-transform:uppercase;color:var(--tertiary)">QDnD · волна 4 · прототип</span>
    <h1>Журнал</h1>
    <p>Живой прототип: летопись записей и заданий, страница записи с живыми именами, чистый лист для письма, Атлас людей, мест и событий. Кампания — история Элиана из Cycle-журнала, дописанная до седьмой сессии.</p>
    <div id="controls"></div>
  </aside>
</div>
<script>
{js_base}
{open(W + '/w4.js').read()}
</script>
</body>
</html>
'''
open('docs/prototypes/wave4/index.html', 'w').write(html)
print('assembled', len(html))
