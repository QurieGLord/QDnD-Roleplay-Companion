/* ================= Wave 3: session and combat ================= */
// Veterans of the Cycle build (levels 15–20): numbers taken from the app's
// own fixture, so the prototype speaks in the values the sheet will show.
const HEROES = [
  {id:'paladin', name:'Cycle · Паладин', cls:'Паладин 18', sub:'Клятва Преданности', acc:2, lvl:18, max:148, ac:19, speed:30, init:0, dex:0, con:2, pb:6,
    hd:{d:10, max:18}, conSave:false,
    res:[{n:'Наложение рук', ic:'hand', acc:2, max:90, rest:'long'}, {n:'Божественное чувство', ic:'eye', acc:4, max:5, rest:'long'}, {n:'Божественный канал', ic:'sun', acc:1, max:1, rest:'short'}],
    slots:[4,3,3,3,2], start:{hp:148, temp:0},
    effects:[{k:'sacred', n:'Священное оружие', ic:'sword', acc:2, left:10, max:10}]},
  {id:'barbarian', name:'Cycle · Варвар', cls:'Варвар 20', sub:'Путь Берсерка', acc:0, lvl:20, max:285, ac:19, speed:40, init:2, dex:2, con:7, pb:6,
    hd:{d:12, max:20}, conSave:true,
    res:[{n:'Ярость', ic:'axe', acc:0, max:Infinity, rest:'long'}],
    slots:[], start:{hp:285, temp:0},
    effects:[{k:'rage', n:'Ярость', ic:'axe', acc:0, left:10, max:10, resist:true}]},
  {id:'wizard', name:'Cycle · Волшебник', cls:'Волшебник 20', sub:'Школа Воплощения', acc:4, lvl:20, max:182, ac:12, speed:30, init:2, dex:2, con:5, pb:6,
    hd:{d:6, max:20}, conSave:false,
    res:[{n:'Магическое восстановление', ic:'star', acc:4, max:1, rest:'long'}],
    slots:[4,3,3,3,3,2,2,1,1], start:{hp:182, temp:12},
    effects:[{k:'haste', n:'Ускорение', ic:'timer', acc:5, left:10, max:10, conc:true}]},
  {id:'rogue', name:'Cycle · Плут', cls:'Плут 17', sub:'Вор', acc:4, lvl:17, max:173, ac:16, speed:30, init:5, dex:5, con:5, pb:6,
    hd:{d:8, max:17}, conSave:false,
    res:[], slots:[], start:{hp:0, temp:0}, effects:[]},
];
const CONDS = [
  ['blinded','Ослеплён','eye',0,'Атаки по вам — с преимуществом, ваши — с помехой'],
  ['charmed','Очарован','heart',0,'Не атакуете очарователя, он — с преимуществом в общении'],
  ['deafened','Оглох','wave',4,'Проваливаете проверки, где нужен слух'],
  ['frightened','Испуган','skull',5,'Помеха, пока видите источник; не приближаетесь к нему'],
  ['grappled','Схвачен','hand',1,'Скорость 0'],
  ['incapacitated','Недееспособен','x',0,'Ни действий, ни реакций'],
  ['invisible','Невидим','mask',5,'Ваши атаки с преимуществом, по вам — с помехой'],
  ['paralyzed','Парализован','lock',0,'Недееспособен; попадание вблизи — критическое'],
  ['petrified','Окаменел','peaks',1,'Недееспособен, сопротивление всему урону'],
  ['poisoned','Отравлен','drop',3,'Помеха на атаки и проверки'],
  ['prone','Сбит с ног','down',2,'Ползком; атаки вблизи по вам — с преимуществом'],
  ['restrained','Опутан','track',2,'Скорость 0; атаки по вам с преимуществом'],
  ['stunned','Ошеломлён','spark',1,'Недееспособен, проваливаете спасброски СИЛ и ЛОВ'],
  ['unconscious','Без сознания','moon',5,'Недееспособен, падает; попадание вблизи — крит'],
];
const EXH = ['Без истощения', 'Помеха на проверки характеристик', 'Скорость вдвое меньше', 'Помеха на атаки и спасброски', 'Максимум ОЗ вдвое меньше', 'Скорость 0', 'Смерть'];
const DTYPES = [['none','Без типа',1],['blud','Дробящий',1,true],['pierce','Колющий',4,true],['slash','Рубящий',0,true],['fire','Огонь',1],['cold','Холод',4],['poison','Яд',3],
  ['psychic','Психический',5],['radiant','Излучение',2],['necrotic','Некротический',5],['force','Силовое',5],['thunder','Звук',4],['lightning','Электричество',2],['acid','Кислота',3]];

let H, C, scene = 'overview', history = [];
// The prototype panel can fix the next d20 to check crits and fumbles.
let forceD20 = 'rand';
const d20 = () => forceD20 === '20' ? 20 : forceD20 === '1' ? 1 : 1 + Math.floor(Math.random() * 20);
function fresh(h){
  const x = structuredClone(h);
  return {...x, hp:x.start.hp, temp:x.start.temp, hdLeft:x.hd.max - 4, conds:[], exh:0,
    // A session in progress: some uses already spent, so a rest has work to do.
    res:x.res.map(r => ({...r, left:r.max === Infinity ? Infinity : Math.max(0, r.max - (r.rest === 'short' ? 1 : Math.round(r.max * .3)))})),
    slotsLeft:x.slots.map((s, i) => Math.max(0, s - (i < 3 ? 2 : 1))),
    ds:{s:0, f:0, stable:false, dead:false}, conc:(x.effects.find(e => e.conc) || {}).n || null};
}
const freshCombat = h => ({round:1, init:null, used:{act:false, bonus:false, react:false}, moved:0, dash:false, attacks:0, effects:structuredClone(h.effects), log:[]});

function pickHero(id, sc){
  const base = HEROES.find(h => h.id === id); H = fresh(base); C = freshCombat(base); history = [];
  scene = sc || (base.start.hp === 0 ? 'combat' : 'overview');
  if (scene === 'combat') { C.init = 14 + base.init; C.round = 3; }
  render(true);
}
const snap = () => { history.push(JSON.stringify({H, C})); if (history.length > 40) history.shift(); };
function undo(){ const s = history.pop(); if (!s) return toast('Отменять нечего'); ({H, C} = JSON.parse(s)); H.res.forEach(r => { if (r.left === null) r.left = Infinity; if (r.max === null) r.max = Infinity; }); buzz.light(); live(render); toast('Отменено'); }
const log = (t, acc = 'a4') => { C.log.unshift({t, acc}); if (C.log.length > 30) C.log.pop(); };

/* ---------- health rules ---------- */
const resisting = type => type && DTYPES.find(d => d[0] === type)?.[3] && C.effects.some(e => e.resist);
function damage(n, type, opts = {}){
  if (n <= 0) return; snap();
  const prevDs = H.hp === 0 ? {...H.ds} : null;
  if (C.halve && scene === 'combat') { C.halve = false; n = Math.floor(n / 2); log('Уклонение: урон вдвое', 'a4'); }
  const half = resisting(type) ? Math.floor(n / 2) : n;
  const fromTemp = Math.min(H.temp, half); H.temp -= fromTemp; let rest = half - fromTemp;
  if (H.hp === 0) {
    if (!H.ds.dead) { H.ds.stable = false; H.ds.f = Math.min(3, H.ds.f + (opts.crit ? 2 : 1)); if (H.ds.f >= 3) H.ds.dead = true; }
    log(`Урон ${half} без сознания → провал`, 'a0');
  } else {
    const over = rest - H.hp; H.hp = Math.max(0, H.hp - rest);
    if (H.hp === 0) { H.ds = {s:0, f:0, stable:false, dead:over >= H.max}; H.conds = [...new Set([...H.conds, 'unconscious'])]; dropConc('Концентрация прервана: без сознания'); }
    log(`Урон ${half}${half < n ? ` (½ от ${n})` : ''}${fromTemp ? ` · ${fromTemp} снял щит` : ''}`, 'a0');
    if (H.hp > 0 && H.conc) C.check = Math.max(10, Math.floor(half / 2));
  }
  buzz.medium(); live(render); if (prevDs) markFates(prevDs); else replay($('#life'), 'hit');
}
function heal(n){
  if (n <= 0) return; snap();
  const was = H.hp; H.hp = Math.min(H.max, H.hp + n);
  if (was === 0) { H.ds = {s:0, f:0, stable:false, dead:false}; H.conds = H.conds.filter(c => c !== 'unconscious'); log(`Лечение ${n} · снова в строю`, 'a3'); }
  else log(`Лечение ${H.hp - was}${H.hp - was < n ? ` из ${n}` : ''}`, 'a3');
  buzz.light(); live(render); replay($('#life'), 'healed');
}
function giveTemp(n){ if (n <= 0) return; snap(); const was = H.temp; H.temp = Math.max(H.temp, n); log(H.temp > was ? `Временные ОЗ ${H.temp}` : `Временные ОЗ: оставлены ${was} (больше)`, 'a4'); buzz.light(); live(render); }
function dropConc(msg){ if (!H.conc) return; C.effects = C.effects.filter(e => !e.conc); H.conc = null; C.check = null; toast(msg); log(msg, 'a5'); }

/* ---------- rendering ---------- */
const SHIELD = 'M50 4 92 18v34c0 28-18 48-42 56C26 100 8 80 8 52V18z';
const app = () => $('#app');
const hpColor = () => { const p = H.hp / H.max; return H.hp === 0 ? 'var(--outline)' : p > .5 ? 'var(--primary)' : p > .25 ? 'var(--a1)' : 'var(--a0)'; };
function lifeHTML(){
  const p = H.hp / H.max, shieldW = Math.min(1, H.temp / H.max);
  return `<section class="life" id="life" style="--hpc:${hpColor()}">
    <div class="life-top"><button type="button" data-a="hpsheet" class="life-n num" aria-label="Изменить ОЗ">${odo(H.hp, 'hp')}</button><span class="life-of num">/ ${H.max}</span>
      <button type="button" data-a="hpsheet" data-m="temp" class="life-temp ${H.temp ? '' : 'zero'}" data-peek="Временные ОЗ|Щит поверх здоровья: урон сначала снимает его">${icon('shield')}<span class="num">${odo(H.temp, 'temp')}</span></button></div>
    <div class="bar" id="hpbar" aria-label="Протяните — урон или лечение">
      <i class="fill" style="width:${p * 100}%"></i><i class="ghostbar"></i>
      ${H.temp ? `<i class="shield" style="left:calc(${p * 100}% - ${Math.min(p, shieldW) * 100}%);width:${shieldW * 100}%"></i>` : ''}
      <i class="grip"></i><span class="scrub-label"></span></div>
    <div class="life-row"><span class="hint-drag">${icon('swap')} Протяните полосу: влево — урон, вправо — лечение</span></div>
  </section>`;
}
function brinkHTML(){
  const d = H.ds, lamp = i => `<span class="lamp ${i < d.s ? 'lit' : ''}"><svg viewBox="0 0 38 50"><path class="glass2" d="M12 8h14l4 8v20l-4 8H12l-4-8V16z"/><path class="fl" d="M19 18c3 4 6 7 6 12a6 6 0 0 1-12 0c0-4 3-6 4-9 1 2 2 3 2 5 1-2 1-5 0-8z"/></svg></span>`;
  const title = d.dead ? 'Герой пал' : d.stable ? 'Стабилен' : 'На пороге';
  const sub = d.dead ? 'Три провала. Мастер может решить иначе — вернуть героя можно вручную.' : d.stable ? 'Без сознания, но больше не бросает. Любое лечение поднимет героя.' : 'Без сознания. Каждый ход — спасбросок от смерти: 10+ успех, 20 — встаёт с 1 ОЗ, 1 — два провала.';
  return `<section class="brink ${d.dead ? 'dead' : d.stable ? 'stable' : ''}" id="life">
    <span class="cap">0 ОЗ · ${H.max} максимум</span><div class="brink-h"><h3>${title}</h3><span class="info" role="button" tabindex="0" aria-label="Что это значит" data-peek="${title}|${sub}">${icon('info')}</span></div>
    <div class="fates"><div class="fcol" data-peek="Успехи|Три успеха — герой стабилен"><span class="cap">Успехи</span><div class="fate">${[0,1,2].map(lamp).join('')}</div></div>
      <div class="fcol r" data-peek="Провалы|Три провала — смерть. Урон без сознания — провал, крит — два"><span class="cap">Провалы</span><div class="fate">${[0,1,2].map(i => `<span class="skull ${i < d.f ? 'on' : ''}">${icon('skull')}</span>`).join('')}</div></div></div>
    ${d.dead || d.stable ? '' : `<div class="fatebox"><button type="button" class="fatedie" data-a="dsroll" aria-label="Спасбросок от смерти">${DIE}<b id="fateN">к20</b></button><small>Коснитесь — спасбросок</small></div>`}
    <div class="brink-out" id="fateOut"></div>
    <div class="acts">${d.dead ? `<button type="button" class="btn wide" data-a="revive">${icon('heart')} Вернуть с 1 ОЗ</button>`
      : `<button type="button" class="btn wide tonal" data-a="hpsheet" data-m="heal">${icon('heart')} Лечение</button>${d.stable ? '' : `<button type="button" class="btn wide" data-a="stabilize" data-peek="Стабилизация|Медицина Сл 10 или «Щадящий» — герой больше не бросает">${icon('check')} Стабилен</button>`}`}</div>
  </section>`;
}
function concHTML(){
  if (!H.conc) return '';
  const alert = C.check != null;
  return `<section class="conc ${alert ? 'alert' : ''}" id="conc">${icon('timer')}<div class="ft"><b>Концентрация · ${H.conc}</b>
    <small>${alert ? `Урон: спасбросок Телосложения, Сл ${C.check}` : 'Урон потребует спасбросок Телосложения'}</small></div>
    ${alert ? `<button type="button" class="btn sm primary" data-a="concroll">Бросить</button>` : `<button type="button" class="btn sm" data-a="concend">Прервать</button>`}</section>`;
}
const budget = () => H.speed * (C.dash ? 2 : 1);
function turnHTML(){
  const mv = Math.max(0, budget() - C.moved);
  const tok = (k, n, ic, acc, peek) => `<button type="button" class="tok ${C.used[k] ? 'spent' : ''}" data-a="tok" data-k="${k}" style="--acc:var(--${acc})" data-peek="${n}|${peek}"><span class="ti">${icon(C.used[k] ? 'check' : ic)}</span><small>${n}</small></button>`;
  return `<div class="sec-title">Мой ход<small>сбросится в новом раунде</small></div>
    <div class="turn">${tok('act', 'Действие', 'bolt', 'a0', 'Атака, заклинание, Рывок, Отход, Уклонение')}${tok('bonus', 'Бонусное', 'spark', 'a1', 'Если что-то даёт бонусное действие')}${tok('react', 'Реакция', 'stepback', 'a4', 'Одна до начала вашего хода: провоцированная атака, Щит')}
      <button type="button" class="tok move ${mv === 0 ? 'spent' : ''} ${C.dash ? 'dash' : ''}" data-a="move" style="--acc:var(--a3)" data-peek="Движение|Касание — линейка шагов, Рывок и трудная местность"><span class="ti">${icon(C.dash ? 'dash' : 'run')}</span><small><span class="num">${odo(mv, 'mv')}</span> фт.</small><span class="meter"><i style="width:${mv / budget() * 100}%"></i></span></button></div>`;
}
function tapeHTML(){
  const from = tapeShown ?? C.round, n = Math.max(C.round + 7, 12);
  const ends = r => C.effects.filter(e => C.round + e.left === r).map(e => `<i style="background:var(--a${e.acc})"></i>`).join('');
  return `<section class="tape" id="roundbox"><div class="tape-h"><div class="t"><span class="cap">Раунд</span><b class="num">${odo(C.round, 'round')}</b></div>
      <div class="tape-m"><span>Инициатива <b class="num">${C.init ?? '—'}</b></span><small>Листайте влево — новый раунд</small></div>
      <button type="button" class="round nx" data-a="next" aria-label="Новый раунд">${icon('fwd')}</button></div>
    <div class="beads" id="beads"><div class="rail" id="rail">${Array.from({length:n}, (_, i) => `<span class="bead ${i + 1 < from ? 'done' : i + 1 === from ? 'now' : ''}">${i + 1}<span class="ends">${ends(i + 1)}</span></span>`).join('')}</div></div>
    <div class="ribbons">${C.effects.map(e => `<button type="button" class="rib" data-a="efend" data-k="${e.k}" style="--acc:var(--a${e.acc})" data-peek="${e.n}|${e.conc ? 'Концентрация. ' : ''}Ещё ${e.left} ${plural(e.left, 'раунд', 'раунда', 'раундов')}. Касание — завершить"><span class="ri">${icon(e.ic)}</span><b>${e.n}</b><span class="rl"><i data-w="${Math.min(1, e.left / Math.min(e.max, 10)) * 100}"></i></span><span class="num">${e.left > 99 ? '99+' : e.left}</span></button>`).join('') || '<span class="muted noef">Активных эффектов нет</span>'}</div>
  </section>`;
}
function sealsHTML(){
  return `<div class="seals" id="seals">${H.conds.map(k => { const c = CONDS.find(x => x[0] === k); return `<button type="button" class="seal" data-a="conds" style="--acc:var(--a${c[3]})" data-peek="${c[1]}|${c[4]}"><span class="si">${icon(c[2])}</span>${c[1]}</button>`; }).join('')}
    ${H.exh ? `<button type="button" class="seal" data-a="conds" style="--acc:var(--a1)" data-peek="Истощение ${H.exh}|${EXH.slice(1, H.exh + 1).join(' · ')}"><span class="si">${icon('timer')}</span>Истощение ${H.exh}</button>` : ''}
    <button type="button" class="seal add" data-a="conds">${icon('plus')} Состояние</button></div>`;
}
let renderedScene = null;
function render(first){
  const base = HEROES.find(h => h.id === H.id), combat = scene === 'combat';
  $('#phone').classList.toggle('incombat', combat);
  // Keep the reading position when the same scene re-renders.
  const keepY = renderedScene === scene ? ($('#scr')?.scrollTop ?? 0) : 0;
  ribPrev = {}; $$('.rib').forEach(r => ribPrev[r.dataset.k] = parseFloat($('.rl i', r).style.width) || 0);
  const oldLife = $('#life'), oldKind = oldLife && renderedScene === scene ? oldLife.className.replace(/\b(hit|healed|morph)\b/g, '').trim() : null, oldH = oldLife?.offsetHeight;
  renderedScene = scene;
  app().innerHTML = `
    <div class="top3 glass">
      <button type="button" class="round" aria-label="Назад" data-a="${combat ? 'endc' : 'noop'}">${icon(combat ? 'x' : 'back')}</button>
      <div class="ttl-stack"><div class="tb-title">${combat ? `<span class="badge-combat"><i></i>Бой · раунд ${C.round}</span>` : H.name}</div></div>
      ${combat ? `<button type="button" class="round" data-a="logs" aria-label="Журнал боя">${icon('book')}</button>` : `<button type="button" class="round" data-a="dice" aria-label="Кости">${icon('dice')}</button>`}
      <button type="button" class="round" data-a="console" aria-label="Игровые параметры">${icon('sliders')}</button>
    </div>
    <div class="scroller" id="scr"><div class="page3">
      <div class="hero-h"><div><h2>${combat ? H.name.replace('Cycle · ', '') : H.cls}</h2><small>${combat ? H.cls + ' · ' + H.sub : H.sub}</small></div><span class="lvlchip">КД <b>${H.ac}</b></span></div>
      ${H.hp === 0 ? brinkHTML() : lifeHTML()}
      ${concHTML()}
      ${combat ? `${H.hp === 0 ? '' : turnHTML()}${arsenalHTML()}
        <div class="sec-title">Раунды<small>листайте ленту</small></div>${tapeHTML()}
        <div class="sec-title">Состояния</div>${sealsHTML()}
        ${C.log.length ? `<div class="sec-title">Журнал<button type="button" class="undo" data-a="undo" style="font:600 13px/1 var(--body)">Отменить</button></div><div class="logline">${C.log.slice(0, 6).map((l, i) => `<span class="lg ${i === 0 && !first ? 'new' : ''}" style="--acc:var(--${l.acc})"><i></i>${l.t}</span>`).join('')}</div>` : ''}`
      : `<div class="qs"><button type="button" class="q ac" data-a="acbreak"><span class="qshield"><svg viewBox="0 0 100 112" aria-hidden="true"><path d="${SHIELD}"/></svg><b class="num">${H.ac}</b></span><small>КД</small></button>${[['bolt', fmt(H.init), 'ИНИЦ'], ['run', H.speed, 'СКОР'], ['star', '+' + H.pb, 'МАСТ']].map(([ic, v, l]) => `<button type="button" class="q">${icon(ic)}<b class="num">${v}</b><small>${l}</small></button>`).join('')}</div>
        <div class="sec-title">Состояния</div>${sealsHTML()}
        <div class="sec-title">Отдых<small>кости хитов ${H.hdLeft}/${H.hd.max} · к${H.hd.d}</small></div>
        <div class="restrow"><button type="button" class="restb" data-a="rest" data-r="short">${icon('cup')} Короткий</button><button type="button" class="restb" data-a="rest" data-r="long">${icon('moon')} Длительный</button></div>
        <button type="button" class="startc" data-a="startc">${icon('sword')} Начать бой</button>`}
    </div></div>
    ${combat ? `<div class="dock3 glass"><button type="button" class="db dmg" data-a="hpsheet" data-m="dmg">${icon('minus')} Урон</button>
      <button type="button" class="d20" data-a="dice" aria-label="Бросок">${DIE}</button>
      <button type="button" class="db heal" data-a="hpsheet" data-m="heal">${icon('plus')} Лечение</button></div>` : ''}
    <div class="combat-edge"></div>`;
  $('#scr').scrollTop = keepY;
  const nl = $('#life'); if (oldKind && nl && nl.className.trim() !== oldKind) morphLife(nl, oldH, oldKind);
  bindLife(); placeTape(); bindTape(); bindArsenal();
  if ($('#controls') && $('#controls').childElementCount) controls();
}

/* ---------- life ↔ brink: one block that changes its mind ---------- */
function morphLife(el, fromH, oldKind){
  if (reduced) return;
  const toH = el.offsetHeight, rise = oldKind.startsWith('brink') && !el.classList.contains('brink');
  el.animate([{height:fromH + 'px'}, {height:toH + 'px'}], {duration:620, easing:springEasing(SPR.gentle, .62)});
  [...el.children].forEach((c, i) => c.animate([{opacity:0, transform:'translateY(14px)'}, {opacity:1, transform:'none'}],
    {duration:520, delay:120 + i * 45, easing:springEasing(SPR.snappy, .52), fill:'backwards'}));
  replay(el, 'morph');
  if (rise) {
    // Back on their feet: the number climbs from zero, the bar fills.
    const o = $('[data-odo="hp"]', el); if (o) spinTo(o, digits(o.dataset.v).map(() => 0), digits(o.dataset.v));
    const f = $('.fill', el); if (f) { const w = f.style.width; f.style.transition = 'none'; f.style.width = '0'; void f.offsetWidth; f.style.transition = 'width 900ms var(--e-snappy) 160ms'; f.style.width = w; setTimeout(() => f.style.transition = '', 1100); }
    el.classList.add('healed'); buzz.medium();
  }
}

/* ---------- the scrubbed health bar ---------- */
function bindLife(){
  const bar = $('#hpbar'); if (!bar) return;
  let d = null;
  const fill = $('.fill', bar), ghost = $('.ghostbar', bar), grip = $('.grip', bar), lab = $('.scrub-label', bar);
  bar.addEventListener('pointerdown', e => { d = {x0:e.clientX, w:bar.offsetWidth, last:0}; bar.setPointerCapture(e.pointerId); bar.classList.add('drag'); scrub(e); });
  const scrub = e => {
    const dx = e.clientX - d.x0, delta = Math.round(dx / d.w * H.max * .9);
    const effTemp = delta < 0 ? Math.min(H.temp, -delta) : 0;
    const target = delta < 0 ? clamp(H.hp + delta + effTemp, 0, H.max) : clamp(H.hp + delta, 0, H.max);
    const p0 = H.hp / H.max * 100, p1 = target / H.max * 100;
    fill.style.width = Math.min(p0, p1) + '%';
    ghost.className = 'ghostbar ' + (delta < 0 ? 'dmg' : 'heal'); ghost.style.left = Math.min(p0, p1) + '%'; ghost.style.width = Math.abs(p1 - p0) + '%';
    grip.style.left = p1 + '%'; lab.style.left = clamp(p1, 8, 92) + '%';
    lab.textContent = delta === 0 ? 'Протяните' : delta < 0 ? `−${-delta}${effTemp ? ` · щит ${effTemp}` : ''}` : `+${target - H.hp}`;
    lab.style.background = delta < 0 ? 'var(--primary)' : delta > 0 ? 'var(--heal)' : 'var(--high)'; lab.style.color = delta ? 'var(--surface)' : 'var(--fg)';
    if (Math.floor(Math.abs(delta) / 5) !== Math.floor(Math.abs(d.last) / 5)) buzz.tick();
    d.last = delta; setOdo($('[data-odo="hp"]'), target);
  };
  bar.addEventListener('pointermove', e => { if (d) scrub(e); });
  const end = () => { if (!d) return; const delta = d.last; d = null; bar.classList.remove('drag');
    if (delta < 0) damage(-delta, null); else if (delta > 0) heal(delta); else live(render); };
  bar.addEventListener('pointerup', end); bar.addEventListener('pointercancel', end);
}

/* ---------- round module ---------- */
function nextRound(){
  snap(); C.round++; C.used = {act:false, bonus:false, react:false}; C.moved = 0; C.dash = false; C.attacks = 0; C.sneakUsed = false; C.reckless = false;
  const ended = [];
  C.effects.forEach(e => { e.left--; if (e.left <= 0) ended.push(e); });
  ended.forEach(e => { if (e.conc) H.conc = null; log(`${e.n}: время вышло`, 'a' + e.acc); });
  C.effects = C.effects.filter(e => e.left > 0);
  log(`Раунд ${C.round}`, 'a2'); buzz.medium(); live(render);
  if (ended.length) toast(ended.map(e => e.n).join(', ') + ' — закончилось');
}
// The tape remembers the round it showed, so a new round slides in from
// there; a drag hands its offset and speed over to the slide.
let tapeShown = null, tapeCarry = null, ribPrev = {};
const tapeX = r => -((r - 1) * 44 + 26);
const setBeads = r => $$('#rail .bead').forEach((b, i) => { b.classList.toggle('done', i + 1 < r); b.classList.toggle('now', i + 1 === r); });
let railSpring = null;
function placeTape(){
  const rail = $('#rail'); if (!rail) { tapeShown = null; return; }
  const from = tapeShown ?? C.round, carry = tapeCarry; tapeShown = C.round; tapeCarry = null;
  railSpring = new Spring(0, SPR.gentle, v => rail.style.transform = `translateX(${v}px)`);
  railSpring.set(tapeX(from) + (carry ? carry.dx : 0));
  if (from !== C.round || carry) requestAnimationFrame(() => { setBeads(C.round); railSpring.to(tapeX(C.round), from !== C.round ? SPR.gentle : SPR.bouncy, carry ? carry.v : 0); });
  // Ribbons shrink from their old length.
  $$('.rib').forEach(r => { const i = $('.rl i', r), w = i.dataset.w, was = ribPrev[r.dataset.k];
    if (was === undefined || reduced) { i.style.width = w + '%'; return; }
    i.style.transition = 'none'; i.style.width = was + '%'; void i.offsetWidth; i.style.transition = ''; requestAnimationFrame(() => i.style.width = w + '%'); });
}
function bindTape(){
  const b = $('#beads'); if (!b) return; let d = null;
  b.addEventListener('pointerdown', e => { railSpring.stop(); d = {x0:e.clientX, base:railSpring.x, dx:0, s:[[e.timeStamp, e.clientX]]}; b.setPointerCapture(e.pointerId); });
  b.addEventListener('pointermove', e => { if (!d) return; let dx = e.clientX - d.x0;
    // Rubber band: easy one bead to the left, stiff beyond, stiffer backwards.
    if (dx > 0) dx *= .3; else if (dx < -44) dx = -44 + (dx + 44) * .3;
    if ((d.dx > -30) !== (dx > -30)) buzz.tick();
    d.dx = dx; railSpring.set(d.base + dx); d.s.push([e.timeStamp, e.clientX]); if (d.s.length > 6) d.s.shift(); });
  const end = () => { if (!d) return; const a = d.s[0], z = d.s[d.s.length - 1], v = (z[1] - a[1]) / Math.max(1, z[0] - a[0]) * 1000;
    const go = d.dx < -30 || v < -500, dx = d.dx; d = null;
    if (go) { tapeCarry = {dx, v}; nextRound(); } else railSpring.to(tapeX(C.round), SPR.bouncy, v); };
  b.addEventListener('pointerup', end); b.addEventListener('pointercancel', end);
}

/* ---------- initiative ceremony ---------- */
function ceremony(){
  const roll1 = 1 + Math.floor(Math.random() * 20), total = roll1 + H.init;
  const el = document.createElement('div'); el.className = 'ceremony';
  el.innerHTML = `<i class="veil"></i><div class="cer-body"><span class="cap">Бросок инициативы</span><div class="cer-die die2" id="cerDie">${DIE}<b>к20</b></div>
    <div class="cer-sum" id="cerSum" style="opacity:0"><span class="num">${roll1}</span><span class="mod">${fmt(H.init)} ЛОВ</span><span>=</span><span class="tot num">${total}</span></div></div>`;
  $('#phone').appendChild(el); buzz.light();
  requestAnimationFrame(() => el.classList.add('on'));
  setTimeout(() => tumble([$('#cerDie')], [roll1], 20, () => {
    const s = $('#cerSum'); s.style.transition = 'opacity 300ms'; s.style.opacity = 1; buzz.medium();
    setTimeout(() => {
      snap(); scene = 'combat'; C = freshCombat(HEROES.find(h => h.id === H.id)); C.init = total; log(`Бой начат · инициатива ${total}`, 'a1');
      el.classList.remove('on'); setTimeout(() => el.remove(), 450);
      live(render); if (!reduced) app().animate([{transform:'scale(1.04)', filter:'brightness(1.4)'}, {transform:'none', filter:'none'}], {duration:620, easing:springEasing(SPR.gentle, .62)});
    }, reduced ? 200 : 1100);
  }), reduced ? 0 : 380);
}

/* ---------- death saves ---------- */
// A lamp lit or a skull struck since the last frame plays its moment.
function markFates(prev){
  if (reduced || !prev) return;
  $$('.lamp').forEach((el, i) => { if (i >= prev.s && i < H.ds.s) setTimeout(() => replay(el, 'ignite'), (i - prev.s) * 140); });
  $$('.skull').forEach((el, i) => { if (i >= prev.f && i < H.ds.f) setTimeout(() => replay(el, 'strike'), (i - prev.f) * 160); });
  if (H.ds.f > prev.f) replay($('#life'), 'hit');
}
function deathSave(){
  const dEl = $('.fatedie'); const r = d20();
  tumble([dEl], [r], 20, () => {
    const prev = {...H.ds};
    floatUp(dEl, r, r >= 10 ? 'var(--heal)' : 'var(--primary)');
    snap(); let out;
    if (r === 20) { H.hp = 1; H.ds = {s:0, f:0, stable:false, dead:false}; H.conds = H.conds.filter(c => c !== 'unconscious'); out = '20! Герой встаёт с 1 ОЗ'; buzz.medium(); }
    else if (r === 1) { H.ds.f = Math.min(3, H.ds.f + 2); out = '1 — два провала'; }
    else if (r >= 10) { H.ds.s++; out = `${r} — успех`; }
    else { H.ds.f++; out = `${r} — провал`; }
    if (H.ds.s >= 3) { H.ds.stable = true; out = 'Три успеха — стабилен'; }
    if (H.ds.f >= 3) { H.ds.dead = true; out = 'Три провала'; }
    log(`Спасбросок от смерти: ${out}`, r >= 10 ? 'a3' : 'a0');
    live(render); markFates(prev); const o = $('#fateOut'); if (o) { o.textContent = out; replay(o, 'pop'); }
  });
}

/* ---------- sheets: hit points ---------- */
function hpSheet(mode){
  let m = mode === 'temp' ? 'temp' : mode === 'heal' ? 'heal' : 'dmg', val = '', type = 'none';
  const typesHTML = () => `<div class="types" id="types">${DTYPES.map(([k, n, a]) => `<button type="button" class="ty" data-t="${k}" aria-pressed="${k === type}" style="--acc:var(--a${a})"><i></i>${n}</button>`).join('')}</div>`;
  openSheet(`<span class="bs-kicker">${H.name}</span>${segHTML([['dmg','Урон'],['heal','Лечение'],['temp','Врем. ОЗ']], m, 'hpSeg')}
    <div id="hpDyn"></div><div class="kp-val num" id="kpVal">${odo(0, 'kp')}</div>
    <div class="quick">${[1,5,10].map(q => `<button type="button" data-q="${q}">+${q}</button>`).join('')}</div>
    <div class="kp">${[1,2,3,4,5,6,7,8,9,'x',0,'00'].map(k => `<button type="button" data-k="${k}">${k === 'x' ? icon('back') : k}</button>`).join('')}</div>
    <button type="button" class="btn primary wide" id="hpGo" style="height:56px" disabled></button>`, {onOpen(sh, close){
      const n = () => +val || 0;
      const draw = () => {
        const v = n(); let to = H.hp, temp = H.temp, note = '';
        if (m === 'dmg') { const eff = resisting(type) ? Math.floor(v / 2) : v; const ft = Math.min(temp, eff); temp -= ft; to = Math.max(0, H.hp - (eff - ft));
          note = `${ft ? `Щит снимет ${ft}. ` : ''}${to === 0 && H.hp > 0 ? 'Герой упадёт без сознания.' : ''}${H.hp === 0 ? 'Без сознания: это провал спасброска.' : ''}`; }
        if (m === 'heal') to = Math.min(H.max, H.hp + v);
        if (m === 'temp') temp = Math.max(temp, v);
        $('#hpDyn', sh).innerHTML = `<div class="prev"><div class="row"><span class="from num">${H.hp}${H.temp ? ` +${H.temp}` : ''}</span>${icon('fwd')}<span class="to num" style="color:${m === 'dmg' ? 'var(--primary)' : m === 'heal' ? 'var(--heal)' : 'var(--a4)'}">${to}${temp ? ` +${temp}` : ''}</span><span class="muted" style="margin-left:auto;font-size:13px">из ${H.max}</span></div>
          <div class="bar"><i class="fill" style="width:${to / H.max * 100}%;background:${m === 'heal' ? 'var(--heal)' : ''}"></i>${temp ? `<i class="shield" style="left:calc(${to / H.max * 100}% - ${Math.min(to / H.max, temp / H.max) * 100}%);width:${temp / H.max * 100}%"></i>` : ''}</div>
          ${note ? `<small>${note}</small>` : ''}</div>
          ${m === 'dmg' ? typesHTML() : ''}
          ${m === 'dmg' && resisting(type) ? `<div class="resist">${icon('axe')}<span><b>Ярость:</b> сопротивление — урон вдвое меньше (${Math.floor(v / 2)})</span></div>` : ''}
          ${m === 'dmg' && H.conc && v ? `<div class="note">${icon('timer')}<span>Концентрация «${H.conc}»: спасбросок Сл ${Math.max(10, Math.floor((resisting(type) ? Math.floor(v / 2) : v) / 2))}</span></div>` : ''}
          ${m === 'temp' && H.temp && v && v <= H.temp ? `<div class="note">${icon('shield')}<span>Временные ОЗ не складываются: останутся ${H.temp}</span></div>` : ''}`;
        $$('.ty', sh).forEach(b => b.addEventListener('click', () => { type = b.dataset.t; buzz.tick(); draw(); }));
        setOdo($('#kpVal .odo', sh), v);
        const go = $('#hpGo', sh); go.disabled = !v;
        go.textContent = m === 'dmg' ? `Получить ${v || ''} урона` : m === 'heal' ? `Вылечить ${v || ''}` : `Дать ${v || ''} временных`;
        go.style.background = m === 'dmg' ? 'var(--primary)' : m === 'heal' ? 'var(--heal)' : 'var(--a4)';
      };
      segment($('#hpSeg', sh), b => { m = b.dataset.v; draw(); });
      $$('.kp button', sh).forEach(b => b.addEventListener('click', () => { const k = b.dataset.k; buzz.tick(); if (k === 'x') val = val.slice(0, -1); else if (val.length < 4) val = (val + k).replace(/^0+/, ''); draw(); }));
      $$('.quick button', sh).forEach(b => b.addEventListener('click', () => { val = String(n() + +b.dataset.q); buzz.tick(); draw(); }));
      $('#hpGo', sh).addEventListener('click', () => { const v = n(); close(0, () => m === 'dmg' ? damage(v, type) : m === 'heal' ? heal(v) : giveTemp(v)); });
      draw();
    }});
}

/* ---------- sheets: conditions and exhaustion ---------- */
function condSheet(){
  // Exhaustion climbs a stair: yellow, then orange, then red, then death.
  const exhC = i => i === 0 ? 'var(--heal)' : i <= 2 ? 'var(--a2)' : i <= 4 ? 'var(--a1)' : 'var(--a0)';
  openSheet(`<span class="bs-kicker">${H.name}</span><h2 class="bs-title">Состояния</h2><p class="bs-sub">Коснитесь печати — наложить или снять. Удержание — полное правило.</p>
    <div class="cgrid">${CONDS.map(([k, n, ic, a, t]) => `<button type="button" class="cnd" data-c="${k}" aria-pressed="${H.conds.includes(k)}" style="--acc:var(--a${a})" data-peek="${n}|${t}"><span class="ch"><span class="ci">${icon(ic)}</span><span class="ck">${icon('check')}</span></span><b>${n}</b><small>${t}</small></button>`).join('')}</div>
    <div class="exh" id="exh"><div class="exh-h"><span class="cap">Истощение</span><span class="exh-big num" id="exhBig"></span></div>
      <div class="stairs">${[0,1,2,3,4,5,6].map(i => `<button type="button" data-x="${i}" style="--k:${i};--c:${exhC(i)}" aria-label="Истощение ${i}"><span class="col"><i></i></span><span class="sn">${i === 6 ? icon('skull') : i}</span></button>`).join('')}</div>
      <div class="exh-now" id="exhNow"></div>
      <div class="exh-eff" id="exhEff"></div></div>
    <button type="button" class="btn primary wide" data-close style="height:52px">Готово</button>`, {onOpen(sh, close){
      const eff = (bump) => {
        const x = H.exh;
        $('#exh', sh).style.setProperty('--c', exhC(x));
        $('#exhBig', sh).innerHTML = `${x}<small> из 6</small>`;
        $('#exhNow', sh).innerHTML = x ? `<b>${EXH[x]}</b>${x > 1 ? `<small>и всё, что ниже по лестнице</small>` : ''}` : `<b>Без истощения</b><small>Длительный отдых снимает одну ступень</small>`;
        $('#exhEff', sh).innerHTML = EXH.slice(1, 6).map((t, i) => `<div class="${i + 1 <= x ? 'on' : ''}" style="--c:${exhC(i + 1)}"><i>${i + 1}</i>${t}</div>`).join('');
        $$('.stairs button', sh).forEach(b => { const i = +b.dataset.x; b.classList.toggle('on', i > 0 && i <= x); b.classList.toggle('cur', i === x); b.setAttribute('aria-pressed', i === x); });
        if (bump) replay($(`.stairs button[data-x="${x}"]`, sh), 'bump');
      };
      eff();
      $$('.cnd', sh).forEach(b => b.addEventListener('click', () => { snap(); const k = b.dataset.c, on = H.conds.includes(k);
        H.conds = on ? H.conds.filter(x => x !== k) : [...H.conds, k]; b.setAttribute('aria-pressed', !on); on ? buzz.tick() : (buzz.light(), replay(b, 'seal'));
        log(`${on ? 'Снято' : 'Наложено'}: ${CONDS.find(c => c[0] === k)[1]}`, 'a' + CONDS.find(c => c[0] === k)[3]); }));
      $$('.stairs button', sh).forEach(b => b.addEventListener('click', () => { const x = +b.dataset.x; if (x === H.exh) return; snap(); H.exh = x; x === 6 ? buzz.medium() : buzz.tick(); eff(true); log(`Истощение ${H.exh}`, 'a1'); }));
      $('[data-close]', sh).addEventListener('click', () => close());
    }, onClose(){ live(render); $$('.seal:not(.add)').forEach(s => replay(s, 'stamp')); }});
}

/* ---------- sheets: rest ---------- */
function restSheet(kind){
  let k = kind, rolls = [], preview = H.hp;
  const stars = Array.from({length:22}, () => `<i style="left:${Math.random() * 100}%;top:${Math.random() * 70}%;animation-delay:${Math.random() * 3}s"></i>`).join('');
  openSheet(`<div class="rest-h ${k}" id="restH"><div class="sky">${stars}</div><i class="orb"></i><span class="cap" id="rCap">Привал</span><h2 id="rTitle"></h2><p id="rSub"></p>${segHTML([['short','Короткий'],['long','Длительный']], k, 'rSeg')}</div>
    <div id="rBody" style="display:flex;flex-direction:column;gap:12px"></div>`, {onOpen(sh, close){
      const gainRow = (ic, acc, n, from, to, max) => `<div class="gain ${from >= to ? 'none' : ''}" style="--acc:var(--${acc})"><span class="gi">${icon(ic)}</span><b>${n}</b><span class="num">${from === Infinity ? '∞' : from} → <em>${to === Infinity ? '∞' : to}</em>${max ? ` / ${max}` : ''}</span></div>`;
      const draw = () => {
        $('#restH', sh).className = `rest-h ${k}`;
        $('#rTitle', sh).textContent = k === 'short' ? 'Короткий отдых' : 'Длительный отдых';
        $('#rSub', sh).textContent = k === 'short' ? 'Час передышки. Бросьте кости хитов — лечение сразу ляжет в ОЗ.' : 'Восемь часов сна. Утром — полные ОЗ, ячейки и умения.';
        const shortRes = H.res.filter(r => r.rest === 'short'), all = H.res;
        if (k === 'short') {
          const left = H.hdLeft - rolls.length, shown = Math.min(left, 10);
          $('#rBody', sh).innerHTML = `<div class="prev"><div class="row"><span class="from num">${H.hp}</span>${icon('fwd')}<span class="to num" style="color:var(--heal)">${odo(preview, 'rprev')}</span><span class="muted" style="margin-left:auto;font-size:13px">из ${H.max}</span></div>
              <div class="bar"><i class="fill" style="width:${preview / H.max * 100}%;background:var(--heal)"></i></div>${rolls.length ? `<small>${rolls.map(r => `${r}+${H.con}`).join(' · ')}</small>` : '<small>Каждая кость — к' + H.hd.d + ' + Телосложение (' + fmt(H.con) + ')</small>'}</div>
            <div class="hdtray" style="--acc:var(--a${HEROES.find(h => h.id === H.id).acc})"><div class="hd-h"><b>Кости хитов · к${H.hd.d}</b><span class="num">${left} из ${H.hd.max}</span></div>
              <div class="hddice">${Array.from({length:shown}, (_, i) => `<button type="button" class="hdd" data-a="hd" aria-label="Бросить кость хитов">${HEX}<b>к${H.hd.d}</b></button>`).join('')}${left > shown ? `<span class="hdd more">+${left - shown}</span>` : ''}${rolls.map(r => `<span class="hdd used">${HEX}<b>${r}</b></span>`).join('')}</div></div>
            <span class="cap">Вернётся</span><div class="gains">${shortRes.length ? shortRes.map(r => gainRow(r.ic, 'a' + r.acc, r.n, r.left, r.max)).join('') : '<div class="gain none"><b>Умений короткого отдыха нет</b></div>'}</div>
            <button type="button" class="btn primary wide" id="rGo" style="height:56px">${icon('cup')} Завершить привал${rolls.length ? ` · +${preview - H.hp} ОЗ` : ''}</button>`;
          $$('[data-a="hd"]', sh).forEach(b => b.addEventListener('click', () => { const r = 1 + Math.floor(Math.random() * H.hd.d);
            tumble([b], [r], H.hd.d, () => { rolls.push(r); preview = Math.min(H.max, preview + r + H.con); buzz.light(); floatUp(b, `+${r + H.con}`, 'var(--heal)'); draw(); }); }));
          $('#rGo', sh).addEventListener('click', () => { snap(); H.hp = preview; H.hdLeft -= rolls.length; H.res.forEach(r => { if (r.rest === 'short' && r.max !== Infinity) r.left = r.max; });
            $$('.gain', sh).forEach((g, i) => setTimeout(() => replay(g, 'wave'), i * 70)); buzz.medium();
            setTimeout(() => close(0, () => { live(render); toast(`Короткий отдых: +${rolls.length ? preview - (H.hp - 0) : 0} · ресурсы восстановлены`); }), reduced ? 0 : 420); log('Короткий отдых', 'a1'); });
        } else {
          const back = Math.max(1, Math.floor(H.hd.max / 2));
          $('#rBody', sh).innerHTML = `<div class="gains">
              ${gainRow('heart', 'a0', 'Хиты', H.hp, H.max)}${H.temp ? gainRow('shield', 'a4', 'Временные ОЗ спадут', H.temp, 0) : ''}
              ${gainRow('dice', 'a1', 'Кости хитов · половина', H.hdLeft, Math.min(H.hd.max, H.hdLeft + back), H.hd.max)}
              ${H.slots.length ? gainRow('magic', 'a4', 'Ячейки заклинаний', H.slotsLeft.reduce((a, b) => a + b, 0), H.slots.reduce((a, b) => a + b, 0)) : ''}
              ${all.map(r => gainRow(r.ic, 'a' + r.acc, r.n, r.left, r.max)).join('')}
              ${H.exh ? gainRow('timer', 'a1', 'Истощение', H.exh, H.exh - 1) : ''}
              ${H.conc ? `<div class="gain" style="--acc:var(--a5)"><span class="gi">${icon('timer')}</span><b>Концентрация «${H.conc}» закончится</b></div>` : ''}</div>
            <button type="button" class="holdbtn" id="rHold"><i></i><span>${icon('moon')} Удерживайте — до рассвета</span></button>`;
          const hb = $('#rHold', sh), fill = $('i', hb); let t0 = 0, raf = 0, done = false;
          const step = now => { const p = clamp((now - t0) / 1100, 0, 1); fill.style.width = p * 100 + '%'; if (p > .33 && !hb.t1) { hb.t1 = 1; buzz.tick(); } if (p > .66 && !hb.t2) { hb.t2 = 1; buzz.tick(); }
            if (p >= 1) { done = true; finish(); return; } raf = requestAnimationFrame(step); };
          hb.addEventListener('pointerdown', e => { if (done) return; hb.setPointerCapture(e.pointerId); t0 = performance.now(); hb.t1 = hb.t2 = 0; raf = requestAnimationFrame(step); });
          const cancel = () => { if (done) return; cancelAnimationFrame(raf); fill.style.transition = 'width 300ms var(--e-snappy)'; fill.style.width = '0'; setTimeout(() => fill.style.transition = '', 320); };
          hb.addEventListener('pointerup', cancel); hb.addEventListener('pointercancel', cancel);
          const finish = () => { snap(); hb.classList.add('done'); $('span', hb).innerHTML = `${icon('sun')} Рассвет`; buzz.medium();
            H.hp = H.max; H.temp = 0; H.hdLeft = Math.min(H.hd.max, H.hdLeft + back); H.slotsLeft = [...H.slots]; H.res.forEach(r => { if (r.max !== Infinity) r.left = r.max; });
            if (H.exh) H.exh--; H.conc = null; C.effects = C.effects.filter(e => !e.conc); H.ds = {s:0, f:0, stable:false, dead:false};
            $('#restH', sh).className = 'rest-h short';
            $$('.gain', sh).forEach((g, i) => setTimeout(() => replay(g, 'wave'), i * 80));
            log('Длительный отдых', 'a5');
            setTimeout(() => close(0, () => { live(render); toast('Утро: всё восстановлено'); }), reduced ? 0 : 900); };
        }
      };
      segment($('#rSeg', sh), b => { k = b.dataset.v; rolls = []; preview = H.hp; draw(); });
      draw();
    }});
}

/* ---------- sheets: the game state console ---------- */
function consoleSheet(){
  const rows = [
    ['hp', 'heart', 'a0', 'Текущие ОЗ', 'Норма — максимум; выше — переполнение', () => H.hp, v => H.hp = Math.max(0, v), 1],
    ['max', 'heart', 'a0', 'Максимум ОЗ', 'Обычно считается от уровня и Телосложения', () => H.max, v => H.max = Math.max(1, v), 1],
    ['temp', 'shield', 'a4', 'Временные ОЗ', 'Снимаются уроном первыми', () => H.temp, v => H.temp = Math.max(0, v), 1],
    ['ac', 'shield', 'a4', 'Класс доспеха', 'Вручную поверх расчёта из снаряжения', () => H.ac, v => H.ac = clamp(v, 0, 40), 1],
    ['speed', 'run', 'a3', 'Скорость', 'Футы за ход', () => H.speed, v => H.speed = clamp(v, 0, 120), 5],
    ['hd', 'dice', 'a1', `Кости хитов · к${H.hd.d}`, `Из ${H.hd.max}`, () => H.hdLeft, v => H.hdLeft = clamp(v, 0, H.hd.max), 1],
    ['exh', 'timer', 'a1', 'Истощение', 'От 0 до 6', () => H.exh, v => H.exh = clamp(v, 0, 6), 1],
  ];
  openSheet(`<span class="bs-kicker">${H.name}</span><h2 class="bs-title">Игровые параметры</h2><p class="bs-sub">Тяните число вбок — оно крутится; коснитесь, чтобы ввести.</p>
    <div class="dials">${rows.map(([k, ic, a, n, s, get]) => `<div class="dial" data-k="${k}" style="--acc:var(--${a})"><span class="di">${icon(ic)}</span><span class="dl"><b>${n}</b><small>${s}</small></span>${k === 'hp' ? `<span class="over" id="over" ${H.hp > H.max ? '' : 'hidden'}>выше нормы</span>` : ''}<span class="dv"><span class="num">${odo(get(), 'c-' + k)}</span><span class="rail">${'<i></i>'.repeat(9)}</span></span></div>`).join('')}</div>
    <button type="button" class="btn primary wide" data-close style="height:52px">Готово</button>`, {onOpen(sh, close){
      rows.forEach(([k, , , n, , get, set, step]) => {
        const row = $(`.dial[data-k="${k}"]`, sh), dv = $('.dv', row); let d = null;
        dv.addEventListener('pointerdown', e => { d = {x0:e.clientX, v0:get(), moved:false}; dv.setPointerCapture(e.pointerId); row.classList.add('active'); });
        dv.addEventListener('pointermove', e => { if (!d) return; const steps = Math.trunc((e.clientX - d.x0) / 9); if (Math.abs(e.clientX - d.x0) > 4) d.moved = true;
          const v = d.v0 + steps * step; if (v !== get()) { set(v); buzz.tick(); setOdo($('.odo', dv), get()); const o = $('#over', sh); if (o) o.hidden = !(H.hp > H.max); } });
        const end = () => { if (!d) return; row.classList.remove('active'); const tap = !d.moved; d = null;
          if (tap) keypadSheet({kicker:H.name, title:n, onDone(v){ snap(); set(v); live(render); consoleSheet(); }}); else { live(render); } };
        dv.addEventListener('pointerup', end); dv.addEventListener('pointercancel', end);
      });
      $('[data-close]', sh).addEventListener('click', () => close());
    }, onClose(){ live(render); }});
}

/* ---------- sheets: movement on a ruler ---------- */
function moveSheet(){
  let rough = false;
  snap();
  openSheet(`<span class="bs-kicker">${H.name}</span><h2 class="bs-title">Движение</h2>
    <div class="mv-top"><span class="mv-left num" id="mvLeft"></span><span class="mv-of" id="mvOf"></span></div>
    <div class="ruler" id="ruler"><div class="track"><i class="used"></i><i class="dashz"></i></div><div class="ticks" id="ticks"></div><span class="thumb"><span class="tl num"></span></span></div>
    <div class="mv-q">${[5, 10, 15, 30].map(q => `<button type="button" data-q="${q}">+${q}</button>`).join('')}<button type="button" data-q="-5" aria-label="Вернуть 5 футов">${icon('back')}</button></div>
    <div class="mv-opts"><button type="button" class="mvo" id="mvDash" aria-pressed="${C.dash}" style="--acc:var(--a1)"><span class="mi">${icon('dash')}</span><span><b>Рывок</b><small>Скорость ×2 · тратит действие</small></span></button>
      <button type="button" class="mvo" id="mvRough" aria-pressed="false" style="--acc:var(--a2)"><span class="mi">${icon('peaks')}</span><span><b>Трудная местность</b><small>Каждый шаг стоит вдвое</small></span></button></div>
    <div class="mv-acts"><button type="button" class="btn" id="mvReset">${icon('back')} Сначала</button><button type="button" class="btn primary" data-close style="flex:1">Готово</button></div>`, {onOpen(sh, close){
      const ruler = $('#ruler', sh), track = $('.track', ruler);
      const draw = () => {
        const B = budget(), left = Math.max(0, B - C.moved), p = Math.min(1, C.moved / B);
        $('#mvLeft', sh).innerHTML = `${odo(left, 'mvleft')}<small> фт.</small>`;
        $('#mvOf', sh).textContent = `осталось из ${B}${C.dash ? ' · с Рывком' : ''}`;
        $('.used', ruler).style.width = p * 100 + '%';
        $('.dashz', ruler).style.left = C.dash ? '50%' : '100%';
        $('.thumb', ruler).style.left = p * 100 + '%'; $('.tl', ruler).textContent = C.moved;
        $('#ticks', sh).innerHTML = Array.from({length:B / 5 + 1}, (_, i) => `<i class="${i * 5 <= C.moved ? 'on' : ''} ${i * 5 % (B > 60 ? 20 : 10) === 0 ? 'big' : ''}" style="left:${i * 5 / B * 100}%">${i * 5 % (B > 60 ? 20 : 10) === 0 ? `<span>${i * 5}</span>` : ''}</i>`).join('');
        $('#mvDash', sh).setAttribute('aria-pressed', C.dash);
      };
      const setMoved = v => { const nv = clamp(Math.round(v / 5) * 5, 0, budget()); if (nv === C.moved) return; if (Math.floor(nv / 5) !== Math.floor(C.moved / 5)) buzz.tick(); C.moved = nv; if (nv === budget()) buzz.light(); draw(); };
      let d = null;
      ruler.addEventListener('pointerdown', e => { d = true; ruler.setPointerCapture(e.pointerId); ruler.classList.add('drag'); at(e); });
      const at = e => { const r = track.getBoundingClientRect(); setMoved((e.clientX - r.left) / r.width * budget()); };
      ruler.addEventListener('pointermove', e => { if (d) at(e); });
      ['pointerup', 'pointercancel'].forEach(k => ruler.addEventListener(k, () => { d = null; ruler.classList.remove('drag'); }));
      $$('.mv-q button', sh).forEach(b => b.addEventListener('click', () => { const q = +b.dataset.q; setMoved(C.moved + q * (rough && q > 0 ? 2 : 1)); replay($('.thumb', ruler), 'nudge'); }));
      $('#mvDash', sh).addEventListener('click', () => { C.dash = !C.dash; if (C.dash) { C.used.act = true; log('Рывок · действие', 'a1'); } else C.moved = Math.min(C.moved, budget()); buzz.light(); draw(); });
      $('#mvRough', sh).addEventListener('click', e => { rough = !rough; e.currentTarget.setAttribute('aria-pressed', rough); buzz.tick(); });
      $('#mvReset', sh).addEventListener('click', () => { setMoved(0); buzz.light(); });
      $('[data-close]', sh).addEventListener('click', () => close());
      draw();
    }, onClose(){ live(render); replay($('.tok.move'), 'flash'); }});
}

/* ---------- sheets: the dice tray ---------- */
// Every die has its own silhouette and its own colour, in the tray and
// on the picker alike.
const DS = [4, 6, 8, 10, 12, 20, 100];
const DACC = {4:'var(--a2)', 6:'var(--a1)', 8:'var(--a3)', 10:'var(--a4)', 12:'var(--a5)', 20:'var(--a0)', 100:'var(--secondary)'};
const K10 = '50,4 95,44 95,56 50,96 5,56 5,44';
const DSH = {
  4:'<polygon class="face" points="50,6 95,88 5,88"/><polyline class="fac" points="5,88 50,64 95,88"/><polyline class="fac" points="50,6 50,64"/>',
  6:'<rect class="face" x="10" y="10" width="80" height="80" rx="17"/><rect class="fac" x="24" y="24" width="52" height="52" rx="9"/>',
  8:'<polygon class="face" points="50,4 95,50 50,96 5,50"/><polyline class="fac" points="5,50 50,36 95,50"/><polyline class="fac" points="50,4 50,36"/>',
  10:`<polygon class="face" points="${K10}"/><polyline class="fac" points="5,44 28,58 50,44 72,58 95,44"/><polyline class="fac" points="28,58 50,96 72,58"/>`,
  12:'<polygon class="face" points="50,5 94,37 77,90 23,90 6,37"/><polygon class="fac" points="50,30 70,44 62,67 38,67 30,44"/><path class="fac" d="M50 5V30M94 37 70 44M77 90 62 67M23 90 38 67M6 37 30 44"/>',
  20:'<polygon class="face" points="50,4 92,28 92,72 50,96 8,72 8,28"/><polygon class="fac" points="50,26 74,66 26,66"/><path class="fac" d="M50 4 50 26M92 28 74 66M8 28 26 66M50 96 26 66M50 96 74 66"/>',
  100:`<polygon class="face back" points="${K10}" transform="translate(16 -8) scale(.84)"/><polygon class="face" points="${K10}" transform="translate(-4 6) scale(.92)"/>`};
const dieN = (s, val, {tag = 'span', attrs = '', cls = ''} = {}) => `<${tag} ${tag === 'button' ? 'type="button"' : ''} class="die2 dd d${s} ${cls}" style="--acc:${DACC[s]}" ${attrs}><svg viewBox="0 0 100 100" aria-hidden="true">${DSH[s]}</svg><b>${val}</b></${tag}>`;
// A throw: dice drop in spinning, slow down, bounce once and settle; faces
// flicker slower and slower, each die lands with its own tick.
function throwDice(els, finals, sides, done){
  if (reduced) { els.forEach((el, i) => $('b', el).textContent = finals[i]); return done(); }
  let landed = 0;
  els.forEach((el, i) => {
    const delay = i * 70, dur = 1050, t0 = performance.now() + delay; let last = 0;
    el.classList.remove('landed2', 'nat20', 'nat1'); el.style.animationDelay = delay + 'ms'; replay(el, 'thrown');
    const step = now => { const p = (now - t0) / dur;
      if (p >= 1) { $('b', el).textContent = finals[i]; el.classList.remove('thrown'); replay(el, 'landed2'); buzz.tick(); if (++landed === els.length) setTimeout(done, 180); return; }
      if (p > 0 && now - last > 40 + p * p * 220) { last = now; $('b', el).textContent = 1 + Math.floor(Math.random() * sides[i]); }
      requestAnimationFrame(step); };
    requestAnimationFrame(step);
  });
}
function sparks(host, el, color){
  if (reduced) return;
  const hr = host.getBoundingClientRect(), r = el.getBoundingClientRect(), cx = r.left + r.width / 2 - hr.left, cy = r.top + r.height / 2 - hr.top;
  for (let k = 0; k < 14; k++) { const s = document.createElement('i'); s.className = 'spark'; s.style.cssText = `left:${cx}px;top:${cy}px;background:${color}`; host.appendChild(s);
    const a = k / 14 * Math.PI * 2 + Math.random() * .3, d = 60 + Math.random() * 50;
    s.animate([{transform:'translate(-50%,-50%) scale(1)', opacity:1}, {transform:`translate(calc(-50% + ${Math.cos(a) * d}px), calc(-50% + ${Math.sin(a) * d}px)) scale(.2)`, opacity:0}], {duration:700 + Math.random() * 300, easing:'cubic-bezier(.1,.7,.2,1)'}).onfinish = () => s.remove(); }
}
let tray = [], diceHist = [];
function diceSheet(){
  let mod = 0, adv = 'none';
  openSheet(`<span class="bs-kicker">${H.name}</span><h2 class="bs-title">Лоток костей</h2>
    <div class="dpick">${DS.map(s => `<button type="button" data-s="${s}" style="--acc:${DACC[s]}" aria-label="Положить к${s}">${dieN(s, '')}<span>к${s}</span><em class="cnt" hidden></em></button>`).join('')}</div>
    <div class="tray" id="tray"></div>
    <div class="advseg">${segHTML([['dis','Помеха'],['none','Обычно'],['adv','Преимущество']], adv, 'advSeg')}</div>
    <div class="stp2"><span>Модификатор</span><div class="sg"><button type="button" data-d="-1" aria-label="Меньше">${icon('minus')}</button><span class="num sv">${odo('+0', 'dmod')}</span><button type="button" data-d="1" aria-label="Больше">${icon('plus')}</button></div></div>
    <div class="total" id="dTotal" hidden><span class="tv num" id="dTot"></span><div class="tb"><span id="dBr"></span><span id="dFlag"></span></div></div>
    <button type="button" class="btn primary wide" id="dGo" style="height:56px">${icon('dice')} Бросить</button>
    <div class="hist" id="dHist"></div>`, {onOpen(sh){
      const drawHist = () => $('#dHist', sh).innerHTML = diceHist.map(h => `<span>${h.f} = <b>${h.t}</b></span>`).join('');
      const drawTray = () => {
        $('#tray', sh).dataset.n = Math.min(tray.length, 5);
        $('#tray', sh).innerHTML = tray.length ? tray.map((t, i) => dieN(t.s, t.v ?? 'к' + t.s, {tag:'button', attrs:`data-i="${i}" aria-label="Убрать"`, cls:(t.drop ? 'drop ' : '') + (t.nat || '')})).join('') : '<span class="empty">Коснитесь кости выше — она ляжет в лоток. Касание кости в лотке убирает её</span>';
        $$('#tray .die2', sh).forEach(b => b.addEventListener('click', () => { tray.splice(+b.dataset.i, 1); buzz.tick(); drawTray(); }));
        $$('.dpick button', sh).forEach(b => { const n = tray.filter(t => t.s === +b.dataset.s && !t.twin).length, c = $('.cnt', b); c.hidden = !n; c.textContent = '×' + n; });
      };
      $$('.dpick button', sh).forEach(b => b.addEventListener('click', () => { if (tray.length >= 8) return toast('Не больше восьми костей'); tray = tray.filter(t => !t.twin).map(t => ({s:t.s})); tray.push({s:+b.dataset.s}); buzz.tick(); drawTray(); replay($('#tray .die2:last-child', sh), 'dropin'); replay(b, 'picked'); }));
      segment($('#advSeg', sh), b => { adv = b.dataset.v; });
      $$('.stp2 button', sh).forEach(b => stepper(b, d => { mod = clamp(mod + d, -20, 30); setOdo($('[data-odo="dmod"]', sh), fmt(mod)); }));
      $('#dGo', sh).addEventListener('click', () => {
        if (!tray.length) tray.push({s:20});
        tray = tray.filter(t => !t.twin).map(t => ({s:t.s}));
        if (adv !== 'none') { const i = tray.findIndex(t => t.s === 20); if (i >= 0) tray.splice(i + 1, 0, {s:20, twin:true}); else tray.unshift({s:20}, {s:20, twin:true}); }
        drawTray(); $('#dTotal', sh).classList.add('dim');
        const vals = tray.map((t, i) => t.s === 20 && i === tray.findIndex(x => x.s === 20) ? d20() : 1 + Math.floor(Math.random() * t.s));
        throwDice($$('#tray .die2', sh), vals, tray.map(t => t.s), () => {
          tray.forEach((t, i) => t.v = vals[i]);
          if (adv !== 'none') { const idx = tray.map((t, i) => t.s === 20 ? i : -1).filter(i => i >= 0).slice(0, 2); const [a, b] = idx; if (b !== undefined) { const keepA = adv === 'adv' ? vals[a] >= vals[b] : vals[a] <= vals[b]; tray[keepA ? b : a].drop = true; } }
          tray.forEach(t => { if (t.s === 20 && !t.drop) t.nat = t.v === 20 ? 'nat20' : t.v === 1 ? 'nat1' : ''; });
          const kept = tray.filter(t => !t.drop), total = kept.reduce((a, t) => a + t.v, 0) + mod;
          const crit = kept.some(t => t.nat === 'nat20'), fumble = kept.some(t => t.nat === 'nat1');
          drawTray();
          const box = $('#dTotal', sh); box.hidden = false; box.classList.remove('dim'); box.classList.toggle('crit', crit); box.classList.toggle('fumble', fumble && !crit);
          $('#dTot', sh).innerHTML = odo(total, 'dtot'); const o = $('#dTot .odo', sh);
          if (!reduced) { spinTo(o, digits(total).map(() => 0), digits(total)); replay(box, 'reveal'); }
          $('#dBr', sh).innerHTML = kept.map(t => `<span class="dk" style="--acc:${DACC[t.s]}">к${t.s}<b>${t.v}</b></span>`).join('<i>+</i>') + (mod ? `<i>${mod > 0 ? '+' : '−'}</i><span class="dk mod">мод<b>${Math.abs(mod)}</b></span>` : '');
          $('#dFlag', sh).innerHTML = crit ? `<span class="flag gold">${icon('star')} Критический успех</span>` : fumble ? `<span class="flag red">${icon('skull')} Критический провал</span>` : '';
          const t = $('#tray', sh);
          if (crit) { buzz.medium(); setTimeout(buzz.medium, 140); replay(t, 'gold'); $$('#tray .nat20', sh).forEach(el => sparks(t, el, 'var(--a2)')); }
          if (fumble && !crit) { buzz.medium(); replay(t, 'shake'); }
          diceHist.unshift({f:kept.map(t => 'к' + t.s).join('+') + (mod ? fmt(mod) : ''), t:total}); if (diceHist.length > 10) diceHist.pop(); drawHist();
          if (scene === 'combat') log(`Бросок ${diceHist[0].f} = ${total}`, crit ? 'a2' : 'a5');
        });
      });
      drawTray(); drawHist();
    }, onClose(){ if (scene === 'combat') live(render); }});
}

/* ---------- armor class ---------- */
function acSheet(){
  const parts = H.id === 'wizard' ? [['Без доспеха', 10, 'person'], ['Ловкость', 2, 'run']] : H.id === 'rogue' ? [['Кожаный доспех', 11, 'shield'], ['Ловкость', 5, 'run']] : [['Кольчуга', 16, 'shield'], ['Щит', 2, 'shield'], ['Стиль «Оборона»', 1, 'sword']];
  const n = parts.length;
  openSheet(`<span class="bs-kicker">${H.name}</span><h2 class="bs-title">Класс доспеха</h2><p class="bs-sub">Слои ложатся снизу вверх и сходятся в щит.</p>
    <div class="acstack">
      <div class="acshield" style="animation:stamp 520ms ${n * 110}ms var(--e-snappy) both"><svg viewBox="0 0 100 112"><path d="${SHIELD}"/></svg><b class="num">${H.ac}</b><span>КД</span></div>
      ${parts.map(([nm, v, ic], i) => `<div class="acplate" style="--w:${100 - i * 9}%;--acc:var(--a${[4, 3, 2][i] ?? 4});animation:rise 460ms ${i * 110}ms var(--e-snappy) both"><span class="bic">${icon(ic)}</span><b>${nm}</b><span class="num">${i ? '+' : ''}${v}</span></div>`).reverse().join('')}
    </div>
    <button type="button" class="btn wide" data-a2="pin" style="height:50px">Закрепить вручную</button>`, {onOpen(sh, close){ $('[data-a2="pin"]', sh).addEventListener('click', () => close(0, consoleSheet)); }});
}

/* ---------- log ---------- */
function logSheet(){
  openSheet(`<span class="bs-kicker">${H.name}</span><h2 class="bs-title">Журнал боя</h2>
    <div class="blist">${C.log.map(l => `<div class="brow2"><span class="lg" style="--acc:var(--${l.acc});background:none;padding:0"><i></i></span><span class="ft"><b style="font-weight:500">${l.t}</b></span></div>`).join('') || '<p class="muted">Пока пусто</p>'}</div>
    <button type="button" class="btn wide" data-u style="height:50px">${icon('back')} Отменить последнее</button>`, {onOpen(sh, close){ $('[data-u]', sh).addEventListener('click', () => close(0, undo)); }});
}

/* ---------- actions ---------- */
document.addEventListener('click', e => {
  const t = e.target.closest('[data-a]'); if (!t || !t.closest('#app')) return;
  const a = t.dataset.a;
  if (a === 'hpsheet') return hpSheet(t.dataset.m);
  if (a === 'conds') return condSheet();
  if (a === 'rest') return restSheet(t.dataset.r);
  if (a === 'console') return consoleSheet();
  if (a === 'dice') return diceSheet();
  if (a === 'acbreak') return acSheet();
  if (a === 'logs') return logSheet();
  if (a === 'undo') return undo();
  if (a === 'startc') return ceremony();
  if (a === 'next') return nextRound();
  if (a === 'endc') { snap(); scene = 'overview'; const n = C.round; log(`Бой окончен · ${n} ${plural(n, 'раунд', 'раунда', 'раундов')}`, 'a4'); buzz.light(); live(render); return toast(`Бой окончен за ${n} ${plural(n, 'раунд', 'раунда', 'раундов')}`); }
  if (a === 'tok') { snap(); const k = t.dataset.k; C.used[k] = !C.used[k]; buzz.tick(); live(render); return replay($(`.tok[data-k="${k}"]`), 'flash'); }
  if (a === 'move') return moveSheet();
  if (a === 'efend') { const ef = C.effects.find(x => x.k === t.dataset.k); if (!ef) return; snap(); replay(t, 'ending'); buzz.light();
    return setTimeout(() => { C.effects = C.effects.filter(x => x !== ef); if (ef.conc) H.conc = null; log(`${ef.n}: завершено`, 'a' + ef.acc); live(render); }, reduced ? 0 : 380); }
  if (a === 'concroll') { const r = 1 + Math.floor(Math.random() * 20), save = r + H.con + (H.conSave ? H.pb : 0), dc = C.check, ok = r === 20 || (r !== 1 && save >= dc);
    snap(); C.check = null; if (!ok) dropConc(`Концентрация потеряна: ${save} против Сл ${dc}`); else { log(`Концентрация удержана: ${save} против Сл ${dc}`, 'a5'); toast(`Удержано: ${save} против ${dc}`); } buzz.light(); return live(render); }
  if (a === 'concend') { snap(); dropConc('Концентрация прервана'); return live(render); }
  if (a === 'dsroll') return deathSave();
  if (a === 'stabilize') { snap(); H.ds.stable = true; log('Стабилизирован', 'a3'); buzz.light(); return live(render); }
  if (a === 'revive') { snap(); H.hp = 1; H.ds = {s:0, f:0, stable:false, dead:false}; H.conds = H.conds.filter(c => c !== 'unconscious'); log('Возвращён с 1 ОЗ', 'a3'); buzz.medium(); return live(render); }
});
/* ---------- controls panel ---------- */
let palette = 'monokai';
function controls(){
  $('#controls').innerHTML = `<div class="opt"><span class="lbl">Герой</span><div class="heroes">${HEROES.map(h => `<button type="button" data-hero="${h.id}" aria-pressed="${H && H.id === h.id}"><i style="background:var(--a${h.acc})"></i>${h.cls}</button>`).join('')}</div>
      <span class="hint">Плут начинает при смерти — спасброски от смерти.</span></div>
    <div class="opt"><span class="lbl">Сцена</span>${segHTML([['overview','Обзор'],['combat','В бою']], scene, 'scSeg')}</div>
    <div class="opt"><span class="lbl">Следующий к20</span>${segHTML([['rand','Случайно'],['20','Всегда 20'],['1','Всегда 1']], forceD20, 'd20Seg')}<span class="hint">Чтобы посмотреть крит и провал в лотке, атаке и спасброске от смерти.</span></div>
    <div class="opt"><span class="lbl">Палитра</span>${segHTML([['monokai','Monokai'],['dune','Rose of Dune'],['nord','Nord']], palette, 'palSeg')}</div>
    <button type="button" class="toggle" id="redm" aria-checked="${reduced}"><span class="switch"></span>Меньше движения</button>`;
  $$('[data-hero]').forEach(b => b.addEventListener('click', () => { pickHero(b.dataset.hero); controls(); buzz.tick(); }));
  segment($('#scSeg'), b => { scene = b.dataset.v; if (scene === 'combat' && C.init == null) C.init = 12 + H.init; live(render); });
  segment($('#d20Seg'), b => { forceD20 = b.dataset.v; });
  segment($('#palSeg'), b => { palette = b.dataset.v; applyPalette(palette); });
  $('#redm').addEventListener('click', e => { reduced = !reduced; document.body.classList.toggle('reduce', reduced); e.currentTarget.setAttribute('aria-checked', reduced); });
}
