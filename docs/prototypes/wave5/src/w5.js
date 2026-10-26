/* ================= Wave 5: settings, libraries, transfer, the hero's card, launch ================= */
// APP_PALETTES holds the app's own colours, dumped from AppPalettes: six
// palettes in both themes and the calm «Базовый» scheme.
const PAL_ORDER = ['monokai', 'gruvbox', 'catppuccin', 'nord', 'everforest', 'roseOfDune'];
const PAL_NOTE = {
  monokai:['Тёплые поверхности, неоновые акценты', 'Warm surfaces, neon accents'],
  gruvbox:['Ретро: охра, мох и кирпич', 'Retro: ochre, moss and brick'],
  catppuccin:['Мягкая пастель', 'Soft pastel'],
  nord:['Сдержанная северная синева', 'Restrained arctic blue'],
  everforest:['Хвоя и тёплый свет', 'Pine and warm light'],
  roseOfDune:['Песок, специи и пыльная роза', 'Sand, spice and dusty rose'],
};
let set = {lang:'ru', mode:'system', palette:'monokai', basic:false};
const T = (ru, en) => set.lang === 'ru' ? ru : en;
const themeDark = () => set.mode === 'dark' || set.mode === 'system';
const palKey = (p = set.palette, dark = themeDark()) => `${p}-${dark ? 'dark' : 'light'}`;
// «Базовый режим» keeps the chosen palette and only calms it: accents lose
// a good part of their colour, surfaces turn nearly neutral, quiet text and
// outlines gain contrast. Glows and gradients go away (body.calm).
const grayOf = h => { const [r, g, b] = hex2(h), y = Math.round(.2126 * r + .7152 * g + .0722 * b); return '#' + [y, y, y].map(v => v.toString(16).padStart(2, '0')).join(''); };
const calmHex = (h, keep) => mix(h, grayOf(h), keep);
function palette(key){
  const p = APP_PALETTES[key];
  if (!set.basic) return p;
  const q = {...p};
  ['surface', 'low', 'cont', 'high', 'highest'].forEach(k => q[k] = calmHex(p[k], .35));
  ['primary', 'secondary', 'tertiary'].forEach(k => q[k] = calmHex(p[k], .62));
  ['pc', 'sc', 'tc'].forEach(k => q[k] = calmHex(p[k], .45));
  q.acc = p.acc.map(c => calmHex(c, .58));
  q.on = p.dark ? mix('#FFFFFF', p.on, .5) : mix('#000000', p.on, .5);
  q.muted = mix(q.on, q.surface, .88);
  q.outline = mix(q.on, q.surface, .5);
  return q;
}
function applyApp(key = palKey()){
  const p = palette(key), s = document.documentElement.style, put = (k, v) => s.setProperty('--' + k, v);
  document.body.classList.toggle('calm', set.basic);
  ['surface', 'low', 'cont', 'high', 'highest', 'primary', 'secondary', 'tertiary', 'outline', 'pc', 'sc', 'tc', 'muted'].forEach(k => put(k, p[k]));
  put('fg', p.on); put('on-primary', p.onPrimary); put('page', mix('#000000', p.surface, p.dark ? .2 : .045));
  p.acc.forEach((c, i) => put('a' + i, c)); put('heal', p.acc[3]);
  s.setProperty('color-scheme', p.dark ? 'dark' : 'light');
}

/* ---------- the table's data ---------- */
const HEROES = [
  {id:'elian', name:'Элиан', race:'Человек', cls:'Паладин', lvl:18, acc:1, hp:164},
  {id:'irsa', name:'Ирса', race:'Полуэльф', cls:'Друид', lvl:16, acc:3, hp:128},
  {id:'vex', name:'Векс', race:'Тифлинг', cls:'Плут', lvl:17, acc:4, hp:119},
];
const KINDS5 = [['items', 'Предметы', 'bag'], ['spells', 'Заклинания', 'magic'], ['races', 'Расы', 'person'], ['classes', 'Классы', 'shield'], ['bgs', 'Предыстории', 'book'], ['feats', 'Черты', 'star']];
const stat = (o, k) => o[k] || 0;
let SOURCES = [
  {id:'core', kind:'zip', name:'Мой компендиум', date:'12 октября', acc:1, modules:[
    {id:'rules', name:'Основные правила', path:'core/rules.xml', items:212, spells:361, races:9, classes:12, bgs:13, feats:42},
    {id:'gear', name:'Снаряжение', path:'core/items.xml', items:410},
  ]},
  {id:'extra', kind:'xml', name:'Заклинания-дополнение', date:'3 октября', acc:5, spells:84},
  {id:'home', kind:'xml', name:'Домашние правила стола', date:'20 октября', acc:3, items:12, spells:4, races:1, classes:1, bgs:2, feats:5},
];
const sumOf = (src, k) => src.modules ? src.modules.reduce((n, m) => n + stat(m, k), 0) : stat(src, k);
const totalOf = src => KINDS5.reduce((n, [k]) => n + sumOf(src, k), 0);
const ZIP = {name:'Сборник с игры.zip', ignored:2, entries:[
  {id:'all', path:'Compendium.xml', name:'Общий compendium', combined:true, items:634, spells:449, races:10, classes:13, bgs:15, feats:47, monsters:320},
  {id:'rules', path:'core/rules.xml', name:'Основные правила', rec:true, dup:true, items:212, spells:361, races:9, classes:12, bgs:13, feats:42},
  {id:'gear', path:'core/items.xml', name:'Снаряжение', rec:true, dup:true, items:410},
  {id:'xan', path:'extra/arcana.xml', name:'Тайная магия', rec:true, spells:41, feats:6, monsters:4},
  {id:'beasts', path:'bestiary.xml', name:'Бестиарий', unsupported:true, monsters:316},
  {id:'table', path:'homebrew/table.xml', name:'Ещё домашние правила', rec:true, items:9, races:1, bgs:1},
]};
let libEmpty = false;

/* ---------- navigation ---------- */
let stack = [{s:'lobby'}], settingsVariant = 'stage', libVariant = 'shelf', splashVariant = 'roll';
const cur = () => stack[stack.length - 1];
function go(screen){ stack.push(screen); buzz.tick(); show(1); }
function back(){ if (stack.length < 2) return; stack.pop(); buzz.tick(); show(-1); }
function show(dir = 0){
  render();
  const page = $('#app .page5');
  if (!dir || reduced || !page) return;
  page.animate([{transform:`translateX(${dir * 36}px)`, opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.snappy, .42)});
}
let painted = null;
function render(){
  const s = cur(), scr = $('#app .scroller'), y = painted === s && scr ? scr.scrollTop : 0; painted = s;
  const html = {lobby:lobbyHTML, settings:settingsHTML, library:libraryHTML, editor:editorHTML, splash:splashHTML}[s.s](s);
  $('#app').innerHTML = html;
  bind(s);
  if ($('#app .scroller')) $('#app .scroller').scrollTop = y;
  if ($('#controls')?.childElementCount) controls();
}
document.addEventListener('scroll', e => { if (!e.target.classList?.contains('scroller')) return;
  const bar = $('#app .top5'); if (bar && !bar.classList.contains('pinned')) bar.classList.toggle('titled', e.target.scrollTop > 90); }, true);
const top5 = (title, {lead = 'back', actions = '', pinned = false} = {}) => `<div class="top5 glass ${pinned ? 'pinned titled' : ''}">
  ${lead ? `<button type="button" class="round" data-a="${lead}" aria-label="${lead === 'back' ? 'Назад' : 'Закрыть'}">${icon(lead === 'back' ? 'back' : 'x')}</button>` : '<span class="sp40"></span>'}
  <div class="tb-title">${title}</div>${actions || '<span class="sp40"></span>'}</div>`;
const seal5 = (ic, acc, cls = '') => `<span class="seal5 ${cls}" style="--acc:var(--a${acc})">${icon(ic)}</span>`;
const n0 = n => n.toLocaleString('ru-RU');

/* ---------- the table (a stub of the lobby, to reach the wave 5 screens) ---------- */
function lobbyHTML(){
  return `${top5('Отряд', {lead:'', actions:`<button type="button" class="round" data-a="settings" aria-label="Настройки">${icon('settings')}</button>`})}
  <div class="scroller"><div class="page5">
    <header class="mh"><span class="cap" style="--acc:var(--a1)">QDnD · отряд</span><h1>Отряд</h1><p class="sub5">Набросок лобби — отсюда открываются экраны волны: настройки, перенос, анкета героя.</p></header>
    <div class="heroes5">${HEROES.map(h => `<div class="hcard" style="--acc:var(--a${h.acc})">
      <button type="button" class="hc-main" data-a="editor" data-h="${h.id}"><span class="hc-av">${h.name[0]}</span><span class="ft"><b>${h.name}</b><small>${h.race} · ${h.cls} ${h.lvl}</small></span></button>
      <button type="button" class="round sm" data-a="heroMenu" data-h="${h.id}" aria-label="Действия">${icon('more')}</button></div>`).join('')}</div>
    <button type="button" class="addhero" data-a="addHero">${icon('plus')}<span>Добавить героя</span></button>
  </div></div>`;
}
function heroMenu(id){
  const h = HEROES.find(x => x.id === id);
  openSheet(`<span class="bs-kicker">${h.name} · ${h.cls} ${h.lvl}</span><h2 class="bs-title">Герой</h2>
    <div class="blist">
      <button type="button" class="brow2" data-m="edit">${seal5('edit', 4)}<span class="ft"><b>Анкета героя</b><small class="muted">Имя, облик, личность, предыстория</small></span>${icon('fwd', 'chev')}</button>
      <button type="button" class="brow2" data-m="move">${seal5('share', 1)}<span class="ft"><b>Перенести героя</b><small class="muted">Файл для другого устройства или Fight Club 5</small></span>${icon('fwd', 'chev')}</button>
    </div>`, {onOpen(sh, close){
      $('[data-m="edit"]', sh).addEventListener('click', () => close(0, () => go({s:'editor', h:id})));
      $('[data-m="move"]', sh).addEventListener('click', () => close(0, () => transferSheet(id)));
    }});
}
function addHeroSheet(){
  openSheet(`<span class="bs-kicker">Отряд</span><h2 class="bs-title">Добавить героя</h2>
    <div class="blist">
      <button type="button" class="brow2 dim">${seal5('plus', 3)}<span class="ft"><b>Новый герой</b><small class="muted">Мастер создания — волна 6</small></span></button>
      <button type="button" class="brow2" data-m="qdnd">${seal5('download', 1)}<span class="ft"><b>Из файла QDnD</b><small class="muted">Полная копия героя с другого устройства · .qdnd</small></span>${icon('fwd', 'chev')}</button>
      <button type="button" class="brow2" data-m="fc5">${seal5('file', 4)}<span class="ft"><b>Из Fight Club 5</b><small class="muted">Лист персонажа · .xml</small></span>${icon('fwd', 'chev')}</button>
    </div>`, {onOpen(sh, close){
      $('[data-m="qdnd"]', sh).addEventListener('click', () => close(0, () => importHeroSheet('qdnd')));
      $('[data-m="fc5"]', sh).addEventListener('click', () => close(0, () => importHeroSheet('fc5')));
    }});
}

/* ---------- launch ---------- */
function splashHTML(){
  return `<div class="splash ${splashVariant}"><div class="sp-glow"></div>
    ${splashVariant === 'roll' ? `<div class="sp-die">${die('d20', '20', {cls:'xl'})}</div>` : ''}
    <div class="sp-mark" aria-label="QD&amp;D"></div>
    <div class="sp-word">${[...'Roleplay Companion'].map((ch, i) => `<i style="--i:${i}">${ch === ' ' ? '&nbsp;' : ch}</i>`).join('')}</div>
    <div class="sp-ver num">0.19 · Cycle</div></div>`;
}
function runSplash(){
  const el = $('.splash'); if (!el) return;
  const done = () => { if (cur().s !== 'splash') return; stack = [{s:'lobby'}]; render();
    if (!reduced) $('#app .page5').animate([{transform:'translateY(24px) scale(.98)', opacity:0}, {transform:'none', opacity:1}], {duration:620, easing:springEasing(SPR.gentle, .62)}); };
  if (reduced) { el.classList.add('in', 'landed'); return setTimeout(done, 700); }
  requestAnimationFrame(() => el.classList.add('in'));
  if (splashVariant === 'roll') {
    // A die tumbles onto the table, lands on 20 and turns into the mark.
    const d = $('.sp-die .die2');
    setTimeout(() => { buzz.light(); tumble([d], [20], 20, () => { buzz.medium(); el.classList.add('landed'); }); }, 120);
    setTimeout(done, 2500);
  } else { setTimeout(() => el.classList.add('landed'), 150); setTimeout(done, 1700); }
}

/* ---------- settings ---------- */
function palCard(p){
  const P = palette(`${p}-${themeDark() ? 'dark' : 'light'}`), on = set.palette === p;
  return `<button type="button" class="pal ${on ? 'on' : ''}" data-pal="${p}" aria-pressed="${on}" style="--ps:${P.surface};--pl:${P.low};--pc2:${P.cont};--pf:${P.on};--pp:${P.primary}">
    <span class="pal-mini"><i class="pm-bar"></i><i class="pm-card"><u></u><u></u></i><span class="pm-acc">${P.acc.map(c => `<i style="background:${c}"></i>`).join('')}</span></span>
    <b>${P.label}</b><small>${T(...PAL_NOTE[p])}</small>${on ? `<span class="pal-tick">${icon('check')}</span>` : ''}</button>`;
}
function previewHTML(){
  const h = HEROES[0];
  return `<div class="stage5" id="stage">
    <div class="st-card" style="--acc:var(--a1)"><span class="hc-av">${h.name[0]}</span><span class="ft"><b>${h.name}</b><small>${h.race} · ${h.cls} ${h.lvl}</small></span><span class="st-hp"><b class="num">${odo(132, 'sthp')}</b><small>/ ${h.hp}</small></span></div>
    <div class="st-bar"><i style="width:80%"></i></div>
    <div class="st-row"><span class="st-chip" style="--acc:var(--a0)">${icon('flame')}<b>Ярость</b></span><span class="st-chip" style="--acc:var(--a4)">${icon('shield')}<b class="num">КД 19</b></span><span class="st-chip" style="--acc:var(--a3)">${icon('heart')}<b>${T('Отдых', 'Rest')}</b></span></div>
    <div class="st-say">${icon('quote')}<span>${T('Привет, герой. Так выглядит твой лист.', 'Hello, hero. This is how your sheet looks.')}</span></div>
  </div>`;
}
function modeSeg(){
  return `<div class="modes" id="modes">${[['system', 'auto', T('Как в системе', 'System')], ['light', 'sun', T('Светлая', 'Light')], ['dark', 'moon', T('Тёмная', 'Dark')]].map(([v, ic, n]) =>
    `<button type="button" class="mode ${set.mode === v ? 'on' : ''}" data-mode="${v}" aria-pressed="${set.mode === v}"><i>${icon(ic)}</i><span>${n}</span></button>`).join('')}</div>`;
}
const libSummary = () => { const n = SOURCES.reduce((s, x) => s + totalOf(x), 0); return libEmpty ? T('Пока пусто', 'Empty for now') : `${SOURCES.length} ${plural(SOURCES.length, 'источник', 'источника', 'источников')} · ${n0(n)} ${plural(n, 'запись', 'записи', 'записей')}`; };
function settingsHTML(){
  const P = palette(palKey());
  const stageV = settingsVariant === 'stage';
  return `${top5(T('Настройки', 'Settings'))}
  <div class="scroller"><div class="page5">
    <header class="mh"><span class="cap" style="--acc:var(--a1)">QDnD · 0.19</span><h1>${T('Настройки', 'Settings')}</h1></header>
    ${stageV ? `${previewHTML()}
      <div class="palname"><span class="cap" style="--acc:var(--a1)">${set.basic ? T('Палитра · базовый режим', 'Palette · basic mode') : T('Палитра', 'Palette')}</span><b>${P.label}</b></div>
      <div class="pals strip5">${PAL_ORDER.map(palCard).join('')}</div>
      ${modeSeg()}` : `
      <div class="grp"><div class="grp-h">${seal5('palette', 1)}<b>${T('Внешний вид', 'Look')}</b></div>
        ${modeSeg()}
        <div class="palgrid">${PAL_ORDER.map(palCard).join('')}</div></div>`}
    <div class="${stageV ? 'rows5' : 'grp'}">
      ${stageV ? '' : `<div class="grp-h">${seal5('sliders', 4)}<b>${T('Поведение', 'Behaviour')}</b></div>`}
      <button type="button" class="row5 toggle5 ${set.basic ? 'on' : ''}" data-a="basic" aria-checked="${set.basic}">${seal5('calm', 3)}<span class="ft"><b>${T('Базовый режим', 'Basic mode')}</b><small>${T('Та же палитра, но тише: меньше пестроты, больше контраста и читаемости, без свечений', 'The same palette, quieter: less colour, more contrast and readability, no glows')}</small></span><span class="switch"></span></button>
      <div class="row5">${seal5('globe', 4)}<span class="ft"><b>${T('Язык', 'Language')}</b><small>${T('Интерфейс и названия правил', 'Interface and rule names')}</small></span>
        <span class="lang">${[['ru', 'Рус'], ['en', 'Eng']].map(([v, n]) => `<button type="button" data-lang="${v}" aria-pressed="${set.lang === v}">${n}</button>`).join('')}</span></div>
    </div>
    <div class="sec5"><h3>${T('Контент', 'Content')}</h3></div>
    <button type="button" class="libtile" data-a="library">
      <span class="lt-shelf">${(libEmpty ? [] : SOURCES).map((x, i) => `<i style="--acc:var(--a${x.acc});height:${36 + (i * 13) % 20}px;width:${10 + Math.min(14, Math.round(Math.log10(totalOf(x) + 1) * 4))}px"></i>`).join('')}<u></u></span>
      <span class="ft"><b>${T('Библиотеки', 'Libraries')}</b><small>${libSummary()}</small></span>${icon('fwd', 'chev')}</button>
    <button type="button" class="row5 tap" data-a="transfer">${seal5('share', 1)}<span class="ft"><b>${T('Перенос героев', 'Move heroes')}</b><small>${T('Файл QDnD для другого устройства или XML для Fight Club 5', 'A QDnD file for another device or XML for Fight Club 5')}</small></span>${icon('fwd', 'chev')}</button>
    <div class="sec5"><h3>${T('О приложении', 'About')}</h3></div>
    <div class="about">
      <div class="ab-mark"><span class="sp-mark sm"></span><span class="ft"><b>Roleplay Companion</b><small class="num">0.19.1 · beta</small></span></div>
      <div class="ab-grid"><span><small>${T('Разработчик', 'Developer')}</small><b>Qurie</b></span><span><small>${T('Лицензия', 'License')}</small><b>MIT</b></span></div>
      <div class="ab-links"><a class="lnk5" href="#" data-a="link">${icon('code')}GitHub</a><a class="lnk5" href="#" data-a="link">${icon('send')}Telegram</a></div>
    </div>
    <button type="button" class="footer5" data-a="footdie" aria-label="Бросить к20">${die('d20', '20', {cls:'sm', attrs:'id="footdie"'})}<span>${T('Готово к следующему броску', 'Ready for the next roll')}</span></button>
  </div></div>`;
}
// A new theme does not cut in: every colour of the app flows from the old
// value to the new one at once (registered colour properties transition),
// as AnimatedTheme lerps the ColorScheme in the app.
function flood(e, change){
  const root = document.documentElement;
  if (!reduced) root.classList.add('morph');
  change(); applyApp(); live(render);
  clearTimeout(flood.t); flood.t = setTimeout(() => root.classList.remove('morph'), 700);
}
function bindSettings(){
  $$('[data-pal]').forEach(b => b.addEventListener('click', e => {
    if (set.palette === b.dataset.pal) return; buzz.light(); flood(e, () => { set.palette = b.dataset.pal; }); }));
  $$('[data-mode]').forEach(b => b.addEventListener('click', e => { if (set.mode === b.dataset.mode) return; buzz.light(); flood(e, () => { set.mode = b.dataset.mode; }); }));
  $$('[data-lang]').forEach(b => b.addEventListener('click', () => { if (set.lang === b.dataset.lang) return; set.lang = b.dataset.lang; buzz.tick(); live(render); }));
  const sel = $('.pal.on'); if (sel) sel.scrollIntoView({inline:'center', block:'nearest'});
}

/* ---------- libraries ---------- */
function spineHTML(x, i, sel){
  const n = totalOf(x), w = 26 + Math.min(34, Math.round(Math.log10(n + 1) * 10)), h = 150 + ((i * 37) % 4) * 12;
  const parts = x.modules || [x];
  return `<button type="button" class="spines ${sel ? 'on' : ''}" data-src="${x.id}" style="--acc:var(--a${x.acc})" aria-label="${x.name}">
    ${parts.map((m, k) => `<span class="spine" style="width:${parts.length > 1 ? Math.max(22, w - 8 - k * 4) : w}px;height:${h - k * 14}px"><i class="sb t"></i><span class="st">${m.name}</span><i class="sb b"></i>${x.kind === 'zip' && k === 0 ? `<i class="zipmark">${icon('zip')}</i>` : ''}</span>`).join('')}</button>`;
}
function libraryHTML(s){
  const sel = SOURCES.find(x => x.id === s.sel) || null;
  const totals = KINDS5.map(([k, n, ic]) => [k, n, ic, SOURCES.reduce((t, x) => t + sumOf(x, k), 0)]);
  const empty = libEmpty || !SOURCES.length;
  const shelf = libVariant === 'shelf';
  return `${top5(T('Библиотеки', 'Libraries'), {actions:`<button type="button" class="round" data-a="import" aria-label="Импорт">${icon('plus')}</button>`})}
  <div class="scroller"><div class="page5">
    <header class="mh"><span class="cap" style="--acc:var(--a1)">${T('Контент стола', 'Table content')}</span><h1>${T('Библиотеки', 'Libraries')}</h1><p class="sub5">Книги правил, заклинания и свои находки стола — из Fight Club 5 XML и ZIP.</p></header>
    ${empty ? `<div class="emptylib"><div class="shelf-plank empty"><span class="ghostbook"></span><span class="ghostbook b"></span><u></u></div>
        <b>Полка пока пустая</b><small>Поставьте первую книгу: XML или ZIP из Fight Club 5. Перед импортом ZIP покажет, что внутри.</small>
        <button type="button" class="btn primary" data-a="import" style="height:52px">${icon('upload')} Импортировать</button></div>` : `
    <div class="totals">${totals.map(([k, n, ic, v]) => `<span class="tot" style="--acc:var(--a${KINDS5.findIndex(z => z[0] === k)})"><b class="num">${odo(v, 'tot' + k)}</b><small>${n}</small></span>`).join('')}</div>
    ${shelf ? `<div class="shelf-wrap"><div class="shelf-plank" id="shelf">${SOURCES.map((x, i) => spineHTML(x, i, sel === x)).join('')}<button type="button" class="spine-add" data-a="import" aria-label="Импорт">${icon('plus')}</button><u></u></div></div>
      <div id="libdetail">${sel ? sourceDetail(sel) : `<p class="hint5">${icon('book')} Коснитесь корешка — книга выдвинется, а здесь появится её содержимое.</p>`}</div>`
    : `<div class="catalog">${SOURCES.map(x => catCard(x, s.open === x.id)).join('')}</div>`}`}
  </div></div>`;
}
function statTiles(x){
  return `<div class="stiles">${KINDS5.map(([k, n, ic], i) => { const v = sumOf(x, k);
    return `<span class="stile ${v ? '' : 'zero'}" style="--acc:var(--a${i})">${icon(ic)}<b class="num">${odo(v, 'st' + x.id + k)}</b><small>${n}</small></span>`; }).join('')}</div>`;
}
function bars(x){
  const t = totalOf(x) || 1;
  return `<span class="bars">${KINDS5.map(([k], i) => { const v = sumOf(x, k); return v ? `<i style="--acc:var(--a${i});flex:${v / t}"></i>` : ''; }).join('')}</span>`;
}
function sourceDetail(x){
  return `<section class="srcd" style="--acc:var(--a${x.acc})"><i class="glow5"></i>
    <div class="sd-h">${seal5(x.kind === 'zip' ? 'zip' : 'file', x.acc, 'lg')}<span class="ft"><span class="cap">${x.kind === 'zip' ? `ZIP · ${x.modules.length} ${plural(x.modules.length, 'модуль', 'модуля', 'модулей')}` : 'XML'} · ${x.date}</span><h2>${x.name}</h2></span></div>
    ${statTiles(x)}
    ${x.modules ? `<div class="mods">${x.modules.map(m => `<div class="mod"><span class="ft"><b>${m.name}</b><small class="num">${m.path} · ${n0(KINDS5.reduce((n, [k]) => n + stat(m, k), 0))} записей</small></span><button type="button" class="round sm" data-delmod="${x.id}:${m.id}" aria-label="Убрать модуль">${icon('trash')}</button></div>`).join('')}</div>` : ''}
    <button type="button" class="hold5" data-hold="${x.id}"><span class="fill"></span><span>${icon('trash')} Удерживайте, чтобы убрать с полки</span></button>
  </section>`;
}
function catCard(x, open){
  return `<div class="ccard ${open ? 'open' : ''}" style="--acc:var(--a${x.acc})">
    <button type="button" class="cc-h" data-open="${x.id}">${seal5(x.kind === 'zip' ? 'zip' : 'file', x.acc)}<span class="ft"><b>${x.name}</b><small>${x.kind === 'zip' ? `ZIP · ${x.modules.length} ${plural(x.modules.length, 'модуль', 'модуля', 'модулей')} · ` : 'XML · '}${x.date}</small></span><span class="cc-n num">${n0(totalOf(x))}</span></button>
    ${bars(x)}
    <div class="reveal ${open ? 'open' : ''}"><div><div class="cc-body">${statTiles(x)}
      ${x.modules ? `<div class="mods">${x.modules.map(m => `<div class="mod"><span class="ft"><b>${m.name}</b><small class="num">${m.path}</small></span><button type="button" class="round sm" data-delmod="${x.id}:${m.id}" aria-label="Убрать модуль">${icon('trash')}</button></div>`).join('')}</div>` : ''}
      <button type="button" class="hold5" data-hold="${x.id}"><span class="fill"></span><span>${icon('trash')} Удерживайте, чтобы убрать</span></button></div></div></div>
  </div>`;
}
function bindLibrary(s){
  $$('[data-src]').forEach(b => b.addEventListener('click', () => { s.sel = s.sel === b.dataset.src ? null : b.dataset.src; buzz.light(); live(render);
    const d = $('#libdetail'); if (s.sel && d && !reduced) d.animate([{transform:'translateY(16px)', opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.snappy, .42)}); }));
  $$('[data-open]').forEach(b => b.addEventListener('click', () => { s.open = s.open === b.dataset.open ? null : b.dataset.open; buzz.tick(); live(render); }));
  $$('[data-delmod]').forEach(b => b.addEventListener('click', () => { const [sid, mid] = b.dataset.delmod.split(':'), x = SOURCES.find(z => z.id === sid);
    x.modules = x.modules.filter(m => m.id !== mid); if (!x.modules.length) SOURCES = SOURCES.filter(z => z !== x); buzz.medium(); toast('Модуль убран'); live(render); }));
  $$('[data-hold]').forEach(b => {
    let t = 0;
    const start = () => { b.classList.add('holding'); buzz.tick(); t = setTimeout(() => { const id = b.dataset.hold, x = SOURCES.find(z => z.id === id);
      buzz.medium(); SOURCES = SOURCES.filter(z => z.id !== id); s.sel = null; s.open = null; live(render); toast(`«${x.name}» убрана с полки`); }, reduced ? 10 : 900); };
    const stop = () => { clearTimeout(t); b.classList.remove('holding'); };
    b.addEventListener('pointerdown', start); ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => b.addEventListener(ev, stop));
  });
}

/* ---------- import ---------- */
function importSheet(){
  openSheet(`<span class="bs-kicker">Библиотеки</span><h2 class="bs-title">Что ставим на полку?</h2><p class="bs-sub">Файл из Fight Club 5: одиночный XML или ZIP со сборником. ZIP сначала покажет, что внутри.</p>
    <div class="files5">
      <button type="button" class="file5" data-f="zip">${seal5('zip', 1, 'lg')}<span class="ft"><b>${ZIP.name}</b><small class="num">ZIP · 8 файлов · 4,1 МБ</small></span>${icon('fwd', 'chev')}</button>
      <button type="button" class="file5" data-f="xml">${seal5('file', 4, 'lg')}<span class="ft"><b>Хроники ветра.xml</b><small class="num">XML · 220 КБ</small></span>${icon('fwd', 'chev')}</button>
    </div><p class="hint5">${icon('info')} В приложении здесь откроется выбор файла на устройстве.</p>`, {onOpen(sh, close){
      $('[data-f="zip"]', sh).addEventListener('click', () => close(0, zipSheet));
      $('[data-f="xml"]', sh).addEventListener('click', () => close(0, () => importRun([{name:'Хроники ветра', spells:23, items:14, feats:3}], 'Хроники ветра', 'xml')));
    }});
}
let zipPick = new Set(ZIP.entries.filter(e => e.rec).map(e => e.id));
const entryStats = e => KINDS5.filter(([k]) => e[k]).map(([k, n]) => `${n.toLowerCase()} ${n0(e[k])}`).join(' · ');
const zipTotals = () => {
  const sel = ZIP.entries.filter(e => zipPick.has(e.id));
  return {sel, t:Object.fromEntries(KINDS5.map(([k]) => [k, sel.reduce((n, e) => n + (e[k] || 0), 0)])),
    mons:sel.reduce((n, e) => n + (e.monsters || 0), 0), dup:zipPick.has('all') && sel.some(e => e.dup)};
};
// The sheet is built once; picking only flips classes and rolls numbers,
// so every choice animates in place.
function zipSheet(){
  const {sel, t} = zipTotals();
  const row = e => `<button type="button" class="zrow ${zipPick.has(e.id) ? 'on' : ''} ${e.unsupported ? 'off' : ''}" data-z="${e.id}" ${e.unsupported ? 'disabled' : ''} aria-pressed="${zipPick.has(e.id)}">
      <i class="zbox">${icon('check')}</i>
      <span class="ft"><span class="zr-t"><b>${e.name}</b>${e.rec ? '<em class="bd rec">рекомендуется</em>' : ''}${e.combined ? '<em class="bd all">общий</em>' : ''}${e.unsupported ? '<em class="bd no">не поддерживается</em>' : ''}</span>
        <small class="num">${e.path}</small>
        ${e.unsupported ? `<small>Нет поддерживаемого контента · монстры ${e.monsters}</small>` : `${bars(e)}<small>${entryStats(e)}</small>`}</span></button>`;
  openSheet(`<div class="zhead">${seal5('zip', 1, 'lg')}<span class="ft"><span class="cap" style="--acc:var(--a1)">ZIP · 8 файлов · 4,1 МБ</span><b>${ZIP.name}</b></span></div>
    <h2 class="bs-title">Что внутри</h2><p class="bs-sub">Найдено XML: ${ZIP.entries.length}, прочих файлов пропущено: ${ZIP.ignored}. Отметьте, что поставить на полку.</p>
    <div class="qpicks"><button type="button" class="qpick" data-q="rec">${icon('star')}Рекомендуемое</button><button type="button" class="qpick" data-q="all">${icon('layers')}Всё</button><button type="button" class="qpick" data-q="none">${icon('x')}Ничего</button></div>
    <div class="zlist">${ZIP.entries.map(row).join('')}</div>
    <div class="zfoot"><div class="zsum"><b class="num">${odo(sel.length, 'zsel')}</b><span id="zword">${plural(sel.length, 'модуль выбран', 'модуля выбрано', 'модулей выбрано')}</span></div>
      <div class="ztot">${KINDS5.map(([k, n], i) => `<span style="--acc:var(--a${i})" class="${t[k] ? '' : 'zero'}"><b class="num">${odo(t[k], 'zt' + k)}</b><small>${n}</small></span>`).join('')}</div>
      <div class="reveal" id="zmons"><div><p class="znote">${icon('info')}<span>Монстры пока не поддерживаются и будут пропущены: <b class="num" id="zmonsN">0</b>.</span></p></div></div>
      <div class="reveal" id="zdup"><div><p class="znote warn">${icon('warn')}<span>Общий compendium пересекается с отдельными модулями. Можно взять оба — смысловые дубли пропустятся.</span></p></div></div></div>
    <button type="button" class="btn primary wide go5" data-zgo>${icon('download')} Поставить на полку</button>`, {onOpen(sh, close){
      const sync = () => {
        const {sel, t, mons, dup} = zipTotals();
        $$('[data-z]', sh).forEach(r => { const on = zipPick.has(r.dataset.z); if (r.classList.contains('on') !== on) { r.classList.toggle('on', on); r.setAttribute('aria-pressed', on); if (on) replay($('.zbox', r), 'stamp5'); } });
        setOdo($('[data-odo="zsel"]', sh), sel.length);
        $('#zword', sh).textContent = plural(sel.length, 'модуль выбран', 'модуля выбрано', 'модулей выбрано');
        KINDS5.forEach(([k]) => { const el = $(`[data-odo="zt${k}"]`, sh), tile = el.closest('span[style]'); setOdo(el, t[k]); tile.classList.toggle('zero', !t[k]); });
        $('#zmonsN', sh).textContent = mons; $('#zmons', sh).classList.toggle('open', !!mons); $('#zdup', sh).classList.toggle('open', dup);
        $('[data-zgo]', sh).disabled = !sel.length;
      };
      sync();
      $$('[data-z]', sh).forEach(r => r.addEventListener('click', () => { const id = r.dataset.z; zipPick.has(id) ? zipPick.delete(id) : zipPick.add(id); buzz.tick(); sync(); }));
      $$('[data-q]', sh).forEach(b => b.addEventListener('click', () => { const q = b.dataset.q;
        zipPick = q === 'rec' ? new Set(ZIP.entries.filter(e => e.rec).map(e => e.id)) : q === 'all' ? new Set(ZIP.entries.filter(e => !e.unsupported).map(e => e.id)) : new Set();
        buzz.light(); replay(b, 'stamp5'); sync(); }));
      $('[data-zgo]', sh).addEventListener('click', () => close(0, () => importRun(ZIP.entries.filter(e => zipPick.has(e.id)), 'Сборник с игры', 'zip')));
    }});
}
// Import as a book being read: each module's pages flip while its counts roll up.
function importRun(mods, name, kind){
  openSheet(`<span class="bs-kicker">${kind === 'zip' ? 'ZIP' : 'XML'}</span><h2 class="bs-title">Читаем «${name}»</h2>
    <div class="reading"><div class="book5"><i></i><i></i><i></i><i></i></div>
      <div class="rmods">${mods.map((m, i) => `<div class="rmod" data-r="${i}"><span class="ft"><b>${m.name}</b><small class="num" data-rc="${i}">ждёт</small></span><span class="rbar"><i></i></span></div>`).join('')}</div></div>
    <div class="ztot" id="rtot">${KINDS5.map(([k, n], i) => `<span style="--acc:var(--a${i})"><b class="num">${odo(0, 'rt' + k)}</b><small>${n}</small></span>`).join('')}</div>
    <button type="button" class="btn primary wide" data-rdone style="height:54px" disabled>Готово</button>`, {onOpen(sh, close){
      const tot = Object.fromEntries(KINDS5.map(([k]) => [k, 0]));
      let i = 0, dup = 0;
      const nextMod = () => {
        if (i >= mods.length) {
          buzz.medium(); $('[data-rdone]', sh).disabled = false; $('.book5', sh).classList.add('shut');
          const mons = mods.reduce((n, m) => n + (m.monsters || 0), 0);
          if (dup || mons) $('#rtot', sh).insertAdjacentHTML('afterend', `<p class="znote">${icon('info')} Пропущено дублей: ${dup}; монстров: ${mons}.</p>`);
          return;
        }
        const m = mods[i], row = $(`[data-r="${i}"]`, sh); row.classList.add('now');
        $(`[data-rc="${i}"]`, sh).textContent = 'читаем…';
        row.querySelector('.rbar i').animate([{width:'0%'}, {width:'100%'}], {duration:reduced ? 10 : 700, fill:'forwards', easing:'cubic-bezier(.4,0,.2,1)'}).onfinish = () => {
          buzz.tick(); row.classList.remove('now'); row.classList.add('done');
          if (m.dup && mods.some(x => x.combined)) dup += 12;
          $(`[data-rc="${i}"]`, sh).textContent = entryStats(m) || 'пусто';
          KINDS5.forEach(([k]) => { tot[k] += m[k] || 0; setOdo($(`[data-odo="rt${k}"]`, sh), tot[k]); });
          i++; setTimeout(nextMod, reduced ? 0 : 160);
        };
      };
      setTimeout(nextMod, reduced ? 0 : 300);
      $('[data-rdone]', sh).addEventListener('click', () => close(0, () => {
        const src = kind === 'zip'
          ? {id:'n' + Date.now(), kind:'zip', name, date:'сегодня', acc:4, modules:mods.map(m => ({...m, id:m.id || m.name}))}
          : {id:'n' + Date.now(), kind:'xml', name, date:'сегодня', acc:2, ...mods[0]};
        SOURCES.push(src); libEmpty = false;
        if (cur().s !== 'library') stack.push({s:'library'});
        cur().sel = src.id; render();
        const sp = $(`[data-src="${src.id}"]`);
        if (sp && !reduced) { sp.animate([{transform:'translateY(-140px) rotate(-8deg)', opacity:0}, {transform:'none', opacity:1}], {duration:720, easing:springEasing(SPR.bouncy, .72)}); sp.scrollIntoView({inline:'end', block:'nearest'}); }
        toast(`«${name}» на полке`);
      }));
    }});
}

/* ---------- moving a hero ---------- */
function transferSheet(id){
  if (!id) {
    openSheet(`<span class="bs-kicker">${T('Перенос', 'Move')}</span><h2 class="bs-title">${T('Какого героя?', 'Which hero?')}</h2>
      <div class="blist">${HEROES.map(h => `<button type="button" class="brow2" data-hh="${h.id}"><span class="hc-av sm" style="--acc:var(--a${h.acc})">${h.name[0]}</span><span class="ft"><b>${h.name}</b><small class="muted">${h.race} · ${h.cls} ${h.lvl}</small></span>${icon('fwd', 'chev')}</button>`).join('')}
        <button type="button" class="brow2" data-imp>${seal5('download', 3)}<span class="ft"><b>${T('Принять героя из файла', 'Bring a hero in from a file')}</b><small class="muted">.qdnd · .xml</small></span>${icon('fwd', 'chev')}</button></div>`, {onOpen(sh, close){
        $$('[data-hh]', sh).forEach(b => b.addEventListener('click', () => close(0, () => transferSheet(b.dataset.hh))));
        $('[data-imp]', sh).addEventListener('click', () => close(0, () => importHeroSheet('qdnd')));
      }});
    return;
  }
  const h = HEROES.find(x => x.id === id);
  let fmt = 'qdnd', own = true;
  // Built once: the formats flip their state in place, the own-content
  // switch folds away with the full copy, the result crossfades in.
  openSheet(`<div class="zhead"><span class="hc-av" style="--acc:var(--a${h.acc})">${h.name[0]}</span><span class="ft"><span class="cap" style="--acc:var(--a${h.acc})">${h.race} · ${h.cls} ${h.lvl}</span><b>${h.name}</b></span></div>
    <h2 class="bs-title">Перенести героя</h2><p class="bs-sub">Файл можно открыть на другом устройстве через «Добавить героя» или в Fight Club 5.</p>
    <div class="tstage" id="tb">
      <div class="fmts">
        <button type="button" class="fmt on" data-fmt="qdnd" style="--acc:var(--a1)" aria-pressed="true"><i class="glow5"></i><span class="fm-h">${seal5('layers', 1, 'lg')}<span class="ft"><b>Полная копия</b><small class="num">.qdnd · для QDnD</small></span><i class="fm-dot">${icon('check')}</i></span>
          <span class="fm-l"><i>${icon('check')}Лист, ресурсы и состояния</i><i>${icon('check')}Журнал, задания и Атлас</i><i>${icon('check')}История развития</i><i>${icon('check')}Ссылки на библиотеки</i></span></button>
        <button type="button" class="fmt" data-fmt="fc5" style="--acc:var(--a4)" aria-pressed="false"><i class="glow5"></i><span class="fm-h">${seal5('file', 4, 'lg')}<span class="ft"><b>Fight Club 5</b><small class="num">.xml · для других приложений</small></span><i class="fm-dot">${icon('check')}</i></span>
          <span class="fm-l"><i>${icon('check')}Характеристики, навыки, снаряжение</i><i>${icon('check')}Заклинания и умения</i><i class="no">${icon('x')}Журнал и история не переносятся</i></span></button>
      </div>
      <div class="reveal open" id="ownWrap"><div><button type="button" class="row5 toggle5 on" data-own aria-checked="true">${seal5('star', 2)}<span class="ft"><b>Вложить свой контент</b><small>Свои классы, умения и предметы героя поедут вместе с ним</small></span><span class="switch"></span></button></div></div>
      <button type="button" class="btn primary wide go5" data-save>${icon('upload')} <span id="saveWord">Сохранить .qdnd</span></button>
    </div>`, {onOpen(sh, close){
      $$('[data-fmt]', sh).forEach(b => b.addEventListener('click', () => { if (fmt === b.dataset.fmt) return; fmt = b.dataset.fmt; buzz.tick();
        $$('[data-fmt]', sh).forEach(x => { const on = x === b; x.classList.toggle('on', on); x.setAttribute('aria-pressed', on); });
        replay($('.fm-dot', b), 'stamp5');
        $('#ownWrap', sh).classList.toggle('open', fmt === 'qdnd');
        $('#saveWord', sh).textContent = fmt === 'qdnd' ? 'Сохранить .qdnd' : 'Сохранить .xml'; }));
      $('[data-own]', sh).addEventListener('click', e => { own = !own; e.currentTarget.classList.toggle('on', own); e.currentTarget.setAttribute('aria-checked', own); buzz.tick(); });
      $('[data-save]', sh).addEventListener('click', () => { buzz.medium();
        const file = `${h.name}-20261026.${fmt === 'qdnd' ? 'qdnd' : 'xml'}`, tb = $('#tb', sh);
        const swap = () => { tb.innerHTML = `<div class="saved"><span class="sv-file" style="--acc:var(--a${fmt === 'qdnd' ? 1 : 4})">${seal5(fmt === 'qdnd' ? 'layers' : 'file', fmt === 'qdnd' ? 1 : 4, 'lg')}<span class="ft"><b class="num">${file}</b><small>${fmt === 'qdnd' ? (own ? 'Вложено своего контента: 3 · ссылок на библиотеки: 14' : 'Ссылок на библиотеки: 14') : 'Совместим с Fight Club 5'}</small></span><i class="sv-ok">${icon('check')}</i></span>
            <p class="hint5">${icon('check')} Файл сохранён. Отправьте его на другое устройство и откройте там через «Добавить героя».</p>
            <div class="two5"><button type="button" class="btn" data-share style="height:52px">${icon('share')} Поделиться</button><button type="button" class="btn primary" data-close style="height:52px">Готово</button></div></div>`;
          if (!reduced) tb.animate([{opacity:0, transform:'translateY(14px)'}, {opacity:1, transform:'none'}], {duration:420, easing:springEasing(SPR.snappy, .42)});
          replay($('.sv-ok', sh), 'stamp5');
          $('[data-share]', sh).addEventListener('click', () => toast('Здесь откроется системное «Поделиться»'));
          $('[data-close]', sh).addEventListener('click', () => close()); };
        if (reduced) return swap();
        tb.animate([{opacity:1, transform:'none'}, {opacity:0, transform:'translateY(-10px)'}], {duration:180, fill:'forwards'}).onfinish = swap;
      });
    }});
}
function importHeroSheet(kind){
  const qd = kind === 'qdnd';
  openSheet(`<span class="bs-kicker">${qd ? 'Файл QDnD · .qdnd' : 'Fight Club 5 · .xml'}</span><h2 class="bs-title">Принять героя</h2>
    <div class="incoming" style="--acc:var(--a5)"><span class="hc-av lg">Л</span><span class="ft"><span class="cap">${qd ? 'Полная копия' : 'Лист персонажа'}</span><b>Лира Тихий Шаг</b><small>Халфлинг · Бард 12</small></span></div>
    ${qd ? `<div class="deps"><span style="--acc:var(--a3)"><b class="num">3</b><small>вложено</small></span><span style="--acc:var(--a4)"><b class="num">12</b><small>найдено в библиотеках</small></span><span style="--acc:var(--a0)"><b class="num">1</b><small>нет у вас</small></span></div>` : ''}
    <div class="warns"><div class="w-h">${icon('warn')}<b>${qd ? '2 поля требуют внимания' : '3 поля требуют внимания'}</b></div>
      ${(qd ? ['Подкласс «Коллегия шёпота» не найден в библиотеках — сохранён текстом', 'Предмет «Лютня Канайт» записан как свой предмет'] : ['Подкласс не распознан — выберите его на листе', 'Два заклинания не найдены в библиотеках — сохранены текстом', 'Снаряжение без веса — вес можно указать позже']).map(w => `<p>${w}</p>`).join('')}</div>
    <button type="button" class="btn primary wide" data-add style="height:54px">${icon('plus')} Добавить в отряд</button>`, {onOpen(sh, close){
      $('[data-add]', sh).addEventListener('click', () => close(0, () => { buzz.medium();
        HEROES.push({id:'lira' + Date.now(), name:'Лира', race:'Халфлинг', cls:'Бард', lvl:12, acc:5, hp:84});
        stack = [{s:'lobby'}]; render();
        const c = $$('.hcard').at(-1); if (c && !reduced) c.animate([{transform:'translateY(30px) scale(.9)', opacity:0}, {transform:'none', opacity:1}], {duration:620, easing:springEasing(SPR.bouncy, .62)});
        toast('Лира в отряде'); }));
    }});
}

/* ---------- the hero's card ---------- */
const EYES = [['Янтарные', '#FFBF00'], ['Голубые', '#4169E1'], ['Карие', '#8B4513'], ['Серые', '#808080'], ['Зелёные', '#228B22'], ['Ореховые', '#A0785A'], ['Красные', '#DC143C'], ['Фиолетовые', '#8B00FF']];
const SKIN = [['Бледная', '#FFF0E1'], ['Светлая', '#FFE4C4'], ['Персиковая', '#FFDDB3'], ['Оливковая', '#E8B98A'], ['Загорелая', '#D2A574'], ['Смуглая', '#A67C52'], ['Тёмная', '#8B6F47'], ['Эбеновая', '#4A3728']];
const HAIR = [['Каштановые', '#A52A2A'], ['Чёрные', '#1A1A1A'], ['Светлые', '#FAF0BE'], ['Русые', '#654321'], ['Седые', '#808080'], ['Рыжие', '#E2421B'], ['Белые', '#F5F5F5'], ['Без волос', null]];
const PERS = [['traits', 'Черты характера', 'spark', 3, 'Как герой держится и что выдаёт его привычки', ['Говорит мало, но всегда по делу', 'Не может пройти мимо чужой беды']],
  ['ideals', 'Идеалы', 'star', 2, 'Во что герой верит, даже когда это дорого', ['Клятва важнее жизни', 'Слабых нужно защищать']],
  ['bonds', 'Привязанности', 'link', 4, 'Кто и что держит героя', ['Отец, которого я не знал', 'Орден, вырастивший меня']],
  ['flaws', 'Слабости', 'drop', 0, 'Что может его подвести', ['Не прощает ложь — даже малую', 'Бросается в бой раньше, чем думает']]];
let HERO = {name:'Элиан', age:34, height:182, weight:84, eyes:'Карие', skin:'Смуглая', hair:'Чёрные', avatar:false,
  traits:'Говорит мало, но всегда по делу.', ideals:'Клятва важнее жизни.', bonds:'', flaws:'Не прощает ложь — даже малую.',
  story:'Сын рыцаря Альдрена. Вырос при ордене, не зная отца, и лишь после его смерти узнал, чью клятву несёт.'};
let draft = null, dirty = false;
const swatchOf = (list, v) => (list.find(x => x[0] === v) || [v, null])[1];
const sentence = d => [`${d.age} ${plural(d.age, 'год', 'года', 'лет')}`, `${d.height} см`, `${d.weight} кг`, d.eyes && `${d.eyes.toLowerCase()} глаза`, d.skin && `${d.skin.toLowerCase()} кожа`, d.hair && (d.hair === 'Без волос' ? 'без волос' : `${d.hair.toLowerCase()} волосы`)].filter(Boolean).join(' · ');
function editorHTML(s){
  const h = HEROES.find(x => x.id === s.h) || HEROES[0];
  if (!draft || draft._h !== h.id) { draft = {...HERO, name:h.id === 'elian' ? HERO.name : h.name, _h:h.id}; dirty = false; }
  const d = draft;
  const tile = (k, ic, n, v, unit, acc) => `<button type="button" class="ftile" data-num="${k}" style="--acc:var(--a${acc})"><span class="ft-h">${icon(ic)}<small>${n}</small></span><b class="num">${odo(v, 'ed' + k)}<small>${unit}</small></b></button>`;
  const sw = (k, n, list) => { const c = swatchOf(list, d[k]); return `<button type="button" class="ftile sw" data-sw="${k}" style="--acc:${c || 'var(--outline)'}"><span class="ft-h">${icon('swatch')}<small>${n}</small></span><span class="swv"><i class="dot5 ${c ? '' : 'none'}" style="${c ? `background:${c}` : ''}"></i><b>${d[k] || 'Не указано'}</b></span></button>`; };
  return `${top5('Анкета героя', {lead:'close', pinned:true, actions:`<button type="button" class="btn primary sm" data-a="saveHero" ${dirty ? '' : 'disabled'}>Сохранить</button>`})}
  <div class="scroller"><div class="page5 edit5">
    <div class="portrait" style="--acc:var(--a${h.acc})">
      <button type="button" class="pt-av ${d.avatar ? 'img' : ''}" data-a="avatar" aria-label="Портрет"><span>${d.name[0] || '?'}</span><i class="pt-cam">${icon('camera')}</i></button>
      <input class="pt-name" id="hName" value="${d.name}" aria-label="Имя" autocomplete="off">
      <span class="pt-sub">${h.race} · ${h.cls} ${h.lvl}</span>
      <p class="pt-line" id="ptLine">${sentence(d)}</p>
      <div class="fill5"><span class="fl-bar"><i id="flBar" style="width:${filled(d) / 12 * 100}%"></i></span><small id="flWord">${fillWord(d)}</small></div>
    </div>
    <div class="sec5"><h3>Облик</h3><small>касание — выбрать</small></div>
    <div class="ftiles">${tile('age', 'hourglass', 'Возраст', d.age, plural(d.age, 'год', 'года', 'лет'), 1)}${tile('height', 'ruler', 'Рост', d.height, 'см', 4)}${tile('weight', 'scale', 'Вес', d.weight, 'кг', 3)}
      ${sw('eyes', 'Глаза', EYES)}${sw('skin', 'Кожа', SKIN)}${sw('hair', 'Волосы', HAIR)}</div>
    <div class="sec5"><h3>Личность</h3></div>
    <div class="pers">${PERS.map(([k, n, ic, acc, hint]) => `<div class="pcard5 ${d[k] ? '' : 'empty'}" style="--acc:var(--a${acc})" data-p="${k}">
      <span class="pc-h">${seal5(ic, acc, 'sm')}<b>${n}</b></span>
      <textarea data-pt="${k}" rows="1" placeholder="${hint}">${d[k]}</textarea>
      ${d[k] ? '' : `<span class="ideas">${PERS.find(p => p[0] === k)[5].map(t => `<button type="button" class="idea" data-idea="${k}">${icon('plus')}${t}</button>`).join('')}</span>`}</div>`).join('')}</div>
    <div class="sec5"><h3>Предыстория</h3></div>
    <div class="pcard5 story" style="--acc:var(--a5)"><span class="pc-h">${seal5('book', 5, 'sm')}<b>Путь героя</b><small id="words" class="num">${(d.story.match(/\S+/g) || []).length} слов</small></span>
      <textarea class="story5" id="story" placeholder="Откуда герой, что его привело и что он оставил позади">${d.story}</textarea></div>
  </div></div>`;
}
// How much of the card is told: name, six traits of the look, four of the
// character and the story.
const filled = d => ['name', 'age', 'height', 'weight', 'eyes', 'skin', 'hair', 'traits', 'ideals', 'bonds', 'flaws', 'story'].filter(k => String(d[k] ?? '').trim()).length;
const fillWord = d => { const n = filled(d); return n === 12 ? 'Анкета заполнена целиком' : `Рассказано ${n} из 12`; };
function refreshFill(){ const d = draft, bar = $('#flBar'); if (!bar) return; bar.style.width = filled(d) / 12 * 100 + '%'; $('#flWord').textContent = fillWord(d); }
function markDirty(){ if (dirty) return; dirty = true; const b = $('[data-a="saveHero"]'); if (b) { b.disabled = false; replay(b, 'popin'); } }
function bindEditor(){
  const d = draft, grow = t => { t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; };
  $('#hName').addEventListener('input', e => { d.name = e.target.value; $('.pt-av span').textContent = d.name[0] || '?'; markDirty(); refreshFill(); });
  $$('[data-pt]').forEach(t => { grow(t); t.addEventListener('input', () => { d[t.dataset.pt] = t.value; grow(t); markDirty(); refreshFill(); t.closest('.pcard5').classList.toggle('empty', !t.value.trim()); }); });
  const st = $('#story'); grow(st); st.addEventListener('input', () => { d.story = st.value; grow(st); $('#words').textContent = `${(st.value.match(/\S+/g) || []).length} слов`; markDirty(); refreshFill(); });
  // The block being written in lights up; a light tick marks the start.
  $$('.pcard5 textarea').forEach(t => t.addEventListener('focus', () => buzz.tick()));
  $$('[data-idea]').forEach(b => b.addEventListener('click', () => { const k = b.dataset.idea; d[k] = b.textContent.trim() + '.'; buzz.light(); markDirty(); live(render); }));
  $$('[data-num]').forEach(b => b.addEventListener('click', () => drumSheet(b.dataset.num)));
  $$('[data-sw]').forEach(b => b.addEventListener('click', () => swatchSheet(b.dataset.sw)));
}
// A drum of numbers: dragged or flicked, it settles on a value with a tick.
function drumSheet(k){
  const d = draft, cfg = {age:['Возраст', 1, 999, 'лет'], height:['Рост', 50, 250, 'см'], weight:['Вес', 10, 300, 'кг']}[k];
  const [title, min, max, unit] = cfg, ROW = 52;
  let v = d[k];
  openSheet(`<span class="bs-kicker">Облик</span><h2 class="bs-title">${title}</h2>
    <div class="drum" id="drum"><div class="drum-win"></div><div class="drum-col" id="dcol"></div><span class="drum-unit">${unit}</span></div>
    <div class="two5"><button type="button" class="btn" data-type style="height:50px">${icon('edit')} Ввести</button><button type="button" class="btn primary" data-ok style="height:50px">Готово</button></div>`, {onOpen(sh, close){
      const col = $('#dcol', sh), drum = $('#drum', sh);
      let y = -(v - min) * ROW, last = v;
      const spring = new Spring(y, SPR.gentle, () => {});
      const show = () => { const c = -y / ROW + min; col.innerHTML = ''; for (let n = Math.max(min, Math.floor(c) - 4); n <= Math.min(max, Math.ceil(c) + 4); n++) { const dy = (n - c) * ROW;
        col.insertAdjacentHTML('beforeend', `<i class="${n === Math.round(c) ? 'on' : ''}" style="transform:translateY(${dy}px) rotateX(${-dy / ROW * 20}deg);opacity:${Math.max(.12, 1 - Math.abs(dy / ROW) * .3)}">${n}</i>`); } };
      spring.cb = val => { y = val; const n = clamp(Math.round(-y / ROW) + min, min, max); if (n !== last) { last = n; buzz.tick(); } show(); };
      show();
      let g = null;
      drum.addEventListener('pointerdown', e => { g = {y0:e.clientY, b:y, s:[[e.timeStamp, e.clientY]]}; spring.stop(); drum.setPointerCapture(e.pointerId); });
      drum.addEventListener('pointermove', e => { if (!g) return; y = clamp(g.b + e.clientY - g.y0, -(max - min) * ROW, 0); g.s.push([e.timeStamp, e.clientY]); if (g.s.length > 6) g.s.shift(); spring.cb(y); spring.x = y; });
      drum.addEventListener('pointerup', () => { if (!g) return; const a = g.s[0], b = g.s.at(-1), vel = (b[1] - a[1]) / Math.max(1, b[0] - a[0]) * 1000; g = null;
        const target = clamp(Math.round((y + vel * .18) / ROW) * ROW, -(max - min) * ROW, 0); spring.x = y; spring.to(target, SPR.gentle, vel); });
      drum.addEventListener('wheel', e => { e.preventDefault(); const target = clamp(Math.round((y - Math.sign(e.deltaY) * ROW) / ROW) * ROW, -(max - min) * ROW, 0); spring.x = y; spring.to(target, SPR.snappy); }, {passive:false});
      $('[data-type]', sh).addEventListener('click', () => close(0, () => keypadSheet({kicker:'Облик', title, onDone:n => { d[k] = clamp(n, min, max); markDirty(); live(render); }})));
      $('[data-ok]', sh).addEventListener('click', () => close(0, () => { d[k] = clamp(Math.round(-spring.t / ROW) + min, min, max); buzz.light(); markDirty(); live(render); }));
    }});
}
function swatchSheet(k){
  const d = draft, list = {eyes:EYES, skin:SKIN, hair:HAIR}[k], title = {eyes:'Глаза', skin:'Кожа', hair:'Волосы'}[k];
  openSheet(`<span class="bs-kicker">Облик</span><h2 class="bs-title">${title}</h2>
    <div class="swgrid">${list.map(([n, c]) => `<button type="button" class="swc ${d[k] === n ? 'on' : ''}" data-c="${n}"><i class="dot5 lg ${c ? '' : 'none'}" style="${c ? `background:${c}` : ''}"></i><b>${n}</b></button>`).join('')}</div>
    <label class="fld"><span>Своё</span><input id="swOwn" placeholder="Например: разные — зелёный и серый" value="${list.some(x => x[0] === d[k]) ? '' : d[k] || ''}"></label>
    <button type="button" class="btn primary wide" data-ok style="height:52px">Готово</button>`, {onOpen(sh, close){
      $$('[data-c]', sh).forEach(b => b.addEventListener('click', () => { d[k] = b.dataset.c; buzz.tick(); $$('[data-c]', sh).forEach(x => x.classList.toggle('on', x === b)); replay(b, 'stamp5'); $('#swOwn', sh).value = '';
        setTimeout(() => close(0, () => { markDirty(); live(render); }), reduced ? 0 : 260); }));
      $('[data-ok]', sh).addEventListener('click', () => { const own = $('#swOwn', sh).value.trim(); if (own) d[k] = own; close(0, () => { markDirty(); live(render); }); });
    }});
}
function avatarSheet(){
  openSheet(`<span class="bs-kicker">Анкета</span><h2 class="bs-title">Портрет</h2>
    <div class="blist"><button type="button" class="brow2" data-av="pick">${seal5('image', 4)}<span class="ft"><b>Из галереи</b></span></button>
      <button type="button" class="brow2" data-av="cam">${seal5('camera', 1)}<span class="ft"><b>Снять</b></span></button>
      ${draft.avatar ? `<button type="button" class="brow2" data-av="del">${seal5('trash', 0)}<span class="ft"><b>Убрать портрет</b></span></button>` : ''}</div>`, {onOpen(sh, close){
      $$('[data-av]', sh).forEach(b => b.addEventListener('click', () => close(0, () => { draft.avatar = b.dataset.av !== 'del'; buzz.light(); markDirty(); live(render); })));
    }});
}

/* ---------- binding ---------- */
function bind(s){
  if (s.s === 'settings') bindSettings();
  if (s.s === 'library') bindLibrary(s);
  if (s.s === 'editor') bindEditor();
  if (s.s === 'splash') runSplash();
}
document.addEventListener('click', e => {
  const t = e.target.closest('[data-a]'); if (!t || !t.closest('#app')) return;
  const a = t.dataset.a;
  if (a === 'link') { e.preventDefault(); return toast('Откроется во внешнем браузере'); }
  if (a === 'back') return back();
  if (a === 'close') { if (dirty) return discardSheet(); return back(); }
  if (a === 'settings') return go({s:'settings'});
  if (a === 'library') return go({s:'library'});
  if (a === 'import') return importSheet();
  if (a === 'transfer') return transferSheet(null);
  if (a === 'editor') return go({s:'editor', h:t.dataset.h});
  if (a === 'heroMenu') return heroMenu(t.dataset.h);
  if (a === 'addHero') return addHeroSheet();
  if (a === 'avatar') return avatarSheet();
  if (a === 'basic') { buzz.light(); return flood(e, () => { set.basic = !set.basic; }); }
  if (a === 'footdie') { const d = $('#footdie'); if (!d) return; buzz.light(); const r = Math.ceil(Math.random() * 20); return tumble([d], [r], 20, () => { if (r === 20) { buzz.medium(); toast('Естественная 20!'); } }); }
  if (a === 'saveHero') { Object.assign(HERO, draft); dirty = false; buzz.medium(); back(); toast('Анкета сохранена'); }
});
function discardSheet(){
  openSheet(`<span class="bs-kicker">Анкета героя</span><h2 class="bs-title">Оставить изменения?</h2><p class="bs-sub">Можно вернуться к анкете или закрыть её без сохранения.</p>
    <div class="two5"><button type="button" class="btn" data-drop style="height:50px">Не сохранять</button><button type="button" class="btn primary" data-keep style="height:50px">Продолжить</button></div>`, {onOpen(sh, close){
      $('[data-drop]', sh).addEventListener('click', () => close(0, () => { draft = null; dirty = false; back(); }));
      $('[data-keep]', sh).addEventListener('click', () => close());
    }});
}

/* ---------- controls panel ---------- */
function controls(){
  const at = cur().s;
  $('#controls').innerHTML = `<div class="opt"><span class="lbl">Экран</span><div class="heroes">${[['splash', 'Запуск'], ['lobby', 'Отряд'], ['settings', 'Настройки'], ['library', 'Библиотеки'], ['zip', 'Импорт ZIP'], ['move', 'Перенос героя'], ['import', 'Принять героя'], ['editor', 'Анкета героя']].map(([k, n]) =>
      `<button type="button" data-scr="${k}" aria-pressed="${k === at}">${n}</button>`).join('')}</div></div>
    <div class="opt"><span class="lbl">Настройки · вариант</span>${segHTML([['stage', 'A · витрина'], ['board', 'B · пульт']], settingsVariant, 'svSeg')}<span class="hint">A — живая витрина листа над лентой палитр. B — спокойные группы и сетка палитр.</span></div>
    <div class="opt"><span class="lbl">Библиотеки · вариант</span>${segHTML([['shelf', 'A · полка'], ['catalog', 'B · каталог']], libVariant, 'lvSeg')}<span class="hint">A — источники корешками на полке, книга выдвигается. B — карточки с полосой состава.</span></div>
    <div class="opt"><span class="lbl">Запуск · вариант</span>${segHTML([['roll', 'A · бросок'], ['quiet', 'B · тихий']], splashVariant, 'spSeg')}<span class="hint">A — к20 падает на стол, выпадает 20 и становится знаком. B — знак и надпись проявляются.</span></div>
    <button type="button" class="toggle" id="emptyLib" aria-checked="${libEmpty}"><span class="switch"></span>Пустые библиотеки</button>
    <button type="button" class="toggle" id="redm" aria-checked="${reduced}"><span class="switch"></span>Меньше движения</button>`;
  const shut = () => { modal.innerHTML = ''; modal.style.pointerEvents = 'none'; };
  $$('[data-scr]').forEach(b => b.addEventListener('click', () => { const k = b.dataset.scr; buzz.tick(); shut();
    stack = [{s:'lobby'}];
    if (k === 'splash') stack = [{s:'splash'}];
    if (k === 'settings') stack.push({s:'settings'});
    if (['library', 'zip'].includes(k)) stack.push({s:'library', sel:'core'});
    if (k === 'editor') stack.push({s:'editor', h:'elian'});
    show(1);
    if (k === 'zip') setTimeout(zipSheet, 200);
    if (k === 'move') setTimeout(() => transferSheet('elian'), 200);
    if (k === 'import') setTimeout(() => importHeroSheet('qdnd'), 200); }));
  segment($('#svSeg'), b => { shut(); settingsVariant = b.dataset.v; stack = [{s:'lobby'}, {s:'settings'}]; render(); });
  segment($('#lvSeg'), b => { shut(); libVariant = b.dataset.v; stack = [{s:'lobby'}, {s:'library', sel:'core', open:'core'}]; render(); });
  segment($('#spSeg'), b => { shut(); splashVariant = b.dataset.v; stack = [{s:'splash'}]; render(); });
  $('#emptyLib').addEventListener('click', e => { libEmpty = !libEmpty; e.currentTarget.setAttribute('aria-checked', libEmpty); if (['library', 'settings'].includes(cur().s)) render(); });
  $('#redm').addEventListener('click', e => { reduced = !reduced; document.body.classList.toggle('reduce', reduced); e.currentTarget.setAttribute('aria-checked', reduced); });
}
applyApp();
stack = [{s:'splash'}];
render();
controls();
