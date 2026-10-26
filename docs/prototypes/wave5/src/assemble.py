"""Assembles docs/prototypes/wave5/index.html from the wave 2 foundation
(tokens, sheets, drums, dice, peeks) and the wave 5 css/js and the app's real palettes."""
import sys
W = sys.argv[1]
src = open('docs/prototypes/wave2/index.html').read().split('\n')
L = lambda a, b: '\n'.join(src[a - 1:b])
css_base = L(19, 116) + '\n' + L(146, 150) + '\n' + L(171, 173) + '\n' + L(232, 300) + '\n' + L(888, 906) + '\n' + L(1137, 1162) + '\n' + L(182, 230) + '\n' + L(301, 359) + '\n' + L(526, 617) + '\n' + L(659, 703) + '\n' + L(960, 995)
start = next(i for i, l in enumerate(src) if l.startswith('<svg width="0"'))
end = next(i for i in range(start, len(src)) if src[i].strip() == '</svg>')
symbols = '\n'.join(src[start:end]) + '\n' + open('docs/prototypes/wave4/src/symbols.svg').read() + '\n' + open(W + '/symbols.svg').read() + '\n</svg>'
js_base = L(1275, 1384) + '\n' + L(1571, 1692)
fonts = '\n'.join(f'@font-face{{font-family:{f};font-weight:{w};src:url(../../../assets/fonts/{n})}}' for f, w, n in [
    ('Rubik', 400, 'Rubik-Regular.ttf'), ('Rubik', 500, 'Rubik-Medium.ttf'), ('Rubik', 600, 'Rubik-SemiBold.ttf'),
    ('Inter', 400, 'Inter-Regular.ttf'), ('Inter', 500, 'Inter-Medium.ttf'), ('Inter', 600, 'Inter-SemiBold.ttf'), ('Inter', 700, 'Inter-Bold.ttf')])
html = f'''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content">
<title>QDnD · Волна 5</title>
<style>
/* Wave 5 prototype: settings with a live preview, the libraries and their
   imports, moving a hero between devices, the hero's own card editor and
   the launch. Built on the accepted wave 0-4 language: the app's fonts,
   its six palettes in both themes, AppMotion springs. */
{fonts}
{css_base}
{open(W + '/w5.css').read()}
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
    <span style="font:600 12px/1 var(--body);letter-spacing:.12em;text-transform:uppercase;color:var(--tertiary)">QDnD · волна 5 · прототип</span>
    <h1>Настройки и библиотеки</h1>
    <p>Живой прототип: запуск, настройки с живым предпросмотром всех шести палитр в светлой и тёмной теме, библиотеки контента с импортом XML и ZIP, перенос героя между устройствами и анкета героя.</p>
    <div id="controls"></div>
  </aside>
</div>
<script>
{js_base}
{'const APP_PALETTES = ' + open(W + '/palettes.json').read() + ';\n' + open(W + '/w5.js').read()}
</script>
</body>
</html>
'''
open('docs/prototypes/wave5/index.html', 'w').write(html)
print('assembled', len(html))
