/* ================= The arsenal: magic, attacks and features in combat ================= */
// Combat cannot send the hero away to the Magic tab, so what they cast and
// swing lives right under their turn. Every use pays for itself: the slot,
// the action token, the concentration ribbon on the tape.
const COST = {act:['Д', 'Действие', 'a0'], bonus:['БД', 'Бонусное', 'a1'], react:['Р', 'Реакция', 'a4'], free:['', 'Без действия', 'a3']};
const durText = d => !d ? 'мгновенная' : d <= 10 ? '1 мин.' : d <= 100 ? '10 мин.' : d <= 600 ? '1 ч.' : '8 ч.';
const tgt = n => plural(n, 'цель', 'цели', 'целей');
const ARSENAL = {
  paladin:{ab:'ХАР', dc:19, atk:11, perAction:2, smite:true,
    attacks:[{k:'longsword', n:'Длинный меч +1', ic:'sword', hit:12, dice:[1, 8, 6], type:'рубящий', extra:{n:'Улучшенная кара', dice:[1, 8], type:'излучением'}},
      {k:'javelin', n:'Метательное копьё', ic:'track', hit:11, dice:[1, 6, 5], type:'колющий', note:'30/120 фт.', extra:{n:'Улучшенная кара', dice:[1, 8], type:'излучением'}}],
    spells:[
      {k:'bless', n:'Благословение', l:1, cost:'act', conc:true, dur:10, r:'30 фт.', eff:c => ({v:c + 2, l:`${tgt(c + 2)} · +1к4 к атакам и спасброскам`})},
      {k:'shield-of-faith', n:'Щит веры', l:1, cost:'bonus', conc:true, dur:100, r:'60 фт.', eff:() => ({v:'+2', l:'к КД цели'})},
      {k:'wrathful', n:'Гневная кара', l:1, cost:'bonus', conc:true, dur:10, r:'на себя', eff:() => ({v:'+1к6', l:'психическим при попадании · испуг'})},
      {k:'divine-favor', n:'Божественное благоволение', l:1, cost:'bonus', conc:true, dur:10, r:'на себя', eff:() => ({v:'+1к4', l:'излучением к атакам оружием'})},
      {k:'aid', n:'Подмога', l:2, cost:'act', dur:4800, r:'30 фт.', eff:c => ({v:'+' + 5 * (c - 1), l:'к ОЗ трёх целей'})},
      {k:'crusader', n:'Мантия крестоносца', l:3, cost:'act', conc:true, dur:10, r:'30 фт.', eff:() => ({v:'+1к4', l:'излучением союзникам в 30 фт.'})},
      {k:'banishment', n:'Изгнание', l:4, cost:'act', conc:true, dur:10, r:'60 фт.', save:'ХАР', eff:c => ({v:c - 3, l:tgt(c - 3)})},
      {k:'destructive-wave', n:'Разрушительная волна', l:5, cost:'act', r:'30 фт. вокруг', save:'ТЕЛ', eff:() => ({v:'10к6', l:'звуком и излучением · сбивает с ног', dice:[10, 6, 0]})}],
    feats:[
      {k:'loh', n:'Наложение рук', ic:'hand', cost:'act', res:0, line:'Лечение из запаса касанием', use:'loh'},
      {k:'sense', n:'Божественное чувство', ic:'eye', cost:'act', res:1, line:'Небожители, исчадия и нежить в 60 фт.', use:'spend'},
      {k:'sacred', n:'Священное оружие', ic:'sun', cost:'act', res:2, line:'+5 к атакам оружием и свет · 1 мин.', use:'effect', effect:{k:'sacred', n:'Священное оружие', ic:'sword', acc:2, dur:10}}]},
  barbarian:{perAction:2, brutal:3,
    attacks:[{k:'greataxe', n:'Великий топор', ic:'axe', hit:13, dice:[1, 12, 7], type:'рубящий'}, {k:'handaxe', n:'Ручной топор', ic:'axe', hit:13, dice:[1, 6, 7], type:'рубящий', note:'20/60 фт.'}],
    spells:[],
    feats:[
      {k:'rage', n:'Ярость', ic:'axe', cost:'bonus', res:0, line:'Сопротивление физическому, +4 к урону · 1 мин.', use:'toggle', effect:{k:'rage', n:'Ярость', ic:'axe', acc:0, dur:10, resist:true}},
      {k:'reckless', n:'Безрассудная атака', ic:'bolt', cost:'free', line:'Преимущество на атаки силой — и по вам тоже', use:'reckless'}]},
  wizard:{ab:'ИНТ', dc:19, atk:11, perAction:1,
    attacks:[{k:'staff', n:'Боевой посох', ic:'wand', hit:7, dice:[1, 6, 1], type:'дробящий'}],
    spells:[
      {k:'fire-bolt', n:'Огненный снаряд', l:0, cost:'act', r:'120 фт.', hit:true, eff:() => ({v:'4к10', l:'огнём · атака заклинанием', dice:[4, 10, 0]})},
      {k:'magic-missile', n:'Волшебная стрела', l:1, cost:'act', r:'120 фт.', free:true, eff:c => ({v:c + 2, l:`${plural(c + 2, 'снаряд', 'снаряда', 'снарядов')} по 1к4 + 1 · без промаха`, dice:[c + 2, 4, c + 2]})},
      {k:'shield', n:'Щит', l:1, cost:'react', r:'на себя', free:true, eff:() => ({v:'+5', l:'КД до начала вашего хода'})},
      {k:'misty-step', n:'Туманный шаг', l:2, cost:'bonus', r:'на себя', eff:() => ({v:'30 фт.', l:'телепортация в видимое место'})},
      {k:'fireball', n:'Огненный шар', l:3, cost:'act', r:'150 фт.', save:'ЛОВ', eff:c => ({v:`${c + 5}к6`, l:'огнём в сфере 20 фт.', dice:[c + 5, 6, 0]})},
      {k:'counterspell', n:'Контрзаклинание', l:3, cost:'react', r:'60 фт.', eff:c => ({v:`≤ ${c}`, l:'круг прерывается без проверки'})},
      {k:'haste', n:'Ускорение', l:3, cost:'act', conc:true, dur:10, r:'30 фт.', eff:() => ({v:'×2', l:'скорость · +2 КД · ещё действие'})},
      {k:'wall-of-force', n:'Силовая стена', l:5, cost:'act', conc:true, dur:100, r:'120 фт.', eff:() => ({v:'10 панелей', l:'по 10×10 фт. · непроницаема'})},
      {k:'chain-lightning', n:'Цепная молния', l:6, cost:'act', r:'150 фт.', save:'ЛОВ', eff:() => ({v:'10к8', l:'электричеством · до четырёх целей', dice:[10, 8, 0]})},
      {k:'finger', n:'Перст смерти', l:7, cost:'act', r:'60 фт.', save:'ТЕЛ', eff:() => ({v:'7к8 + 30', l:'некротическим', dice:[7, 8, 30]})},
      {k:'meteor', n:'Метеоритный дождь', l:9, cost:'act', r:'1 миля', save:'ЛОВ', eff:() => ({v:'40к6', l:'огнём и дробящим · четыре сферы', dice:[40, 6, 0]})}],
    feats:[{k:'mastery', n:'Мастерство заклинаний', ic:'star', cost:'free', line:'Щит и Волшебная стрела — на 1 круге без ячеек', use:'info'}]},
  rogue:{perAction:1, sneak:[9, 6],
    attacks:[{k:'rapier', n:'Рапира', ic:'sword', hit:11, dice:[1, 8, 5], type:'колющий'}, {k:'shortbow', n:'Короткий лук', ic:'track', hit:11, dice:[1, 6, 5], type:'колющий', note:'80/320 фт.'}],
    spells:[],
    feats:[{k:'cunning', n:'Хитрое действие', ic:'dash', cost:'bonus', line:'Рывок, Отход или Засада', use:'cunning'},
      {k:'uncanny', n:'Невероятное уклонение', ic:'stepback', cost:'react', line:'Урон от видимой атаки — вдвое', use:'uncanny'}]}};

let arsTab = null, arsCost = 'all';
const spentCost = c => c !== 'free' && C.used[c];
const slotFor = sp => { for (let c = Math.max(1, sp.l); c <= H.slots.length; c++) if (H.slotsLeft[c - 1] > 0) return c; return 0; };
const costBadge = c => `<span class="cost ${c} ${spentCost(c) ? 'spent' : ''}" style="--acc:var(--${COST[c][2]})">${c === 'free' ? icon('spark') : COST[c][0]}</span>`;
// Rows in the app's own list language (like rest gains and spell rows of
// the Magic tab): a tinted squircle for what the use costs, the name, and
// one quiet value at the end. Details live in the sheet.
const costSq = c => `<span class="csq ${spentCost(c) ? 'spent' : ''}" style="--acc:var(--${COST[c][2]})" aria-label="${COST[c][1]}">${c === 'free' ? icon('spark') : COST[c][0]}</span>`;
function arsListHTML(){
  const A = ARSENAL[H.id], f = x => arsCost === 'all' || x.cost === arsCost;
  if (arsTab === 'spells') {
    const circles = [...new Set(A.spells.filter(f).map(s => s.l))].sort((x, y) => x - y);
    if (!circles.length) return '<p class="muted none">Нет заклинаний на это действие</p>';
    return circles.map(l => {
      const list = A.spells.filter(s => s.l === l && f(s)), m = H.slots[l - 1], left = H.slotsLeft[l - 1];
      return `<div class="cgroup"><div class="cg-h"><span class="cg-t">${l ? l + ' круг' : 'Заговоры'}</span>
          ${l ? `<button type="button" class="cg-pips" data-slot="${l}" aria-label="Потратить ячейку ${l} круга" data-peek="${l} круг|Касание — потратить ячейку вручную">${Array.from({length:m}, (_, j) => `<i class="${j < left ? 'on' : ''}"></i>`).join('')}<span class="num">${left}/${m}</span></button>` : '<span class="cg-free">без ячеек</span>'}</div>
        ${list.map(sp => { const e = sp.eff(Math.max(1, sp.l)), ok = sp.l === 0 || sp.free || slotFor(sp);
          return `<button type="button" class="arow ${ok ? '' : 'noslot'} ${spentCost(sp.cost) ? 'late' : ''}" data-use="spell:${sp.k}">${costSq(sp.cost)}
            <span class="ft"><b>${sp.n}${sp.conc ? '<i class="kb">К</i>' : ''}</b></span><span class="av num">${e.v}</span></button>`; }).join('')}</div>`;
    }).join('');
  }
  if (arsTab === 'attacks') {
    if (!f({cost:'act'})) return '<p class="muted none">Атака тратит действие</p>';
    return `${A.perAction > 1 ? `<div class="cg-h"><span class="cg-t">Атак в действии</span><span class="cg-pips static">${Array.from({length:A.perAction}, (_, j) => `<i class="${j < C.attacks ? '' : 'on'}"></i>`).join('')}<span class="num">${A.perAction - C.attacks}/${A.perAction}</span></span></div>` : ''}
      ${A.attacks.map(at => `<button type="button" class="arow ${spentCost('act') && C.attacks >= A.perAction ? 'late' : ''}" data-use="atk:${at.k}">${costSq('act')}
        <span class="ft"><b>${at.n}</b><small>${at.dice[0]}к${at.dice[1]} + ${at.dice[2]} ${at.type}${at.note ? ' · ' + at.note : ''}</small></span><span class="av num">${fmt(at.hit)}</span></button>`).join('')}`;
  }
  const feats = A.feats.filter(f);
  if (!feats.length) return '<p class="muted none">Нет умений на это действие</p>';
  return feats.map(ft => { const r = ft.res != null ? H.res[ft.res] : null, on = ft.use === 'toggle' ? C.effects.some(e => e.k === ft.effect.k) : ft.use === 'reckless' ? C.reckless : false;
    return `<button type="button" class="arow ${on ? 'on' : ''} ${spentCost(ft.cost) ? 'late' : ''} ${r && r.left === 0 ? 'noslot' : ''}" data-use="feat:${ft.k}" data-peek="${ft.n}|${ft.line}">${costSq(ft.cost)}
      <span class="ft"><b>${ft.n}</b><small>${ft.line}</small></span>
      ${r ? `<span class="av num">${r.left === Infinity ? '∞' : r.left}${r.max === Infinity ? '' : `<small>/${r.max}</small>`}</span>` : on ? `<span class="av on">${icon('check')}</span>` : ''}</button>`; }).join('');
}
// On the combat screen the arsenal is three doors, not a wall: each opens
// the arsenal sheet on its own tab, the turn tokens riding along on top.
const TABACC = {spells:'a5', attacks:'a0', feats:'a2'};
function arsTabs(){ const A = ARSENAL[H.id]; return [...(A.spells.length ? [['spells', 'Заклинания']] : []), ['attacks', 'Атаки'], ['feats', 'Умения']]; }
function arsenalHTML(){
  const A = ARSENAL[H.id]; if (!A || H.hp === 0) return '';
  const slots = H.slotsLeft.reduce((x, y) => x + y, 0), active = A.feats.filter(ft => ft.use === 'toggle' && C.effects.some(e => e.k === ft.effect.k)).map(ft => ft.n);
  const sub = {spells:`${slots} ${plural(slots, 'ячейка', 'ячейки', 'ячеек')}`, attacks:A.perAction > 1 ? `ещё ${A.perAction - C.attacks} из ${A.perAction}` : `${fmt(A.attacks[0].hit)} к попаданию`,
    feats:active.length ? active.join(', ') : `${A.feats.length} ${plural(A.feats.length, 'умение', 'умения', 'умений')}`};
  const ic = {spells:'wand', attacks:'sword', feats:'star'};
  return `<div class="sec-title">Арсенал<small>${A.dc ? `Сл ${A.dc} · атака ${fmt(A.atk)}` : 'тратит ход сам'}</small></div>
    <div class="arsgo" id="arsenal">${arsTabs().map(([k, n]) => `<button type="button" class="ago ${k === 'feats' && active.length ? 'live' : ''}" data-ars="${k}" style="--acc:var(--${TABACC[k]})"><span class="gi">${icon(ic[k])}</span><b>${n}</b><small>${sub[k]}</small></button>`).join('')}</div>`;
}
function bindArsenal(){
  $$('[data-ars]').forEach(b => b.addEventListener('click', () => { buzz.tick(); arsenalSheet(b.dataset.ars, b); }));
}
const turnStrip = () => [['act', 'Действие'], ['bonus', 'Бонусное'], ['react', 'Реакция']].map(([k, n]) => `<button type="button" data-cf="${k}" aria-pressed="${arsCost === k}" class="${C.used[k] ? 'used' : ''}" style="--acc:var(--${COST[k][2]})"><i>${C.used[k] ? icon('check') : ''}</i>${n}</button>`).join('');
function arsenalSheet(tab){
  arsTab = tab; const A = ARSENAL[H.id];
  openSheet(`<span class="bs-kicker">${H.name}${A.dc ? ` · Сл ${A.dc} · атака ${fmt(A.atk)}` : ''}</span><h2 class="bs-title">Арсенал</h2>
    ${segHTML(arsTabs(), arsTab, 'arsSeg')}
    <div class="costf" id="costf" aria-label="Что ещё осталось в этом ходу">${turnStrip()}</div>
    <div class="arslist" id="arsList" style="--tab:var(--${TABACC[arsTab]})">${arsListHTML()}</div>`, {onOpen(sh, close){
      const redraw = dir => { const l = $('#arsList', sh); l.style.setProperty('--tab', `var(--${TABACC[arsTab]})`); l.innerHTML = arsListHTML(); if (!reduced) [...l.children].forEach((c, i) => c.animate([{opacity:0, transform:`translateX(${dir * 18}px)`}, {opacity:1, transform:'none'}], {duration:420, delay:i * 28, easing:springEasing(SPR.snappy, .42), fill:'backwards'})); };
      const order = ['spells', 'attacks', 'feats'], keep = arsTab, list = $('#arsList', sh);
      let tallest = 0; arsTabs().forEach(([k]) => { arsTab = k; list.innerHTML = arsListHTML(); tallest = Math.max(tallest, sh.offsetHeight); });
      arsTab = keep; list.innerHTML = arsListHTML(); sh.style.height = tallest + 'px';
      segment($('#arsSeg', sh), b => { const was = arsTab; arsTab = b.dataset.v; redraw(order.indexOf(arsTab) > order.indexOf(was) ? 1 : -1); });
      // The turn tokens double as a filter: "what can I still do with my bonus action?"
      $('#costf', sh).addEventListener('click', e => { const b = e.target.closest('[data-cf]'); if (!b) return; arsCost = arsCost === b.dataset.cf ? 'all' : b.dataset.cf; buzz.tick(); $$('#costf button', sh).forEach(x => x.setAttribute('aria-pressed', x.dataset.cf === arsCost)); redraw(0); });
      $('#arsList', sh).addEventListener('click', e => {
        const s = e.target.closest('[data-slot]'); if (s) { const c = +s.dataset.slot; if (!H.slotsLeft[c - 1]) return toast(`Ячеек ${c} круга не осталось`); snap(); H.slotsLeft[c - 1]--; log(`Ячейка ${c} круга потрачена`, 'a4'); buzz.light(); redraw(0); return; }
        const u = e.target.closest('[data-use]'); if (!u) return;
        const [kind, k] = u.dataset.use.split(':');
        if (kind === 'feat' && A.feats.find(x => x.k === k).use === 'info') return showPeek(u);
        close(0, () => { if (kind === 'spell') castSheet3(A.spells.find(x => x.k === k)); else if (kind === 'atk') attackSheet(A.attacks.find(x => x.k === k)); else useFeat(A.feats.find(x => x.k === k), u); });
      });
    }, onClose(){ live(render); }});
}

/* ---------- paying for a use ---------- */
function payCost(cost){ if (cost === 'free') return; C.used[cost] = true; }
function addEffect(ef){ C.effects = C.effects.filter(e => e.k !== ef.k); C.effects.unshift({k:ef.k, n:ef.n, ic:ef.ic, acc:ef.acc, left:ef.dur, max:ef.dur, conc:ef.conc, resist:ef.resist}); }
function afterUse(){ live(render); $$('.tok.spent').forEach(t => replay(t, 'flash')); }

// Rolled dice of a use: up to twelve tumble on the sheet, the rest are
// counted into the total.
function rollGroups(groups, crit){
  const out = [];
  groups.forEach(g => { const n = g.n * (crit ? 2 : 1) + (crit && g.brutal ? g.brutal : 0); for (let i = 0; i < n; i++) out.push({s:g.d, v:1 + Math.floor(Math.random() * g.d), tag:g.tag}); });
  return {dice:out, total:out.reduce((a, x) => a + x.v, 0) + groups.reduce((a, g) => a + (g.flat || 0), 0)};
}
function showRoll(host, r, groups, {label, flagHTML = '', after, crit = false} = {}){
  const cnt = g => g.n * (crit ? 2 : 1) + (crit && g.brutal ? g.brutal : 0);
  const shown = r.dice.slice(0, 12), rest = r.dice.length - shown.length;
  host.innerHTML = `<div class="res"><span class="cap">${label}</span><div class="res-dice">${shown.map(x => dieN(x.s, 'к' + x.s, {cls:'sm'})).join('')}${rest ? `<span class="more-d">+${rest} к${r.dice[12].s}</span>` : ''}</div>
    <div class="total dim"><span class="tv num">${odo(r.total, 'rt' + label.length)}</span><div class="tb"><span class="brk">${groups.map(g => `<span class="dk" style="--acc:${DACC[g.d] || 'var(--fg)'}">${g.tag || ''}<b>${g.n ? cnt(g) + 'к' + g.d : ''}${g.flat ? (g.n ? ' + ' : '') + g.flat : ''}</b></span>`).join('<i>+</i>')}</span>${flagHTML}</div></div></div>`;
  replay(host.firstElementChild, 'resin');
  throwDice($$('.res-dice .die2', host), shown.map(x => x.v), shown.map(x => x.s), () => {
    const t = $('.total', host); t.classList.remove('dim'); const o = $('.odo', t); if (!reduced) { spinTo(o, digits(r.total).map(() => 0), digits(r.total)); replay(t, 'reveal'); }
    buzz.light(); after && after();
  });
}

/* ---------- cast sheet in combat ---------- */
function castSheet3(sp){
  const A = ARSENAL[H.id];
  const rungs = sp.l === 0 ? [] : [...(sp.free ? [{k:'free', n:sp.l, label:'мастерство', left:1, max:1}] : []),
    ...H.slots.map((m, i) => ({k:String(i + 1), n:i + 1, label:'круг', left:H.slotsLeft[i], max:m})).filter(r => r.n >= sp.l)];
  let pick = (rungs.find(r => r.left > 0) || {}).k;
  const circle = () => (rungs.find(r => r.k === pick) || {n:Math.max(1, sp.l)}).n;
  const facts = () => [['ВРЕМЯ', COST[sp.cost][1].toLowerCase()], ['ДИСТАНЦИЯ', sp.r], ['ДЛИТЕЛЬНОСТЬ', (sp.conc ? 'конц., ' : '') + durText(sp.dur)], ...(sp.save ? [['СЛ СПАСА', `${sp.save} ${A.dc}`]] : []), ...(sp.hit ? [['АТАКА', fmt(A.atk)]] : [])]
    .map(([a, b]) => `<div class="cell"><small>${a}</small><b>${b}</b></div>`).join('');
  const e0 = sp.eff(circle());
  openSheet(`<span class="bs-kicker" style="color:var(--a5)">${sp.l ? sp.l + ' круг' : 'Заговор'} · ${COST[sp.cost][1]}${sp.conc ? ' · концентрация' : ''}</span><h2 class="bs-title">${sp.n}</h2>
    <div class="effect" id="eff" style="--acc:var(--a5)"><b id="effV">${e0.v}</b><span id="effL">${e0.l}</span></div>
    <div id="castPick">${rungs.length ? `<div class="ladder2">${rungs.map(r => `<button type="button" class="rung2 ${r.k === 'free' ? 'rit' : ''}" data-k="${r.k}" aria-pressed="${r.k === pick}" ${r.left ? '' : 'disabled'}><small>${r.label}</small><b>${r.k === 'free' ? icon('star') : r.n}</b><span class="mk">${r.k === 'free' ? 'без ячейки' : Array.from({length:r.max}, (_, i) => `<i class="${i < r.left ? '' : 'off'}"></i>`).join('')}</span></button>`).join('')}</div>`
      : `<div class="note">${icon('spark')}<span>Заговор — без ячейки, растёт с уровнем</span></div>`}
    <div class="grid2 facts2" id="facts" style="margin-top:14px">${facts()}</div>
    ${sp.conc && H.conc ? `<div class="note" style="margin-top:14px">${icon('timer')}<span>Прервёт концентрацию на «${H.conc}»</span></div>` : ''}
    ${spentCost(sp.cost) ? `<div class="note warn" style="margin-top:14px">${icon('info')}<span>${COST[sp.cost][1]} этого хода уже потрачено. Наложить всё равно — если мастер разрешил.</span></div>` : ''}</div>
    <div id="castRes"></div>
    <button type="button" class="btn primary wide" id="castGo" style="height:56px" ${sp.l && !pick ? 'disabled' : ''}></button>`, {onOpen(sh, close){
      let done = false;
      const label = () => { $('#castGo', sh).innerHTML = icon('wand') + ' ' + (!rungs.length ? 'Наложить' : !pick ? 'Нет ячеек' : pick === 'free' ? 'Наложить · без ячейки' : `Наложить · ячейка ${pick} круга`); };
      label();
      $$('.rung2', sh).forEach(b => b.addEventListener('click', () => { if (pick === b.dataset.k) return; pick = b.dataset.k; buzz.tick(); $$('.rung2', sh).forEach(x => x.setAttribute('aria-pressed', x === b)); label();
        const e = sp.eff(circle()); if ($('#effV', sh).textContent !== String(e.v)) { $('#effV', sh).textContent = e.v; $('#effL', sh).textContent = e.l; if (!reduced) $('#effV', sh).animate([{transform:'translateY(14px)', opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.bouncy, .42)}); } }));
      $('#castGo', sh).addEventListener('click', () => {
        if (done) return close(0, afterUse);
        snap(); done = true;
        const c = circle(); if (pick && pick !== 'free') H.slotsLeft[+pick - 1]--;
        payCost(sp.cost);
        if (sp.conc) { if (H.conc) { C.effects = C.effects.filter(e => !e.conc); log(`Концентрация на «${H.conc}» прервана`, 'a5'); } H.conc = sp.n; addEffect({k:sp.k, n:sp.n, ic:'timer', acc:5, dur:sp.dur, conc:true}); }
        log(`${sp.n}${pick === 'free' ? ' · без ячейки' : pick ? ` · ячейка ${pick}` : ''}`, 'a5'); buzz.light();
        const e = sp.eff(c), pickBox = $('#castPick', sh);
        if (!e.dice) return close(0, () => { afterUse(); toast(`${sp.n}${sp.conc ? ' · концентрация' : ''}`); });
        pickBox.animate && !reduced ? pickBox.animate([{opacity:1}, {opacity:0, transform:'scale(.97)'}], {duration:200, fill:'forwards'}).onfinish = () => pickBox.remove() : pickBox.remove();
        const go = $('#castGo', sh); go.disabled = true; go.innerHTML = 'Бросаю…';
        const finish = (crit) => { const groups = [{n:e.dice[0], d:e.dice[1], flat:e.dice[2]}], r = rollGroups(groups, crit);
          showRoll($('#castRes', sh).appendChild(document.createElement('div')), r, groups, {label:crit ? 'Урон · крит' : 'Урон', crit, flagHTML:sp.save ? `<span class="half">Спасбросок ${sp.save} Сл ${A.dc} · успех — половина: <b>${Math.floor(r.total / 2)}</b></span>` : '',
            after(){ go.disabled = false; go.innerHTML = 'Готово'; log(`${sp.n}: ${r.total} урона`, 'a5'); }}); };
        if (sp.hit) {
          const v = d20(), hostA = $('#castRes', sh).appendChild(document.createElement('div')), crit = v === 20;
          hostA.innerHTML = `<div class="res"><span class="cap">Атака заклинанием</span><div class="res-row">${dieN(20, 'к20')}<span class="tv num">${v + A.atk}</span><span class="muted">${v} ${fmt(A.atk)}</span>${crit ? `<span class="flag gold">${icon('star')} Крит — кости удвоены</span>` : v === 1 ? `<span class="flag red">${icon('skull')} Промах</span>` : ''}</div></div>`;
          const tv = $('.tv', hostA); tv.style.opacity = 0;
          throwDice([$('.die2', hostA)], [v], [20], () => { tv.style.opacity = 1; replay(tv, 'pop'); if (crit) { $('.die2', hostA).classList.add('nat20'); sparks(hostA, $('.die2', hostA), 'var(--a2)'); buzz.medium(); }
            if (v === 1) { $('.die2', hostA).classList.add('nat1'); go.disabled = false; go.innerHTML = 'Готово'; return; } finish(crit); });
        } else finish(false);
      });
    }});
}

/* ---------- attack sheet ---------- */
function attackSheet(a){
  const A = ARSENAL[H.id], raging = C.effects.some(e => e.k === 'rage'), sacred = C.effects.some(e => e.k === 'sacred');
  let adv = C.reckless ? 'adv' : 'none', smite = 0, sneak = false, phase = 'hit', crit = false;
  const smiteRungs = A.smite ? H.slots.map((m, i) => ({n:i + 1, left:H.slotsLeft[i], max:m})) : [];
  const hitMod = a.hit + (sacred ? 5 : 0);
  openSheet(`<span class="bs-kicker" style="color:var(--a0)">Атака · Действие${A.perAction > 1 ? ` · ${Math.min(C.attacks + 1, A.perAction)} из ${A.perAction}` : ''}</span><h2 class="bs-title">${a.n}</h2>
    <div class="tagrow">${sacred ? `<span class="tag on" style="--acc:var(--a2)">${icon('sun')} Священное оружие +5</span>` : ''}${raging ? `<span class="tag on" style="--acc:var(--a0)">${icon('axe')} Ярость +4 урона</span>` : ''}${C.reckless ? `<span class="tag on" style="--acc:var(--a1)">${icon('bolt')} Безрассудно</span>` : ''}${a.extra ? `<span class="tag on" style="--acc:var(--a2)">${icon('star')} ${a.extra.n} +1к8</span>` : ''}</div>
    <div class="advseg">${segHTML([['dis', 'Помеха'], ['none', 'Обычно'], ['adv', 'Преимущество']], adv, 'atkAdv')}</div>
    <div id="atkRes"></div>
    <div id="atkOpts">${A.smite ? `<div class="opt-h"><b>Божественная кара</b><small>при попадании · ячейка → 2к8 и больше</small></div><div class="ladder2" id="smite"><button type="button" class="rung2" data-sm="0" aria-pressed="true"><small>без кары</small><b>—</b><span class="mk">&nbsp;</span></button>${smiteRungs.map(r => `<button type="button" class="rung2" data-sm="${r.n}" aria-pressed="false" ${r.left ? '' : 'disabled'}><small>${Math.min(5, r.n + 1)}к8</small><b>${r.n}</b><span class="mk">${Array.from({length:r.max}, (_, i) => `<i class="${i < r.left ? '' : 'off'}"></i>`).join('')}</span></button>`).join('')}</div>` : ''}
      ${A.sneak ? `<button type="button" class="mvo wide" id="sneak" aria-pressed="false" ${C.sneakUsed ? 'disabled' : ''} style="--acc:var(--a5)"><span class="mi">${icon('mask')}</span><span><b>Скрытая атака · ${A.sneak[0]}к${A.sneak[1]}</b><small>${C.sneakUsed ? 'Уже в этом ходу' : 'Раз в ход: преимущество или союзник рядом с целью'}</small></span></button>` : ''}</div>
    <button type="button" class="btn primary wide" id="atkGo" style="height:56px"></button>`, {onOpen(sh, close){
      const go = $('#atkGo', sh), res = $('#atkRes', sh);
      const label = () => { go.disabled = false; go.innerHTML = phase === 'hit' ? `${icon('dice')} Бросить атаку · ${fmt(hitMod)}` : phase === 'dmg' ? `${icon('sword')} Бросить урон` : C.attacks < A.perAction ? `${icon('swap')} Следующая атака · ${C.attacks + 1} из ${A.perAction}` : 'Готово'; };
      label();
      segment($('#atkAdv', sh), b => { adv = b.dataset.v; });
      $$('#smite .rung2', sh).forEach(b => b.addEventListener('click', () => { smite = +b.dataset.sm; buzz.tick(); $$('#smite .rung2', sh).forEach(x => x.setAttribute('aria-pressed', x === b)); }));
      $('#sneak', sh)?.addEventListener('click', e => { sneak = !sneak; e.currentTarget.setAttribute('aria-pressed', sneak); buzz.tick(); });
      go.addEventListener('click', () => {
        if (phase === 'hit') {
          snap(); C.used.act = true; C.attacks++; go.disabled = true;
          const v1 = d20(), v2 = adv === 'none' ? null : 1 + Math.floor(Math.random() * 20);
          const keep = v2 == null ? v1 : adv === 'adv' ? Math.max(v1, v2) : Math.min(v1, v2);
          crit = keep === 20;
          res.innerHTML = `<div class="res"><span class="cap">Попадание</span><div class="res-row">${dieN(20, 'к20', {cls:'a'})}${v2 != null ? dieN(20, 'к20', {cls:'b'}) : ''}<span class="tv num" style="opacity:0">${keep + hitMod}</span><span class="muted mm">${keep} ${fmt(hitMod)}</span></div></div>`;
          replay(res.firstElementChild, 'resin');
          throwDice($$('.die2', res), v2 == null ? [v1] : [v1, v2], [20, 20], () => {
            const ds = $$('.die2', res); if (v2 != null) ds[(adv === 'adv' ? v1 >= v2 : v1 <= v2) ? 1 : 0].classList.add('drop');
            const kd = ds.find(d => !d.classList.contains('drop')), tv = $('.tv', res); tv.style.opacity = 1; replay(tv, 'pop');
            if (crit) { kd.classList.add('nat20'); sparks(res.firstElementChild, kd, 'var(--a2)'); buzz.medium(); $('.res-row', res).insertAdjacentHTML('beforeend', `<span class="flag gold">${icon('star')} Крит — кости урона удвоены</span>`); }
            if (keep === 1) { kd.classList.add('nat1'); $('.res-row', res).insertAdjacentHTML('beforeend', `<span class="flag red">${icon('skull')} Промах</span>`); phase = 'done'; log(`${a.n}: промах`, 'a0'); return label(); }
            log(`${a.n}: ${keep + hitMod} к попаданию${crit ? ' · крит' : ''}`, 'a0'); phase = 'dmg'; label();
          });
        } else if (phase === 'dmg') {
          go.disabled = true;
          const groups = [{n:a.dice[0], d:a.dice[1], flat:a.dice[2] + (raging ? 4 : 0), tag:a.type.slice(0, 3), brutal:A.brutal}];
          if (a.extra) groups.push({n:a.extra.dice[0], d:a.extra.dice[1], tag:'изл'});
          if (smite) { H.slotsLeft[smite - 1]--; groups.push({n:Math.min(5, smite + 1), d:8, tag:'кара'}); log(`Божественная кара · ячейка ${smite}`, 'a2'); }
          if (sneak) { C.sneakUsed = true; groups.push({n:A.sneak[0], d:A.sneak[1], tag:'скрыт'}); }
          const r = rollGroups(groups, crit), host = document.createElement('div'); res.appendChild(host);
          $('#atkOpts', sh).remove();
          showRoll(host, r, groups, {label:crit ? 'Урон · крит' : 'Урон', crit, after(){ log(`${a.n}: ${r.total} урона`, 'a0'); phase = 'done'; label(); }});
        } else if (C.attacks < A.perAction) { close(0, () => { afterUse(); attackSheet(a); }); }
        else close(0, afterUse);
      });
    }, onClose(){ live(render); }});
}

/* ---------- features ---------- */
function useFeat(ft, el){
  const r = ft.res != null ? H.res[ft.res] : null;
  if (ft.use === 'info') return showPeek(el);
  if (INSTRUMENT[ft.k] && !(r && r.left === 0)) return INSTRUMENT[ft.k]();
  if (r && r.left === 0) return toast(`${ft.n}: не осталось — ${r.rest === 'short' ? 'короткий' : 'длительный'} отдых`);
  if (ft.use === 'loh') return keypadSheet({kicker:`Запас ${r.left} из ${r.max}`, title:'Наложение рук', onDone(v){ if (v > r.left) return toast(`В запасе только ${r.left}`); payCost('act'); r.left -= v; heal(v); log(`Наложение рук: ${v} из запаса`, 'a2'); afterUse(); }});
  snap();
  if (ft.use === 'spend') { r.left--; payCost(ft.cost); log(ft.n, 'a4'); toast(ft.n); }
  if (ft.use === 'effect') { r.left--; payCost(ft.cost); addEffect(ft.effect); log(`${ft.n} · ${durText(ft.effect.dur)}`, 'a2'); toast(ft.n + ' — на ленте раундов'); }
  if (ft.use === 'toggle') { const on = C.effects.some(e => e.k === ft.effect.k); if (on) { C.effects = C.effects.filter(e => e.k !== ft.effect.k); log(`${ft.n} окончена`, 'a0'); } else { payCost(ft.cost); addEffect(ft.effect); log(`${ft.n}!`, 'a0'); buzz.medium(); } }
  if (ft.use === 'reckless') { C.reckless = !C.reckless; toast(C.reckless ? 'Атаки с преимуществом — и по вам тоже до вашего хода' : 'Безрассудство снято'); }
  if (ft.use === 'uncanny') { payCost('react'); C.halve = true; log('Невероятное уклонение', 'a4'); toast('Следующий урон от атаки — вдвое'); }
  if (ft.use === 'cunning') {
    history.pop();
    return openSheet(`<span class="bs-kicker">Бонусное действие</span><h2 class="bs-title">Хитрое действие</h2>
      <div class="mv-opts" style="grid-template-columns:1fr">${[['dash', 'dash', 'Рывок', 'Скорость ×2 до конца хода'], ['dis', 'stepback', 'Отход', 'Перемещение не провоцирует атак'], ['hide', 'mask', 'Засада', 'Проверка Скрытности, чтобы спрятаться']].map(([k, ic, n, l]) => `<button type="button" class="mvo row" data-cu="${k}" style="--acc:var(--a1)"><span class="mi">${icon(ic)}</span><span><b>${n}</b><small>${l}</small></span></button>`).join('')}</div>`,
      {onOpen(sh, close){ $$('[data-cu]', sh).forEach(b => b.addEventListener('click', () => { snap(); payCost('bonus'); const k = b.dataset.cu; if (k === 'dash') C.dash = true; log(`Хитрое действие: ${$('b', b).textContent}`, 'a1'); buzz.light(); close(0, afterUse); })); }});
  }
  buzz.light(); afterUse();
}

applyPalette('monokai');
pickHero('paladin');
controls();
