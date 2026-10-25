/* ================= Wave 4: the journal ================= */
// The campaign of the Cycle journal (Elian's story), written on to the
// seventh session so the chronicle, the threads and the Atlas have
// something to show.
const KINDS = {
  person:{n:'Персонаж', pl:'Люди', ic:'person', acc:0},
  place:{n:'Место', pl:'Места', ic:'pin', acc:4},
  item:{n:'Предмет', pl:'Предметы', ic:'gem', acc:2},
  event:{n:'Событие', pl:'События', ic:'bolt', acc:1},
  story:{n:'Сюжет', pl:'Сюжеты', ic:'book', acc:5},
};
const CATS = {
  general:{n:'Общее', ic:'note', acc:3},
  location:{n:'Место', ic:'pin', acc:4},
  npc:{n:'Персонаж', ic:'person', acc:0},
  artifact:{n:'Артефакт', ic:'gem', acc:2},
  story:{n:'Сюжет', ic:'book', acc:5},
  session:{n:'Сессия', ic:'feather', acc:1},
};
const QST = {
  active:{n:'Активно', ic:'flag', acc:1},
  completed:{n:'Выполнено', ic:'check', acc:3},
  failed:{n:'Провалено', ic:'x', acc:0},
};
const HERO = 'Cycle · Паладин';
const QUOTES = ['Опасно идти одному!', 'Карта — не территория, но лучше, чем ничего.', 'Каждая история начинается с таверны.', 'Запиши имя, пока его не забыли.'];
const MONTHS = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
const dateText = d => `${d.getDate()} ${MONTHS[d.getMonth()]}`;

let ENT = [
  {id:'elian', name:'Элиан', kind:'person', aliases:['Elian'], desc:'Сын Альдрена. Личность человека из письма ещё предстоит проверить.'},
  {id:'aldren', name:'Альдрен', kind:'person', aliases:['Aldren'], desc:'Старый рыцарь клятвы. Передал последние слова сыну.'},
  {id:'mira', name:'Мира', kind:'person', aliases:[], desc:'Хозяйка «Седого ворона» и смотрительница старой пристани.'},
  {id:'haven', name:'Лесная гавань', kind:'place', aliases:['Woodland Haven'], desc:'Рыбацкий городок у залива. Отсюда всё началось.'},
  {id:'north', name:'Северная дорога', kind:'place', aliases:[], desc:'Тракт к перевалу. Снова безопасен.'},
  {id:'pier', name:'Старая пристань', kind:'place', aliases:[], desc:'Её кто-то недавно чинил.'},
  {id:'light', name:'Маяк', kind:'place', aliases:[], desc:'Заброшен двадцать лет. По ночам там горит свет.'},
  {id:'blade', name:'Клинок Рассвета', kind:'item', aliases:[], desc:'Найден в сокровищнице. Три заряда света.'},
  {id:'ambush', name:'Засада на перевале', kind:'event', aliases:[], desc:'Разбойники ждали отряд на Северной дороге.'},
  {id:'oath', name:'Клятва Альдрена', kind:'story', aliases:['знак клятвы'], desc:'Знак, который оставляют люди Альдрена.'},
];
const D = (d) => new Date(2026, 9, d);
let NOTES = [
  {id:'tavern', title:'Таверна «Седой ворон»', cat:'general', session:1, date:D(2), text:'Отряд собрался в Лесной гавани. Хозяйка Мира рассказала о пропавшем караване на Северной дороге.', tags:[], pinned:false, rec:[]},
  {id:'letter', title:'Письмо из Лесной гавани', cat:'story', session:2, date:D(4), text:'В письме есть имя Элиан и упоминание старой пристани. Пока не установлено, тот ли это человек.', tags:['улика', 'письмо'], pinned:true, rec:[]},
  {id:'ambushn', title:'Засада на перевале', cat:'session', session:3, date:D(6), text:'На Северной дороге нас ждали разбойники. Командир ушёл к перевалу, оставив знак клятвы Альдрена.', tags:['бой'], pinned:false, rec:[]},
  {id:'blade', title:'Клинок из сокровищницы', cat:'artifact', session:4, date:D(8), text:'После победы на Северной дороге найден клинок. Мастер назвал его Клинком Рассвета: три заряда света.', tags:['снаряжение'], pinned:false, rec:[]},
  {id:'pier', title:'Старая пристань', cat:'location', session:5, date:D(11), text:'Мира отвела нас к старой пристани. Доски свежие — кто-то чинил её недавно.', tags:[], pinned:false, rec:['letter']},
  {id:'last', title:'Последние слова', cat:'npc', session:6, date:D(14), text:'Альдрен попросил найти сына Элиана. Он ушёл из семьи ради её защиты. Элиан из старого письма — его сын?', tags:['Альдрен'], pinned:false, rec:['letter']},
  {id:'shadow', title:'Тень у маяка', cat:'story', session:7, date:D(18), text:'Ночью у маяка мелькнул силуэт со знаком клятвы. Мира узнала походку — Элиан жив и прячется на Маяке.', tags:['зацепка'], pinned:true, rec:['pier', 'last']},
  {id:'lamp', title:'Свет на маяке', cat:'location', session:7, date:D(18), text:'Маяк заброшен двадцать лет, но по ночам там горит свет. Дорога к нему одна — тропа от старой пристани.', tags:[], pinned:false, rec:['pier']},
  {id:'mira', title:'Мира что-то скрывает', cat:'npc', session:6, date:D(14), text:'Мира слишком быстро узнала знак клятвы. Альдрен говорил о ней тепло, но имени не назвал.', tags:['подозрение'], pinned:false, rec:[]},
  {id:'shop', title:'Список покупок', cat:'general', session:null, date:D(19), text:'Верёвка, факелы, зелье лечения для Миры.', tags:[], pinned:false, rec:[]},
];
let QUESTS = [
  {id:'find', title:'Найти Элиана', status:'active', session:6, date:D(14), text:'Передать последние слова Альдрена. Первая зацепка ведёт в Лесную гавань.', steps:[
    {t:'Перечитать старое письмо', done:true}, {t:'Расспросить Миру о пристани', done:true}, {t:'Проследить за тенью у маяка', done:false}, {t:'Передать Элиану слова отца', done:false}], rec:['last', 'letter']},
  {id:'caravan', title:'Пропавший караван', status:'active', session:1, date:D(2), text:'Мира просила узнать, что стало с караваном на Северной дороге.', steps:[
    {t:'Найти следы на дороге', done:true}, {t:'Допросить пленного разбойника', done:false}], rec:['tavern']},
  {id:'road', title:'Угроза на северной дороге', status:'completed', session:3, date:D(6), text:'Дорога снова безопасна.', steps:[{t:'Проверить Северную дорогу', done:true}], rec:['ambushn']},
  {id:'guild', title:'Долг перед гильдией', status:'failed', session:4, date:D(8), text:'Не успели доставить груз к сроку.', steps:[{t:'Доставить груз в гавань', done:false}], rec:[]},
];
// Hand-made links that the text alone would not find, and the ones turned off.
const MANUAL = {'q:find':['elian', 'aldren'], 'n:blade':['blade']};
const EXCLUDED = {};

/* ---------- names in the text, with their endings ---------- */
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
function nameRegex(name){
  const words = name.split(/\s+/);
  const part = w => esc(w.length > 4 ? w.slice(0, w.length - 2) : w.length > 3 ? w.slice(0, w.length - 1) : w) + '[а-яёa-z]*';
  // A single proper name keeps its capital so «Мира» never matches «мир».
  return new RegExp(`(^|[^\\p{L}])(${words.map(part).join('\\s+')})(?![\\p{L}])`, words.length > 1 ? 'giu' : 'gu');
}
const entRegex = new Map();
const rx = e => { const key = e.id + ':' + e.name + (e.aliases || []).join(); if (!entRegex.has(key)) entRegex.set(key, [e.name, ...(e.aliases || [])].map(nameRegex)); return entRegex.get(key); };
function found(text){
  const hits = new Set();
  for (const e of ENT) if (rx(e).some(r => { r.lastIndex = 0; return r.test(text); })) hits.add(e.id);
  return hits;
}
const keyOf = x => (x.steps ? 'q:' : 'n:') + x.id;
const entryBy = key => key.startsWith('q:') ? QUESTS.find(q => 'q:' + q.id === key) : NOTES.find(n => 'n:' + n.id === key);
const entitiesOf = x => {
  const key = keyOf(x), ex = new Set(EXCLUDED[key] || []);
  const hits = found([x.title, x.text, ...(x.tags || []), ...(x.steps || []).map(s => s.t)].join('\n'));
  (MANUAL[key] || []).forEach(id => hits.add(id));
  return [...hits].filter(id => !ex.has(id)).map(id => ENT.find(e => e.id === id)).filter(Boolean);
};
const recordsOf = id => [...NOTES, ...QUESTS].filter(x => entitiesOf(x).some(e => e.id === id));
const together = id => {
  const counts = new Map();
  for (const r of recordsOf(id)) for (const e of entitiesOf(r)) if (e.id !== id) counts.set(e.id, (counts.get(e.id) || 0) + 1);
  return [...counts].sort((a, b) => b[1] - a[1]).map(([eid, n]) => ({e:ENT.find(e => e.id === eid), n}));
};
// Threads of an entry: the ones it points to and the ones pointing at it.
const threadsOf = x => {
  const key = keyOf(x), out = [];
  for (const k of x.rec || []) { const t = entryBy(k.includes(':') ? k : 'n:' + k); if (t) out.push({x:t, why:'Связано тобой'}); }
  for (const y of [...NOTES, ...QUESTS]) if (y !== x && (y.rec || []).some(k => (k.includes(':') ? k : 'n:' + k) === key)) out.push({x:y, why:'Ссылается на эту запись'});
  return out.filter((t, i) => out.findIndex(u => u.x === t.x) === i);
};

/* Marks the entities in a text: each name a tappable mark in its kind's colour. */
function marked(text, live = true){
  const spans = [];
  for (const e of ENT) for (const r of rx(e)) {
    r.lastIndex = 0; let m;
    while ((m = r.exec(text))) { const s = m.index + m[1].length; spans.push([s, s + m[2].length, e]); if (r.lastIndex === m.index) r.lastIndex++; }
  }
  spans.sort((a, b) => a[0] - b[0]);
  let out = '', at = 0;
  for (const [s, end, e] of spans) {
    if (s < at) continue;
    out += escHtml(text.slice(at, s));
    const k = KINDS[e.kind];
    out += live ? `<button type="button" class="mk" data-ent="${e.id}" style="--acc:var(--a${k.acc})">${escHtml(text.slice(s, end))}</button>` : `<span class="mk" style="--acc:var(--a${k.acc})">${escHtml(text.slice(s, end))}</span>`;
    at = end;
  }
  return out + escHtml(text.slice(at));
}
const escHtml = s => s.replace(/[&<>"]/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;'}[c]));

/* Search that forgives Russian endings: each word is cut to its stem. */
const stem = w => w.length > 5 ? w.slice(0, -2) : w.length > 3 ? w.slice(0, -1) : w;
function matches(x, q){
  const words = q.toLowerCase().split(/\s+/).filter(Boolean).map(stem);
  if (!words.length) return true;
  const hay = [x.title, x.text, ...(x.tags || []), ...(x.steps || []).map(s => s.t), ...entitiesOf(x).map(e => e.name)].join(' ').toLowerCase();
  return words.every(w => hay.includes(w));
}

/* ---------- state and navigation ---------- */
let stack = [{s:'home'}], focus = null, query = '', palette = 'monokai', quote = QUOTES[0], foldDone = true;
const app = () => $('#app');
const cur = () => stack[stack.length - 1];
function go(screen){ stack.push(screen); buzz.tick(); show(1); }
function back(){ if (stack.length < 2) return; stack.pop(); buzz.tick(); show(-1); }
function show(dir = 0){
  const y = cur().s === 'home' ? (cur().y || 0) : 0;
  render();
  const page = $('#app .page4'), scr = $('#app .scroller');
  if (scr) scr.scrollTop = y;
  if (!dir || reduced || !page) return;
  page.animate([{transform:`translateX(${dir * 36}px)`, opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.snappy, .42)});
}
let painted = null;
function render(){
  const s = cur();
  // Re-rendering the same screen keeps its scroll; a new screen starts at the top.
  const y = painted === s ? $('#app .scroller')?.scrollTop : null; painted = s;
  if (s.s === 'home') app().innerHTML = homeHTML();
  if (s.s === 'entry') app().innerHTML = entryHTML(entryBy(s.key));
  if (s.s === 'editor') app().innerHTML = editorHTML(s);
  if (s.s === 'atlas') app().innerHTML = atlasHTML(s);
  bind();
  if (y != null && $('#app .scroller')) $('#app .scroller').scrollTop = y;
  if ($('#controls') && $('#controls').childElementCount) controls();
}
// Keeps the home list where it was when an entry opens over it.
// The bar shows its title once the page's own big title has scrolled away.
document.addEventListener('scroll', e => { if (!e.target.classList?.contains('scroller')) return;
  if (cur().s === 'home') cur().y = e.target.scrollTop;
  const bar = $('#app .top4'); if (bar && cur().s !== 'editor') bar.classList.toggle('titled', e.target.scrollTop > 96); }, true);

/* ---------- small pieces ---------- */
const seal = (ic, acc, cls = '') => `<span class="seal4 ${cls}" style="--acc:var(--a${acc})">${icon(ic)}</span>`;
const token = (e, cls = '') => { const k = KINDS[e.kind]; return `<button type="button" class="tok4 ${cls}" data-ent="${e.id}" style="--acc:var(--a${k.acc})"><span class="tg">${icon(k.ic)}</span><b>${escHtml(e.name)}</b></button>`; };
const dots = list => `<span class="edots">${list.slice(0, 5).map(e => `<i style="background:var(--a${KINDS[e.kind].acc})"></i>`).join('')}</span>`;
const ring = (done, total, size = 64, key = 'r') => {
  const r = size / 2 - 5, c = 2 * Math.PI * r, p = total ? done / total : 0;
  return `<span class="ring" style="width:${size}px;height:${size}px"><svg viewBox="0 0 ${size} ${size}"><circle class="rt" cx="${size / 2}" cy="${size / 2}" r="${r}"/><circle class="rf" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke-dasharray="${c}" stroke-dashoffset="${c * (1 - p)}"/></svg><b class="num">${odo(done, 'ring-' + key + size)}<small>/${total}</small></b></span>`;
};
const topbar = (title, {backBtn = true, actions = '', titled = false} = {}) => `<div class="top4 glass ${titled ? 'titled' : ''}">
    ${backBtn ? `<button type="button" class="round" data-a="back" aria-label="Назад">${icon('back')}</button>` : ''}
    <div class="tb-title">${title}</div>${actions}</div>`;

/* ---------- home: the session tape, the shelf and the board ---------- */
// Sessions are a tape, not a field: the player taps «+» when a new session
// starts, and every new record lands in the latest one on its own.
let sessions = 7, sessPick = null, tapeX = null;
function visible(list){
  return list.filter(x => matches(x, query) && (!focus || entitiesOf(x).some(e => e.id === focus)) && (!sessPick || x.session === sessPick));
}
const countIn = n => [...NOTES, ...QUESTS].filter(x => x.session === n).length;
function tapeHTML(){
  const n = sessPick ? countIn(sessPick) : 0;
  return `<div class="tape-h"><span class="cap">${sessPick ? `Сессия ${sessPick}` : `Идёт сессия ${sessions}`}</span>
      ${sessPick ? `<button type="button" class="tclr" data-a="unsess">${n} ${plural(n, 'запись', 'записи', 'записей')} · все сессии ${icon('x')}</button>` : `<small>новые записи попадут в неё</small>`}</div>
    <div class="tape" id="tape"><div class="rail">${Array.from({length:sessions}, (_, i) => i + 1).map(s => { const c = countIn(s);
      return `<button type="button" class="sbub ${s === sessions ? 'now' : ''} ${sessPick === s ? 'sel' : ''} ${c ? '' : 'empty'}" data-sess-f="${s}" data-flip="s:${s}" aria-label="Сессия ${s}: ${c} ${plural(c, 'запись', 'записи', 'записей')}"><b class="num">${s}</b><i class="cnt">${'<u></u>'.repeat(Math.min(3, c))}</i></button>`; }).join('')}
      <button type="button" class="sbub add" data-a="newsess" data-flip="s:add" aria-label="Новая сессия"><b>${icon('plus')}</b><i class="cnt"></i></button></div></div>`;
}
function noteCard(n){
  const c = CATS[n.cat], ents = entitiesOf(n);
  return `<button type="button" class="card4" data-open="n:${n.id}" data-drag="${n.id}" data-flip="n:${n.id}" style="--acc:var(--a${c.acc})">
    <span class="c-k">${icon(c.ic)}<span>${c.n}</span></span>
    <b class="c-t">${escHtml(n.title)}</b>
    <span class="c-x">${escHtml(n.text)}</span>
    ${ents.length || n.session ? `<span class="c-f">${dots(ents)}${n.session ? `<small class="num">сессия ${n.session}</small>` : ''}</span>` : ''}
  </button>`;
}
function pinCard(n){
  const c = CATS[n.cat];
  return `<button type="button" class="pcard" data-open="n:${n.id}" data-drag="${n.id}" data-flip="n:${n.id}" style="--acc:var(--a${c.acc})">
    <span class="c-k">${icon(c.ic)}<span>${c.n}</span>${icon('bookmark', 'pinic')}</span><b class="c-t">${escHtml(n.title)}</b><span class="c-x">${escHtml(n.text)}</span></button>`;
}
function heroQuest(q){
  const done = q.steps.filter(s => s.done).length, next = q.steps.find(s => !s.done);
  return `<section class="hq" data-open="q:${q.id}">
    <i class="hq-glow"></i>
    <div class="hq-h"><span class="cap">В работе · задание${q.session ? ` · с сессии ${q.session}` : ''}</span></div>
    <div class="hq-m"><h2>${escHtml(q.title)}</h2>${ring(done, q.steps.length, 64, q.id)}</div>
    ${next ? `<div class="step-next"><button type="button" class="chk" data-step="${q.id}:${q.steps.indexOf(next)}" aria-label="Отметить шаг"><i>${icon('check')}</i></button><span><small>Следующий шаг</small><b>${escHtml(next.t)}</b></span></div>`
      : `<div class="step-next all">${icon('check')}<span><b>Все шаги отмечены</b><small>Отметьте задание выполненным на его странице</small></span></div>`}
    <div class="hq-f">${entitiesOf(q).slice(0, 4).map(e => token(e, 'mini')).join('')}</div>
  </section>`;
}
function questRow(q){
  const done = q.steps.filter(s => s.done).length, st = QST[q.status], next = q.steps.find(s => !s.done);
  return `<button type="button" class="qrow ${q.status}" data-open="q:${q.id}" style="--acc:var(--a${st.acc})">${q.status === 'active' ? ring(done, q.steps.length, 44, q.id) : seal(st.ic, st.acc, 'sm')}
    <span class="ft"><b>${escHtml(q.title)}</b><small>${q.status === 'active' ? (next ? escHtml(next.t) : 'Все шаги отмечены') : st.n}</small></span>${icon('fwd', 'chev')}</button>`;
}
function homeHTML(){
  const quests = visible(QUESTS), active = quests.filter(q => q.status === 'active'), closed = quests.filter(q => q.status !== 'active');
  const notes = visible(NOTES), hero = active[0], pinned = notes.filter(n => n.pinned), loose = notes.filter(n => !n.pinned);
  const people = ENT.filter(e => recordsOf(e.id).length).sort((a, b) => recordsOf(b.id).length - recordsOf(a.id).length);
  const f = focus && ENT.find(e => e.id === focus);
  const filtered = query || focus || sessPick;
  return `${topbar('Журнал', {backBtn:false, actions:`<button type="button" class="round" data-a="atlas" aria-label="Атлас">${icon('grid')}</button>`})}
    <div class="scroller"><div class="page4">
      <header class="jh"><span class="cap">${HERO} · журнал</span><h1>Журнал</h1><p class="epi">${icon('quote')}<span>${quote}</span></p></header>
      ${tapeHTML()}
      <label class="search4">${icon('search')}<input id="q" type="search" placeholder="Найти в журнале: имя, место, слово" value="${escHtml(query)}" autocomplete="off">${query ? `<button type="button" class="qx" data-a="clearq" aria-label="Очистить">${icon('x')}</button>` : ''}</label>
      <div class="strip">${people.map(e => token(e, focus === e.id ? 'on' : '')).join('')}</div>
      ${f ? `<div class="focus4" style="--acc:var(--a${KINDS[f.kind].acc})">${seal(KINDS[f.kind].ic, KINDS[f.kind].acc, 'sm')}<span><small>Фокус истории</small><b>${escHtml(f.name)}</b></span><button type="button" class="btn sm" data-ent="${f.id}">Карточка</button><button type="button" class="round sm" data-a="unfocus" aria-label="Снять фокус">${icon('x')}</button></div>` : ''}
      ${filtered ? `<p class="found">Найдено: ${quests.length + notes.length} ${plural(quests.length + notes.length, 'запись', 'записи', 'записей')}</p>` : ''}
      ${hero ? heroQuest(hero) : ''}
      ${active.length > 1 || closed.length ? `<div class="sec4"><h3>Задания</h3><small>${active.length} в работе</small></div>
        <div class="qlist">${active.slice(1).map(questRow).join('')}
        ${closed.length ? `<button type="button" class="fold ${foldDone ? '' : 'open'}" data-a="fold">${icon('down', 'chev')}<span>Завершённые и проваленные · ${closed.length}</span></button>
          <div class="reveal ${foldDone ? '' : 'open'}"><div><div class="qlist">${closed.map(questRow).join('')}</div></div></div>` : ''}</div>` : ''}
      <div class="sec4"><h3>Закреплённое</h3><small>${pinned.length ? 'вниз — открепить' : ''}</small></div>
      <div class="shelf" id="shelf">${pinned.map(pinCard).join('')}${pinned.length ? '' : `<div class="shelf-drop">${icon('bookmark')}<span>Удерживайте запись и перетащите сюда, чтобы закрепить</span></div>`}</div>
      <div class="sec4"><h3>Записи</h3><small>${loose.length ? 'удерживайте, чтобы переставить' : ''}</small></div>
      ${loose.length ? `<div class="board" id="board">${loose.map(noteCard).join('')}</div>` : `<p class="empty4">${filtered ? 'Ничего не нашлось.' : 'Здесь пока пусто. Начните с того, что случилось сегодня.'}</p>`}
    </div></div>
    <div class="dock4 glass"><button type="button" class="write" data-a="write">${icon('feather')}<span>Записать</span></button><button type="button" class="round lg" data-a="newquest" aria-label="Новое задание">${icon('flag')}</button></div>`;
}

/* Masonry of two columns, placed by hand so a reorder glides: each card
   takes the shorter column, and left/top transition on a spring. */
const GAP = 8;
function layoutBoard(order){
  const b = $('#board'); if (!b) return;
  const cards = order || $$('.card4', b), w = (b.clientWidth - GAP) / 2, cols = [0, 0];
  for (const el of cards) {
    if (el.classList.contains('gone')) continue;
    el.style.width = w + 'px';
    const col = cols[0] <= cols[1] ? 0 : 1;
    el.style.left = col * (w + GAP) + 'px'; el.style.top = cols[col] + 'px';
    cols[col] += el.offsetHeight + GAP;
  }
  b.style.height = Math.max(0, Math.max(...cols) - GAP) + 'px';
}
const inside = (el, x, y, pad = 0) => { const r = el.getBoundingClientRect(); return x > r.left - pad && x < r.right + pad && y > r.top - pad && y < r.bottom + pad; };
// Moves the given notes into the slots they occupy in NOTES, in a new order.
function reorderNotes(ids){
  const slots = NOTES.map((x, i) => ids.includes(x.id) ? i : -1).filter(i => i >= 0), moved = ids.map(id => NOTES.find(x => x.id === id));
  slots.forEach((s, k) => { NOTES[s] = moved[k]; });
}
let dragging = false, justDragged = 0;
document.addEventListener('touchmove', e => { if (dragging) e.preventDefault(); }, {passive:false});
document.addEventListener('contextmenu', e => { if (e.target.closest?.('[data-drag]')) e.preventDefault(); });
function bindDrag(){
  $$('#app [data-drag]').forEach(el => el.addEventListener('pointerdown', e => {
    if (e.button) return;
    const touch = e.pointerType !== 'mouse', p = {x:e.clientX, y:e.clientY, id:e.pointerId};
    let drag = null, timer = 0;
    const cleanup = () => { clearTimeout(timer); el.classList.remove('pressing'); removeEventListener('pointermove', move); removeEventListener('pointerup', up); removeEventListener('pointercancel', up); };
    const move = ev => {
      if (ev.pointerId !== p.id) return;
      p.x = ev.clientX; p.y = ev.clientY;
      if (!drag) { if (Math.hypot(ev.clientX - e.clientX, ev.clientY - e.clientY) < 8) return; if (touch) return cleanup(); drag = liftCard(el, e); }
      drag.move(p.x, p.y);
    };
    const up = ev => { if (ev.pointerId !== p.id) return; cleanup(); if (drag) drag.drop(); };
    // A finger holds the card to lift it; a mouse just pulls it.
    if (touch) { el.classList.add('pressing'); timer = setTimeout(() => { el.classList.remove('pressing'); drag = liftCard(el, e); drag.move(p.x, p.y); }, 340); }
    addEventListener('pointermove', move); addEventListener('pointerup', up); addEventListener('pointercancel', up);
  }));
}
function liftCard(el, e){
  dragging = true; buzz.medium();
  const id = el.dataset.drag, note = NOTES.find(x => x.id === id), fromShelf = !!el.closest('#shelf');
  const phone = $('#phone').getBoundingClientRect(), r = el.getBoundingClientRect(), grab = {x:e.clientX - r.left, y:e.clientY - r.top};
  const ghost = el.cloneNode(true);
  ghost.removeAttribute('data-flip'); ghost.className += ' ghost4';
  Object.assign(ghost.style, {left:r.left - phone.left + 'px', top:r.top - phone.top + 'px', width:r.width + 'px', height:r.height + 'px'});
  $('#phone').appendChild(ghost);
  requestAnimationFrame(() => ghost.classList.add('up'));
  el.classList.add('hole');
  const shelf = $('#shelf'), board = $('#board'), scr = $('#app .scroller');
  let order = board ? $$('.card4', board) : [], zone = fromShelf ? 'shelf' : 'board', over = null, last = 0, x = e.clientX, y = e.clientY, raf = 0;
  const hit = () => {
    const z = inside(shelf, x, y, 24) ? 'shelf' : 'board';
    if (z !== zone) {
      zone = z; buzz.tick();
      shelf.classList.toggle('drop', zone === 'shelf' && !fromShelf);
      board?.classList.toggle('drop', zone === 'board' && fromShelf);
      // Leaving its place, the card's slot closes up; coming back reopens it.
      el.classList.toggle('gone', zone !== (fromShelf ? 'shelf' : 'board'));
      if (!fromShelf) layoutBoard(order);
    }
    if (zone !== 'board' || !board) return;
    const o = order.find(c => c !== el && inside(c, x, y));
    if (fromShelf) { over = o || null; return; }
    if (!o || o === over || performance.now() - last < 140) { if (!o) over = null; return; }
    over = o; last = performance.now();
    const i = order.indexOf(el), j = order.indexOf(o); order.splice(i, 1); order.splice(j, 0, el);
    buzz.tick(); layoutBoard(order);
  };
  // Near the top or bottom edge the page scrolls under the held card.
  const edge = () => {
    const s = scr.getBoundingClientRect(); let v = 0;
    if (y < s.top + 130) v = -(s.top + 130 - y) / 7; else if (y > s.bottom - 130) v = (y - (s.bottom - 130)) / 7;
    if (v) { scr.scrollTop += clamp(v, -16, 16); hit(); }
    raf = requestAnimationFrame(edge);
  };
  raf = requestAnimationFrame(edge);
  return {
    move(nx, ny){ x = nx; y = ny; ghost.style.translate = `${x - grab.x - (r.left)}px ${y - grab.y - (r.top)}px`; hit(); },
    drop(){
      dragging = false; justDragged = Date.now(); cancelAnimationFrame(raf);
      if (!fromShelf && zone === 'shelf') { note.pinned = true; NOTES.splice(NOTES.indexOf(note), 1); NOTES.unshift(note); buzz.light(); toast('Закреплено'); }
      else if (fromShelf && zone === 'board') {
        note.pinned = false; NOTES.splice(NOTES.indexOf(note), 1);
        const at = over ? NOTES.findIndex(n => n.id === over.dataset.drag) : NOTES.findIndex(n => !n.pinned);
        NOTES.splice(at < 0 ? NOTES.length : at, 0, note); buzz.light(); toast('Откреплено');
      }
      else if (!fromShelf) { reorderNotes(order.map(c => c.dataset.drag)); buzz.light(); }
      else buzz.tick();
      // The card flies from where it was let go to its new place.
      ghost.setAttribute('data-flip', 'n:' + id); el.removeAttribute('data-flip'); ghost.classList.remove('up');
      live(() => { ghost.remove(); render(); });
    },
  };
}
function bindHome(){
  const q = $('#q'); q.addEventListener('input', () => { query = q.value; const at = q.selectionStart; render(); const n = $('#q'); n.focus(); n.setSelectionRange(at, at); });
  layoutBoard();
  bindDrag();
  const tape = $('#tape');
  tape.scrollLeft = tapeX ?? tape.scrollWidth;
  tape.addEventListener('scroll', () => { tapeX = tape.scrollLeft; });
  $$('[data-sess-f]').forEach(b => {
    const s = +b.dataset.sessF;
    b.addEventListener('click', () => { if (b.dataset.held) return; sessPick = sessPick === s ? null : s; buzz.tick(); live(render); });
    // The latest session, while still empty, can be taken back with a hold.
    if (s !== sessions || countIn(s) || sessions < 2) return;
    let t = 0;
    b.addEventListener('pointerdown', () => { b.classList.add('holding'); t = setTimeout(() => { b.dataset.held = 1; sessions--; sessPick = null; tapeX = null; buzz.medium(); live(render); toast(`Сессия ${s} убрана`); }, 600); });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => b.addEventListener(ev, () => { clearTimeout(t); b.classList.remove('holding'); }));
  });
}
function newSession(){
  sessions++; sessPick = null; buzz.medium();
  const was = $('#tape').scrollLeft; tapeX = was;
  live(render);
  const tape = $('#tape'); tape.scrollTo({left:tape.scrollWidth, behavior:reduced ? 'auto' : 'smooth'}); tapeX = null;
  toast(`Сессия ${sessions} началась — новые записи попадут в неё`);
}

/* ---------- the entry page ---------- */
function entryHTML(x){
  const q = !!x.steps, ents = entitiesOf(x), th = threadsOf(x);
  const head = q ? QST[x.status] : CATS[x.cat];
  const meta = [q ? 'Задание' : CATS[x.cat].n, x.session ? `Сессия ${x.session}` : null, dateText(x.date)].filter(Boolean).join(' · ');
  const done = q ? x.steps.filter(s => s.done).length : 0;
  return `${topbar(escHtml(x.title), {actions:`<button type="button" class="round" data-a="edit" aria-label="Изменить">${icon('edit')}</button><button type="button" class="round" data-a="more" aria-label="Ещё">${icon('more')}</button>`})}
    <div class="scroller"><div class="page4 doc">
      <header class="dh" style="--acc:var(--a${head.acc})">
        <i class="dh-glow"></i>
        ${seal(head.ic, head.acc, 'lg')}
        <span class="cap">${meta}</span>
        <h1>${escHtml(x.title)}</h1>
        ${x.pinned ? `<span class="pinmark">${icon('bookmark')} Закреплено</span>` : ''}
      </header>
      <div class="prose4">${x.text.split('\n').map(p => `<p>${marked(p)}</p>`).join('')}</div>
      ${q ? `<section class="qbox"><div class="qb-h">${ring(done, x.steps.length, 76, x.id)}<span><b class="num">${done === x.steps.length ? 'Все шаги отмечены' : `Шаг ${done + 1} из ${x.steps.length}`}</b><small>Коснитесь шага, чтобы отметить</small></span></div>
          <div class="steps">${x.steps.map((s, i) => `<button type="button" class="step ${s.done ? 'done' : ''}" data-step="${x.id}:${i}"><i class="box">${icon('check')}</i><span>${marked(s.t, false)}</span></button>`).join('')}</div>
          <div class="addstep"><input id="newStep" placeholder="Новый шаг" autocomplete="off"><button type="button" class="round sm" data-a="addstep" aria-label="Добавить шаг">${icon('plus')}</button></div>
          ${segHTML([['active', 'Активно'], ['completed', 'Выполнено'], ['failed', 'Провалено']], x.status, 'qStatus')}</section>` : ''}
      ${(x.tags || []).length ? `<div class="tags4">${x.tags.map(t => `<span>#${escHtml(t)}</span>`).join('')}</div>` : ''}
      ${ents.length ? `<div class="sec4"><h3>Действующие лица</h3><small>касание — карточка</small></div><div class="actors strip">${ents.map(e => { const k = KINDS[e.kind]; return `<button type="button" class="actor" data-ent="${e.id}" style="--acc:var(--a${k.acc})"><span class="ag">${icon(k.ic)}</span><b>${escHtml(e.name)}</b><small>${k.n}</small></button>`; }).join('')}</div>` : ''}
      ${th.length ? `<div class="sec4"><h3>Нити</h3><small>${th.length} ${plural(th.length, 'связь', 'связи', 'связей')}</small></div>
        <div class="threads">${th.map(t => { const tq = !!t.x.steps, h = tq ? QST[t.x.status] : CATS[t.x.cat];
          return `<button type="button" class="thr" data-open="${keyOf(t.x)}" style="--acc:var(--a${h.acc})">${seal(h.ic, h.acc, 'sm')}<span class="ft"><b>${escHtml(t.x.title)}</b><small>${t.why}${t.x.session ? ` · сессия ${t.x.session}` : ''}</small></span>${icon('fwd', 'chev')}</button>`; }).join('')}</div>` : ''}
    </div></div>`;
}

/* ---------- entity peek ---------- */
function entitySheet(id){
  const e = ENT.find(x => x.id === id), k = KINDS[e.kind], recs = recordsOf(id), tg = together(id);
  openSheet(`<div class="ehead" style="--acc:var(--a${k.acc})">${seal(k.ic, k.acc, 'lg')}<span class="cap">${k.n}${e.aliases.length ? ` · ${escHtml(e.aliases.join(', '))}` : ''}</span><h2 class="bs-title">${escHtml(e.name)}</h2></div>
    ${e.desc ? `<p class="edesc">${escHtml(e.desc)}</p>` : ''}
    <div class="estats"><span><b class="num">${odo(recs.length, 'erec')}</b><small>${plural(recs.length, 'запись', 'записи', 'записей')}</small></span><span><b class="num">${odo(tg.length, 'etog')}</b><small>${plural(tg.length, 'пересечение', 'пересечения', 'пересечений')}</small></span></div>
    ${tg.length ? `<div class="mini-h">Вместе в записях</div><div class="strip wrap">${tg.slice(0, 6).map(t => token(t.e)).join('')}</div>` : ''}
    <div class="mini-h">Где встречается</div>
    <div class="trail">${recs.sort((a, b) => (a.session || 99) - (b.session || 99)).map(r => `<button type="button" class="tr" data-open="${keyOf(r)}"><span class="bead num">${r.session || '—'}</span><span class="ft"><b>${escHtml(r.title)}</b><small>${r.steps ? 'Задание' : CATS[r.cat].n}</small></span>${icon('fwd', 'chev')}</button>`).join('')}</div>
    <button type="button" class="btn primary wide" data-a2="atlas" style="height:52px">${icon('grid')} Открыть в Атласе</button>`, {onOpen(sh, close){
      $$('[data-open]', sh).forEach(b => b.addEventListener('click', () => close(0, () => go({s:'entry', key:b.dataset.open}))));
      $$('[data-ent]', sh).forEach(b => b.addEventListener('click', () => close(0, () => entitySheet(b.dataset.ent))));
      $('[data-a2="atlas"]', sh).addEventListener('click', () => close(0, () => go({s:'atlas', sel:id})));
    }});
}

/* ---------- the writing sheet ---------- */
function editorHTML(s){
  const d = s.draft;
  const q = d.kind === 'quest', ents = draftEntities(d), sugg = suggestions(d);
  const head = q ? QST.active : CATS[d.cat];
  return `<div class="top4 glass titled"><button type="button" class="round" data-a="cancel" aria-label="Отменить">${icon('x')}</button>
      <div class="tb-title">${s.key ? (q ? 'Задание' : 'Запись') : (q ? 'Новое задание' : 'Новая запись')}</div>
      <button type="button" class="btn primary sm" data-a="save" ${d.title.trim() ? '' : 'disabled'}>Сохранить</button></div>
    <div class="scroller"><div class="page4 sheetpage">
      <input id="dTitle" class="t-in" placeholder="${q ? 'Что нужно сделать?' : 'Что случилось?'}" value="${escHtml(d.title)}" autocomplete="off">
      <div class="body-wrap"><div class="mirror" id="mirror" aria-hidden="true">${marked(d.text, false)}<br></div><textarea id="dText" placeholder="Пишите как есть — имена людей и мест журнал узнает сам">${escHtml(d.text)}</textarea></div>
      <div class="live" id="live">${liveHTML(ents, sugg, d)}</div>
      ${q ? `<div class="sec4"><h3>Шаги</h3><small>${d.steps.length}</small></div>
        <div class="ed-steps">${d.steps.map((st, i) => `<div class="ed-step"><button type="button" class="chk ${st.done ? 'on' : ''}" data-dstep="${i}"><i>${icon('check')}</i></button><input data-stept="${i}" value="${escHtml(st.t)}" placeholder="Шаг"><button type="button" class="round sm" data-delstep="${i}" aria-label="Убрать шаг">${icon('x')}</button></div>`).join('')}
          <button type="button" class="addline" data-a="dstep">${icon('plus')} Шаг</button></div>` : ''}
      <div class="sec4"><h3>Нити</h3><small>записи, связанные с этой</small></div>
      <div class="strip wrap">${d.rec.map(k => { const x = entryBy(k); if (!x) return ''; return `<span class="lnk">${icon('link')}<b>${escHtml(x.title)}</b><button type="button" data-unrec="${k}" aria-label="Убрать связь">${icon('x')}</button></span>`; }).join('')}<button type="button" class="addline inline" data-a="link">${icon('link')} Связать запись</button></div>
      ${!q ? `<div class="sec4"><h3>Метки</h3></div><div class="strip wrap">${d.tags.map((t, i) => `<span class="lnk ht">#${escHtml(t)}<button type="button" data-untag="${i}" aria-label="Убрать метку">${icon('x')}</button></span>`).join('')}<input id="dTag" class="taginput" placeholder="+ метка" autocomplete="off"></div>` : ''}
    </div></div>
    <div class="tools glass">
      ${q ? `<span class="tool static" style="--acc:var(--a${head.acc})"><i>${icon(head.ic)}</i><span>Задание</span></span>` : `<button type="button" class="tool" data-a="cat" style="--acc:var(--a${head.acc})"><i>${icon(head.ic)}</i><span>${head.n}</span>${icon('down', 'chev')}</button>`}
      <span class="sess-step"><button type="button" data-sess="-1" aria-label="Раньше">${icon('minus')}</button><span><small>сессия</small><b class="num">${d.session ? odo(d.session, 'dsess') : '—'}</b></span><button type="button" data-sess="1" aria-label="Позже">${icon('plus')}</button></span>
      ${!q ? `<button type="button" class="tool icon ${d.pinned ? 'on' : ''}" data-a="pin" aria-label="Закрепить" style="--acc:var(--a0)"><i>${icon('bookmark')}</i></button>` : ''}
      <button type="button" class="tool icon" data-a="photo" aria-label="Фото" style="--acc:var(--a4)"><i>${icon('image')}</i></button>
    </div>`;
}
const draftEntities = d => {
  const hits = found([d.title, d.text, ...d.tags, ...(d.steps || []).map(s => s.t)].join('\n'));
  d.manual.forEach(id => hits.add(id));
  return {on:[...hits].filter(id => !d.excluded.includes(id)).map(id => ENT.find(e => e.id === id)).filter(Boolean),
    off:d.excluded.map(id => ENT.find(e => e.id === id)).filter(Boolean)};
};
// Capitalised words inside sentences that no entity knows yet.
function suggestions(d){
  const text = [d.title, d.text].join('. ');
  const known = ENT.flatMap(e => [e.name, ...e.aliases]).map(s => s.toLowerCase());
  const out = [];
  const re = /(?<=[^.!?\n«"]\s)([А-ЯЁ][а-яё]{2,}(?:\s+[А-ЯЁ][а-яё]{2,})?)/gu; let m;
  while ((m = re.exec(text))) {
    const w = m[1];
    if (d.dismissed.includes(w) || out.includes(w)) continue;
    if (known.some(k => w.toLowerCase().startsWith(stem(k)) || k.startsWith(stem(w.toLowerCase())))) continue;
    out.push(w);
  }
  return out.slice(0, 4);
}
function liveHTML(ents, sugg, d){
  if (!ents.on.length && !ents.off.length && !sugg.length) return `<p class="hint4">${icon('spark')} Имена и места из текста появятся здесь — журнал свяжет запись с ними</p>`;
  return `${ents.on.length || ents.off.length ? `<div class="live-h"><span class="cap">Узнано в тексте</span></div><div class="strip wrap">${ents.on.map(e => `<span class="tok4 on rm" style="--acc:var(--a${KINDS[e.kind].acc})"><span class="tg">${icon(KINDS[e.kind].ic)}</span><b>${escHtml(e.name)}</b><button type="button" data-ex="${e.id}" aria-label="Не связывать">${icon('x')}</button></span>`).join('')}${ents.off.map(e => `<button type="button" class="tok4 off" data-inc="${e.id}" style="--acc:var(--a${KINDS[e.kind].acc})"><span class="tg">${icon(KINDS[e.kind].ic)}</span><b>${escHtml(e.name)}</b></button>`).join('')}<button type="button" class="tok4 add" data-a="attach">${icon('plus')}<b>История</b></button></div>` : ''}
    ${sugg.length ? `<div class="live-h"><span class="cap">Новые имена?</span></div><div class="strip wrap">${sugg.map(w => `<button type="button" class="sugg" data-sugg="${escHtml(w)}">${icon('plus')}<b>${escHtml(w)}</b></button>`).join('')}</div>` : ''}`;
}

/* ---------- the Atlas ---------- */
/* ---------- the Atlas: a living constellation ---------- */
// A small force simulation that never quite stops: shared records pull,
// everyone repels, and each star wanders a little on its own. Positions
// and the camera survive re-renders.
const AW = 390, AH = 430;
const SKY = Array.from({length:52}, (_, i) => ({x:(Math.sin(i * 91.7) * .5 + .5) * 700 - 155, y:(Math.sin(i * 37.3 + 1) * .5 + .5) * 760 - 165, r:.6 + (i % 3) * .4, o:.12 + (i % 5) * .06}));
let sim = null, cam = {x:0, y:0, k:1}, camTo = null, kindsOff = new Set(), aq = '', atlasRaf = 0;
function syncSim(){
  const first = !sim;
  if (!sim) sim = {nodes:new Map(), links:[]};
  ENT.forEach((e, i) => {
    const n = sim.nodes.get(e.id);
    if (n) n.e = e; else sim.nodes.set(e.id, {e, x:AW / 2 + 150 * Math.cos(i * 2.399), y:AH / 2 + 150 * Math.sin(i * 2.399), vx:0, vy:0, a:Math.random() * 6.28, fixed:false});
  });
  for (const id of [...sim.nodes.keys()]) if (!ENT.some(e => e.id === id)) sim.nodes.delete(id);
  sim.links = [];
  for (let i = 0; i < ENT.length; i++) for (let j = i + 1; j < ENT.length; j++) {
    const n = recordsOf(ENT[i].id).filter(r => entitiesOf(r).some(e => e.id === ENT[j].id)).length;
    if (n) sim.links.push({a:ENT[i].id, b:ENT[j].id, n});
  }
  if (first) for (let i = 0; i < 400; i++) step(false);
}
function step(wander){
  const N = [...sim.nodes.values()];
  for (const a of N) for (const b of N) if (a !== b) {
    const dx = a.x - b.x, dy = a.y - b.y, d2 = Math.max(120, dx * dx + dy * dy), d = Math.sqrt(d2), f = 5600 / d2;
    a.vx += dx / d * f; a.vy += dy / d * f;
  }
  for (const l of sim.links) {
    const a = sim.nodes.get(l.a), b = sim.nodes.get(l.b), dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 1, f = (d - 100) * .011 * Math.min(2, l.n);
    a.vx += dx / d * f; a.vy += dy / d * f; b.vx -= dx / d * f; b.vy -= dy / d * f;
  }
  for (const n of N) {
    n.vx += (AW / 2 - n.x) * .0028; n.vy += (AH / 2 - n.y) * .0028;
    if (wander) { n.a += (Math.random() - .5) * .12; n.vx += Math.cos(n.a) * .045; n.vy += Math.sin(n.a) * .045; }
    if (n.fixed) { n.vx = n.vy = 0; continue; }
    n.vx *= .8; n.vy *= .8;
    const sp = Math.hypot(n.vx, n.vy); if (sp > 14) { n.vx *= 14 / sp; n.vy *= 14 / sp; }
    n.x += n.vx; n.y += n.vy;
  }
}
const radius = id => 13 + Math.min(4, recordsOf(id).length) * 3;
function starsHTML(){
  return `<div class="stars" id="stars"><svg viewBox="0 0 ${AW} ${AH}" id="starsvg">
      <g id="sky">${SKY.map(s => `<circle cx="${s.x.toFixed(1)}" cy="${s.y.toFixed(1)}" r="${s.r}" opacity="${s.o.toFixed(2)}"/>`).join('')}</g>
      <g id="cam"><g id="lines">${sim.links.map(l => `<line class="ln" data-l="${l.a}|${l.b}" stroke-width="${(1 + l.n * .7).toFixed(1)}"/>`).join('')}</g>
      <g id="nodes">${[...sim.nodes.values()].map(n => { const k = KINDS[n.e.kind], r = radius(n.e.id);
        return `<g class="node" data-node="${n.e.id}" style="--acc:var(--a${k.acc})"><g class="nbody">
          <circle class="halo" r="${r + 10}"/><circle class="nb" r="${r}"/><use href="#i-${k.ic}" x="-9" y="-9" width="18" height="18" class="ni"/>
          <text y="${r + 15}" text-anchor="middle">${escHtml(n.e.name)}</text></g></g>`; }).join('')}</g></g>
    </svg>
    <button type="button" class="round sm recenter" data-a="recenter" aria-label="Вернуть вид" ${cam.k === 1 && !cam.x && !cam.y ? 'hidden' : ''}>${icon('target')}</button>
    <span class="stars-hint">Тяните звезду · щипок — масштаб</span></div>`;
}
function atlasHTML(s){
  syncSim();
  const sel = ENT.find(e => e.id === s.sel) || null;
  const counts = Object.fromEntries(Object.keys(KINDS).map(k => [k, ENT.filter(e => e.kind === k).length]));
  return `${topbar('Атлас', {actions:`<button type="button" class="round" data-a="newent" aria-label="Новая сущность">${icon('plus')}</button>`})}
    <div class="scroller"><div class="page4">
      <header class="jh"><span class="cap">${HERO}</span><h1>Атлас</h1><p class="sub4">Люди, места и события — и как они связаны записями.</p></header>
      <label class="search4">${icon('search')}<input id="aq" type="search" placeholder="Найти имя или место" value="${escHtml(aq)}" autocomplete="off"></label>
      <div class="kinds">${Object.entries(KINDS).map(([k, v]) => `<button type="button" class="kind ${kindsOff.has(k) ? 'off' : ''}" data-kind="${k}" style="--acc:var(--a${v.acc})"><i>${icon(v.ic)}</i>${v.pl}<small class="num">${counts[k]}</small></button>`).join('')}</div>
      ${starsHTML()}
      <div id="detail">${sel ? detailHTML(sel) : emptyDetail}</div>
    </div></div>`;
}
const emptyDetail = '<p class="empty4">Коснитесь звезды — здесь появится её история.</p>';
function detailHTML(e){
  const k = KINDS[e.kind], recs = recordsOf(e.id).sort((a, b) => (a.session || 99) - (b.session || 99)), tg = together(e.id);
  return `<section class="edetail" style="--acc:var(--a${k.acc})"><i class="dh-glow"></i>
      <div class="ed-h">${seal(k.ic, k.acc, 'lg')}<span><span class="cap">${k.n}${e.aliases.length ? ` · ${escHtml(e.aliases.join(', '))}` : ''}</span><h2>${escHtml(e.name)}</h2></span><button type="button" class="round sm" data-a="editent" aria-label="Изменить">${icon('edit')}</button></div>
      ${e.desc ? `<p class="edesc">${escHtml(e.desc)}</p>` : ''}
      <div class="estats"><span><b class="num">${odo(recs.length, 'drec')}</b><small>${plural(recs.length, 'запись', 'записи', 'записей')}</small></span><span><b class="num">${odo(tg.length, 'dtog')}</b><small>${plural(tg.length, 'пересечение', 'пересечения', 'пересечений')}</small></span>
        <button type="button" class="btn sm tonal" data-a="focusent">${icon('search')} Фокус журнала</button></div>
    </section>
    ${tg.length ? `<div class="sec4"><h3>Вместе в записях</h3></div><div class="strip wrap">${tg.map(t => `${token(t.e)}`).join('')}</div>` : ''}
    <div class="sec4"><h3>След истории</h3><small>по сессиям</small></div>
    <div class="trail wide">${recs.map(r => `<button type="button" class="tr" data-open="${keyOf(r)}"><span class="bead num">${r.session || '—'}</span><span class="ft"><b>${escHtml(r.title)}</b><small>${escHtml(r.text)}</small></span>${icon('fwd', 'chev')}</button>`).join('') || '<p class="empty4">Пока ни одной записи.</p>'}</div>`;
}

/* ---------- binding ---------- */
// Records open their page; names open their card, filter the journal from
// its strip, or pick their star in the Atlas.
function bindLinks(root){
  $$('[data-open]', root).forEach(b => b.addEventListener('click', e => { if (e.target.closest('.chk, .mk') || Date.now() - justDragged < 400) return; go({s:'entry', key:b.dataset.open}); }));
  $$('[data-ent]', root).forEach(b => b.addEventListener('click', e => { e.stopPropagation(); const s = cur();
    if (s.s === 'home' && b.closest('.strip')) { focus = focus === b.dataset.ent ? null : b.dataset.ent; buzz.tick(); return live(render); }
    if (s.s === 'atlas') { if (s.sel !== b.dataset.ent) selectStar(b.dataset.ent); return $('#stars').scrollIntoView({behavior:reduced ? 'auto' : 'smooth', block:'center'}); }
    entitySheet(b.dataset.ent); }));
}
function bind(){
  const s = cur();
  bindLinks($('#app'));
  $$('#app [data-step]').forEach(b => b.addEventListener('click', e => { e.stopPropagation(); toggleStep(b); }));
  if (s.s === 'home') bindHome();
  if (s.s === 'entry') {
    const x = entryBy(s.key);
    if (x.steps) {
      segment($('#qStatus'), b => { x.status = b.dataset.v; buzz.medium(); toast(x.status === 'completed' ? 'Задание выполнено' : x.status === 'failed' ? 'Задание провалено' : 'Задание снова в работе');
        const sl = $('.dh .seal4'); const h = QST[x.status]; sl.style.setProperty('--acc', `var(--a${h.acc})`); sl.innerHTML = icon(h.ic); replay(sl, 'stampin'); $('.dh').style.setProperty('--acc', `var(--a${h.acc})`); });
      const ns = $('#newStep'); const add = () => { if (!ns.value.trim()) return; x.steps.push({t:ns.value.trim(), done:false}); buzz.light(); live(render); setTimeout(() => replay($$('.step').at(-1), 'stampin')); };
      ns.addEventListener('keydown', e => { if (e.key === 'Enter') add(); });
      $('[data-a="addstep"]').addEventListener('click', add);
    }
  }
  if (s.s === 'editor') bindEditor(s);
  if (s.s === 'atlas') bindAtlas(s);
}
function toggleStep(b){
  const [id, i] = b.dataset.step.split(':'), q = QUESTS.find(x => x.id === id), st = q.steps[+i];
  st.done = !st.done; st.done ? buzz.light() : buzz.tick();
  if (st.done && !reduced) { b.closest('.step, .step-next')?.classList.add('ticking'); return setTimeout(() => { live(render); }, 380); }
  live(render);
}
document.addEventListener('click', e => {
  const t = e.target.closest('[data-a]'); if (!t || !t.closest('#app')) return;
  const a = t.dataset.a, s = cur();
  if (a === 'back') return back();
  if (a === 'atlas') return go({s:'atlas', sel:null});
  if (a === 'clearq') { query = ''; return live(render); }
  if (a === 'unfocus') { focus = null; buzz.tick(); return live(render); }
  if (a === 'newsess') return newSession();
  if (a === 'unsess') { sessPick = null; buzz.tick(); return live(render); }
  if (a === 'fold') { foldDone = !foldDone; buzz.tick(); t.classList.toggle('open'); t.nextElementSibling.classList.toggle('open'); return; }
  if (a === 'write') return go({s:'editor', draft:newDraft('note')});
  if (a === 'newquest') return go({s:'editor', draft:newDraft('quest')});
  if (a === 'edit') return go({s:'editor', key:s.key, draft:draftOf(entryBy(s.key))});
  if (a === 'more') return moreSheet(entryBy(s.key));
  if (a === 'focusent') { focus = s.sel; stack = [{s:'home'}]; buzz.light(); show(-1); return toast('Журнал смотрит на ' + ENT.find(e => e.id === focus).name); }
  if (a === 'newent' || a === 'editent') return entityEditor(a === 'editent' ? s.sel : null);
});
function moreSheet(x){
  const q = !!x.steps;
  openSheet(`<span class="bs-kicker">${escHtml(x.title)}</span><h2 class="bs-title">Запись</h2>
    <div class="blist">${!q ? `<button type="button" class="brow2" data-m="pin"><span class="bic" style="--a3:var(--a0)">${icon('bookmark')}</span><span class="ft"><b>${x.pinned ? 'Открепить' : 'Закрепить'}</b></span></button>` : ''}
      <button type="button" class="brow2" data-m="del"><span class="bic" style="--a3:var(--a0)">${icon('x')}</span><span class="ft"><b>Удалить</b></span></button></div>`, {onOpen(sh, close){
      $('[data-m="pin"]', sh)?.addEventListener('click', () => close(0, () => { x.pinned = !x.pinned; buzz.light(); live(render); toast(x.pinned ? 'Закреплено' : 'Откреплено'); }));
      $('[data-m="del"]', sh).addEventListener('click', () => close(0, () => { (q ? QUESTS : NOTES).splice((q ? QUESTS : NOTES).indexOf(x), 1); buzz.medium(); back(); toast('Удалено'); }));
    }});
}

/* ---------- editor ---------- */
const newDraft = kind => ({kind, title:'', text:'', cat:'general', session:sessions, pinned:false, tags:[], rec:[], steps:kind === 'quest' ? [{t:'', done:false}] : [], manual:[], excluded:[], dismissed:[]});
const draftOf = x => ({kind:x.steps ? 'quest' : 'note', title:x.title, text:x.text, cat:x.cat || 'general', session:x.session, pinned:!!x.pinned, tags:[...(x.tags || [])], rec:[...(x.rec || [])].map(k => k.includes(':') ? k : 'n:' + k),
  steps:(x.steps || []).map(s => ({...s})), manual:[...(MANUAL[keyOf(x)] || [])], excluded:[...(EXCLUDED[keyOf(x)] || [])], dismissed:[]});
function bindEditor(s){
  const d = s.draft, t = $('#dTitle'), tx = $('#dText'), mirror = $('#mirror');
  const grow = () => { tx.style.height = 'auto'; tx.style.height = Math.max(160, tx.scrollHeight) + 'px'; };
  grow();
  let timer = 0;
  const refreshLive = () => { const l = $('#live'); const before = l.innerHTML; l.innerHTML = liveHTML(draftEntities(d), suggestions(d), d); if (l.innerHTML !== before) { buzz.tick(); $$('.tok4.on, .sugg', l).forEach(el => replay(el, 'popin')); } bindLive(s); };
  t.addEventListener('input', () => { d.title = t.value; $('[data-a="save"]').disabled = !d.title.trim(); clearTimeout(timer); timer = setTimeout(refreshLive, 260); });
  tx.addEventListener('input', () => { d.text = tx.value; mirror.innerHTML = marked(d.text, false) + '<br>'; grow(); clearTimeout(timer); timer = setTimeout(refreshLive, 260); });
  bindLive(s);
  $$('[data-dstep]').forEach(b => b.addEventListener('click', () => { const st = d.steps[+b.dataset.dstep]; st.done = !st.done; b.classList.toggle('on', st.done); buzz.tick(); }));
  $$('[data-stept]').forEach(i => i.addEventListener('input', () => { d.steps[+i.dataset.stept].t = i.value; }));
  $$('[data-delstep]').forEach(b => b.addEventListener('click', () => { d.steps.splice(+b.dataset.delstep, 1); buzz.tick(); render(); }));
  $$('[data-unrec]').forEach(b => b.addEventListener('click', () => { d.rec = d.rec.filter(k => k !== b.dataset.unrec); buzz.tick(); render(); }));
  $$('[data-untag]').forEach(b => b.addEventListener('click', () => { d.tags.splice(+b.dataset.untag, 1); buzz.tick(); render(); }));
  $('#dTag')?.addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.value.trim()) { d.tags.push(e.target.value.trim().replace(/^#/, '')); buzz.light(); render(); setTimeout(() => $('#dTag').focus()); } });
  $$('[data-sess]').forEach(b => b.addEventListener('click', () => { d.session = clamp((d.session || 0) + +b.dataset.sess, 0, 99) || null; buzz.tick(); const el = $('.sess-step b'); el.innerHTML = d.session ? odo(d.session, 'dsess') : '—'; }));
  $('[data-a="dstep"]')?.addEventListener('click', () => { d.steps.push({t:'', done:false}); buzz.tick(); render(); setTimeout(() => $$('[data-stept]').at(-1).focus()); });
  $('[data-a="cancel"]').addEventListener('click', () => back());
  $('[data-a="save"]').addEventListener('click', () => save(s));
  $('[data-a="pin"]')?.addEventListener('click', e => { d.pinned = !d.pinned; e.currentTarget.classList.toggle('on', d.pinned); buzz.light(); });
  $('[data-a="photo"]').addEventListener('click', () => toast('Фото: выбор из галереи или камеры'));
  $('[data-a="cat"]')?.addEventListener('click', () => catSheet(d));
  $('[data-a="link"]').addEventListener('click', () => linkSheet(s));
}
function bindLive(s){
  const d = s.draft, l = $('#live');
  $$('[data-ex]', l).forEach(b => b.addEventListener('click', () => { d.excluded.push(b.dataset.ex); d.manual = d.manual.filter(x => x !== b.dataset.ex); buzz.tick(); l.innerHTML = liveHTML(draftEntities(d), suggestions(d), d); bindLive(s); }));
  $$('[data-inc]', l).forEach(b => b.addEventListener('click', () => { d.excluded = d.excluded.filter(x => x !== b.dataset.inc); buzz.tick(); l.innerHTML = liveHTML(draftEntities(d), suggestions(d), d); bindLive(s); }));
  $$('[data-sugg]', l).forEach(b => b.addEventListener('click', () => kindPicker(s, b.dataset.sugg)));
  $('[data-a="attach"]', l)?.addEventListener('click', () => attachSheet(s));
}
function kindPicker(s, name){
  openSheet(`<span class="bs-kicker">Новое имя в истории</span><h2 class="bs-title">Кто или что это?</h2><p class="bs-sub">Журнал будет узнавать это имя в записях и покажет его в Атласе.</p>
    <label class="fld"><span>Имя</span><input id="kName" value="${escHtml(name)}" autocomplete="off"></label>
    <div class="kgrid">${Object.entries(KINDS).map(([k, v]) => `<button type="button" class="kpick" data-k="${k}" style="--acc:var(--a${v.acc})">${seal(v.ic, v.acc)}<b>${v.n}</b></button>`).join('')}</div>
    <button type="button" class="btn wide" data-skip style="height:48px">Это не имя</button>`, {onOpen(sh, close){
      $$('[data-k]', sh).forEach(b => b.addEventListener('click', () => { replay(b, 'stampin'); buzz.light();
        const typed = $('#kName', sh).value.trim() || name;
        ENT.push({id:'e' + Date.now(), name:typed, kind:b.dataset.k, aliases:[], desc:''});
        if (typed !== name) s.draft.dismissed.push(name);
        setTimeout(() => close(0, () => { const l = $('#live'); l.innerHTML = liveHTML(draftEntities(s.draft), suggestions(s.draft), s.draft); bindLive(s); $('#mirror').innerHTML = marked(s.draft.text, false) + '<br>'; toast(`${typed}: ${KINDS[b.dataset.k].n.toLowerCase()} в Атласе`); }), reduced ? 0 : 260); }));
      $('[data-skip]', sh).addEventListener('click', () => close(0, () => { s.draft.dismissed.push(name); const l = $('#live'); l.innerHTML = liveHTML(draftEntities(s.draft), suggestions(s.draft), s.draft); bindLive(s); }));
    }});
}
function attachSheet(s){
  const d = s.draft, on = new Set(draftEntities(d).on.map(e => e.id));
  openSheet(`<span class="bs-kicker">Связать с историей</span><h2 class="bs-title">Кто ещё здесь?</h2>
    <div class="strip wrap">${ENT.map(e => `<button type="button" class="tok4 ${on.has(e.id) ? 'on' : ''}" data-pick="${e.id}" style="--acc:var(--a${KINDS[e.kind].acc})"><span class="tg">${icon(KINDS[e.kind].ic)}</span><b>${escHtml(e.name)}</b></button>`).join('')}</div>
    <button type="button" class="btn primary wide" data-close style="height:52px">Готово</button>`, {onOpen(sh, close){
      $$('[data-pick]', sh).forEach(b => b.addEventListener('click', () => { const id = b.dataset.pick; if (on.has(id)) { on.delete(id); d.manual = d.manual.filter(x => x !== id); if (found([d.title, d.text].join('\n')).has(id)) d.excluded.push(id); } else { on.add(id); d.manual.push(id); d.excluded = d.excluded.filter(x => x !== id); } b.classList.toggle('on'); buzz.tick(); }));
      $('[data-close]', sh).addEventListener('click', () => close());
    }, onClose(){ render(); }});
}
function linkSheet(s){
  const d = s.draft, self = s.key;
  openSheet(`<span class="bs-kicker">Нити</span><h2 class="bs-title">Связать запись</h2>
    <div class="blist">${[...QUESTS, ...NOTES].filter(x => keyOf(x) !== self).map(x => { const k = keyOf(x), q = !!x.steps, h = q ? QST[x.status] : CATS[x.cat], on = d.rec.includes(k);
      return `<button type="button" class="brow2 ${on ? 'on' : ''}" data-l="${k}">${seal(h.ic, h.acc, 'sm')}<span class="ft"><b>${escHtml(x.title)}</b><small class="muted">${q ? 'Задание' : h.n}${x.session ? ` · сессия ${x.session}` : ''}</small></span><span class="lk">${icon(on ? 'check' : 'plus')}</span></button>`; }).join('')}</div>`, {onOpen(sh){
      $$('[data-l]', sh).forEach(b => b.addEventListener('click', () => { const k = b.dataset.l; d.rec = d.rec.includes(k) ? d.rec.filter(x => x !== k) : [...d.rec, k]; b.classList.toggle('on'); $('.lk', b).innerHTML = icon(d.rec.includes(k) ? 'check' : 'plus'); buzz.tick(); }));
    }, onClose(){ render(); }});
}
function catSheet(d){
  openSheet(`<span class="bs-kicker">Запись</span><h2 class="bs-title">О чём она?</h2>
    <div class="kgrid">${Object.entries(CATS).map(([k, v]) => `<button type="button" class="kpick ${d.cat === k ? 'on' : ''}" data-c="${k}" style="--acc:var(--a${v.acc})">${seal(v.ic, v.acc)}<b>${v.n}</b></button>`).join('')}</div>`, {onOpen(sh, close){
      $$('[data-c]', sh).forEach(b => b.addEventListener('click', () => { d.cat = b.dataset.c; buzz.tick(); replay(b, 'stampin'); setTimeout(() => close(0, render), reduced ? 0 : 220); }));
    }});
}
function save(s){
  const d = s.draft;
  let x = s.key ? entryBy(s.key) : null;
  if (!x) { x = d.kind === 'quest' ? {id:'q' + Date.now(), status:'active', date:new Date(), steps:[], rec:[]} : {id:'n' + Date.now(), date:new Date(), rec:[]}; (d.kind === 'quest' ? QUESTS : NOTES).unshift(x); }
  Object.assign(x, {title:d.title.trim(), text:d.text.trim(), session:d.session, rec:[...d.rec]});
  if (d.kind === 'quest') x.steps = d.steps.filter(st => st.t.trim()); else Object.assign(x, {cat:d.cat, tags:[...d.tags], pinned:d.pinned});
  MANUAL[keyOf(x)] = [...d.manual]; EXCLUDED[keyOf(x)] = [...d.excluded];
  buzz.medium();
  stack.pop();
  if (!s.key) stack.push({s:'entry', key:keyOf(x)});
  show(1);
  toast(s.key ? 'Сохранено' : 'Записано в летопись');
}
function entityEditor(id){
  const e = id ? ENT.find(x => x.id === id) : {name:'', kind:'person', aliases:[], desc:''};
  let kind = e.kind;
  openSheet(`<span class="bs-kicker">Атлас</span><h2 class="bs-title">${id ? 'Изменить' : 'Новое имя'}</h2>
    <label class="fld"><span>Имя</span><input id="eName" value="${escHtml(e.name)}"></label>
    <div class="kgrid">${Object.entries(KINDS).map(([k, v]) => `<button type="button" class="kpick ${kind === k ? 'on' : ''}" data-k="${k}" style="--acc:var(--a${v.acc})">${seal(v.ic, v.acc)}<b>${v.n}</b></button>`).join('')}</div>
    <label class="fld"><span>Другие имена — через запятую</span><input id="eAl" value="${escHtml(e.aliases.join(', '))}"></label>
    <label class="fld"><span>Кто это или что</span><input id="eDesc" value="${escHtml(e.desc)}"></label>
    <button type="button" class="btn primary wide" data-ok style="height:52px">Сохранить</button>`, {onOpen(sh, close){
      $$('[data-k]', sh).forEach(b => b.addEventListener('click', () => { kind = b.dataset.k; $$('[data-k]', sh).forEach(x => x.classList.toggle('on', x === b)); buzz.tick(); }));
      $('[data-ok]', sh).addEventListener('click', () => { const name = $('#eName', sh).value.trim(); if (!name) return toast('Нужно имя');
        if (id) Object.assign(e, {name, kind, aliases:$('#eAl', sh).value.split(',').map(x => x.trim()).filter(Boolean), desc:$('#eDesc', sh).value.trim()});
        else { e.id = 'e' + Date.now(); Object.assign(e, {name, kind, aliases:$('#eAl', sh).value.split(',').map(x => x.trim()).filter(Boolean), desc:$('#eDesc', sh).value.trim()}); ENT.push(e); cur().sel = e.id; }
        entRegex.clear(); buzz.light(); close(0, render); });
    }});
}

/* ---------- atlas bindings ---------- */
const shownIds = () => new Set(ENT.filter(e => !kindsOff.has(e.kind) && (!aq || [e.name, ...e.aliases].some(n => n.toLowerCase().includes(aq.toLowerCase())))).map(e => e.id));
// Classes only: the selected star grows over the rest, its neighbours stay
// lit, the others fade; a held star lights its own threads.
function paintStars(){
  const s = cur(), shown = shownIds(), sel = s.sel, held = s.held;
  const near = sel ? new Set([sel, ...together(sel).map(t => t.e.id)]) : null;
  $$('#nodes .node').forEach(g => { const id = g.dataset.node;
    g.classList.toggle('on', id === sel); g.classList.toggle('held', id === held);
    g.classList.toggle('dim', !shown.has(id) || (near && !near.has(id) && id !== held)); });
  $$('#lines .ln').forEach(l => { const [a, b] = l.dataset.l.split('|'), hot = [sel, held].some(x => x && (a === x || b === x));
    l.classList.toggle('hot', hot); l.classList.toggle('dim', !shown.has(a) || !shown.has(b) || (!!(sel || held) && !hot)); });
}
function drawStars(){
  for (const n of sim.nodes.values()) n.g?.setAttribute('transform', `translate(${n.x.toFixed(1)} ${n.y.toFixed(1)})`);
  for (const l of sim.links) { if (!l.el) continue; const a = sim.nodes.get(l.a), b = sim.nodes.get(l.b);
    l.el.setAttribute('x1', a.x.toFixed(1)); l.el.setAttribute('y1', a.y.toFixed(1)); l.el.setAttribute('x2', b.x.toFixed(1)); l.el.setAttribute('y2', b.y.toFixed(1)); }
  $('#cam')?.setAttribute('transform', `translate(${cam.x.toFixed(1)} ${cam.y.toFixed(1)}) scale(${cam.k.toFixed(3)})`);
  // The far sky moves a third as much: a little depth when panning.
  $('#sky')?.setAttribute('transform', `translate(${(cam.x * .3).toFixed(1)} ${(cam.y * .3).toFixed(1)})`);
}
function selectStar(id){
  const s = cur(); s.sel = s.sel === id ? null : id; buzz.tick();
  // The chosen star is drawn last, over its neighbours, before it grows.
  const g = s.sel && $(`#nodes [data-node="${s.sel}"]`);
  if (g) { g.parentNode.appendChild(g); g.getBoundingClientRect(); }
  paintStars();
  const d = $('#detail'), e = ENT.find(x => x.id === s.sel);
  live(() => { d.innerHTML = e ? detailHTML(e) : emptyDetail; bindLinks(d); });
  if (e && !reduced) d.animate([{transform:'translateY(18px)', opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.snappy, .42)});
}
function bindAtlas(s){
  const aqi = $('#aq'); aqi.addEventListener('input', () => { aq = aqi.value; const at = aqi.selectionStart; render(); const n = $('#aq'); n.focus(); n.setSelectionRange(at, at); });
  $$('[data-kind]').forEach(b => b.addEventListener('click', () => { const k = b.dataset.kind; kindsOff.has(k) ? kindsOff.delete(k) : kindsOff.add(k); b.classList.toggle('off'); buzz.tick(); paintStars(); }));
  const stars = $('#stars'), svg = $('#starsvg'), rc = $('.recenter');
  for (const n of sim.nodes.values()) n.g = $(`#nodes [data-node="${n.e.id}"]`);
  for (const l of sim.links) l.el = $(`#lines [data-l="${l.a}|${l.b}"]`);
  paintStars(); drawStars();
  const view = (x, y) => { const r = svg.getBoundingClientRect(); return {x:(x - r.left) * AW / r.width, y:(y - r.top) * AH / r.height}; };
  const world = p => ({x:(p.x - cam.x) / cam.k, y:(p.y - cam.y) / cam.k});
  const zoomAt = (p, k) => { k = clamp(k, .5, 2.6); cam.x = p.x - (p.x - cam.x) * k / cam.k; cam.y = p.y - (p.y - cam.y) * k / cam.k; cam.k = k; camTo = null; rc.hidden = false; };
  const ptrs = new Map(); let g = null;
  stars.addEventListener('pointerdown', e => {
    if (e.target.closest('.recenter')) return;
    try { stars.setPointerCapture(e.pointerId); } catch {}
    ptrs.set(e.pointerId, view(e.clientX, e.clientY)); stars.classList.add('used');
    if (ptrs.size === 2) {
      // A second finger turns any gesture into a pinch about the midpoint.
      if (g?.node) { g.node.fixed = false; s.held = null; paintStars(); }
      const [a, b] = [...ptrs.values()], m = {x:(a.x + b.x) / 2, y:(a.y + b.y) / 2};
      g = {type:'pinch', d0:Math.hypot(a.x - b.x, a.y - b.y), k0:cam.k, w:world(m)};
      return;
    }
    const id = e.target.closest('[data-node]')?.dataset.node, p = ptrs.get(e.pointerId);
    g = {type:id ? 'node' : 'pan', id, node:id && sim.nodes.get(id), p0:p, cx:cam.x, cy:cam.y, moved:false};
    if (g.node) { const w = world(p); g.off = {x:g.node.x - w.x, y:g.node.y - w.y}; }
  });
  stars.addEventListener('pointermove', e => {
    if (!ptrs.has(e.pointerId) || !g) return;
    const p = view(e.clientX, e.clientY); ptrs.set(e.pointerId, p);
    if (g.type === 'pinch') {
      if (ptrs.size < 2) return;
      const [a, b] = [...ptrs.values()], m = {x:(a.x + b.x) / 2, y:(a.y + b.y) / 2}, k = clamp(g.k0 * Math.hypot(a.x - b.x, a.y - b.y) / g.d0, .5, 2.6);
      cam.k = k; cam.x = m.x - g.w.x * k; cam.y = m.y - g.w.y * k; camTo = null; rc.hidden = false;
      return;
    }
    if (!g.moved && Math.hypot(p.x - g.p0.x, p.y - g.p0.y) < 5) return;
    if (!g.moved) { g.moved = true; if (g.node) { g.node.fixed = true; s.held = g.id; buzz.tick(); paintStars(); } }
    if (g.node) { const w = world(p); g.node.x = w.x + g.off.x; g.node.y = w.y + g.off.y; }
    else { cam.x = g.cx + p.x - g.p0.x; cam.y = g.cy + p.y - g.p0.y; camTo = null; rc.hidden = false; }
  });
  const end = e => {
    if (!ptrs.delete(e.pointerId) || !g) return;
    if (g.type === 'pinch') { if (!ptrs.size) g = null; return; }
    if (g.node) { g.node.fixed = false; if (g.moved) { s.held = null; paintStars(); buzz.light(); } }
    if (!g.moved && g.node) selectStar(g.id);
    else if (!g.moved && s.sel) selectStar(s.sel);
    g = null;
  };
  stars.addEventListener('pointerup', end); stars.addEventListener('pointercancel', end);
  stars.addEventListener('wheel', e => { e.preventDefault(); zoomAt(view(e.clientX, e.clientY), cam.k * Math.exp(-e.deltaY * .0016)); }, {passive:false});
  // Double tap on the sky zooms in a step; on a zoomed sky it goes back.
  stars.addEventListener('dblclick', e => { if (e.target.closest('[data-node]')) return; buzz.tick(); if (cam.k > 1.05) camTo = {x:0, y:0, k:1}; else { const p = view(e.clientX, e.clientY); camTo = {k:1.8, x:p.x - (p.x - cam.x) * 1.8 / cam.k, y:p.y - (p.y - cam.y) * 1.8 / cam.k}; } rc.hidden = false; });
  rc.addEventListener('click', () => { camTo = {x:0, y:0, k:1}; buzz.tick(); });
  cancelAnimationFrame(atlasRaf);
  const frame = () => {
    if (!svg.isConnected) return;
    step(!reduced);
    if (camTo) { const t = reduced ? 1 : .16; cam.x = lerp(cam.x, camTo.x, t); cam.y = lerp(cam.y, camTo.y, t); cam.k = lerp(cam.k, camTo.k, t);
      if (Math.abs(cam.k - camTo.k) < .002 && Math.abs(cam.x - camTo.x) < .3) { cam = {...camTo}; camTo = null; rc.hidden = cam.k === 1 && !cam.x && !cam.y; } }
    drawStars(); atlasRaf = requestAnimationFrame(frame);
  };
  atlasRaf = requestAnimationFrame(frame);
}

/* ---------- controls panel ---------- */
function controls(){
  const at = cur().s;
  $('#controls').innerHTML = `<div class="opt"><span class="lbl">Экран</span><div class="heroes">${[['home', 'Журнал'], ['note', 'Запись'], ['quest', 'Задание'], ['editor', 'Чистый лист'], ['atlas', 'Атлас']].map(([k, n]) => `<button type="button" data-scr="${k}" aria-pressed="${(k === 'home' && at === 'home') || (k === 'atlas' && at === 'atlas') || (k === 'editor' && at === 'editor') || (k === 'note' && at === 'entry' && cur().key?.startsWith('n:')) || (k === 'quest' && at === 'entry' && cur().key?.startsWith('q:'))}">${n}</button>`).join('')}</div></div>
    <div class="opt"><span class="lbl">Палитра</span>${segHTML([['monokai', 'Monokai'], ['dune', 'Rose of Dune'], ['nord', 'Nord']], palette, 'palSeg')}</div>
    <button type="button" class="toggle" id="redm" aria-checked="${reduced}"><span class="switch"></span>Меньше движения</button>`;
  $$('[data-scr]').forEach(b => b.addEventListener('click', () => { const k = b.dataset.scr;
    stack = [{s:'home'}];
    if (k === 'note') stack.push({s:'entry', key:'n:last'});
    if (k === 'quest') stack.push({s:'entry', key:'q:find'});
    if (k === 'editor') stack.push({s:'editor', draft:newDraft('note')});
    if (k === 'atlas') stack.push({s:'atlas', sel:'elian'});
    buzz.tick(); show(1); }));
  segment($('#palSeg'), b => { palette = b.dataset.v; applyPalette(palette); });
  $('#redm').addEventListener('click', e => { reduced = !reduced; document.body.classList.toggle('reduce', reduced); e.currentTarget.setAttribute('aria-checked', reduced); });
}
// Newest first; the player's own order takes over once they drag.
NOTES.sort((a, b) => (b.session || 0) - (a.session || 0));
applyPalette('monokai');
quote = QUOTES[Math.floor(Math.random() * QUOTES.length)];
render();
controls();
