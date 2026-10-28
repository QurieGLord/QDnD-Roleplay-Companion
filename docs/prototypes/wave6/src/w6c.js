/* ================= Creation · «Пролог» ================= */
let cr = null;
const CHAP = [['name', 'Имя', 'Как зовут героя?'], ['race', 'Народ', 'Откуда он родом?'], ['class', 'Класс', 'Чем он живёт?'], ['abil', 'Характеристики', 'В чём его сила?'],
  ['bg', 'Предыстория', 'Кем он был до приключений?'], ['skills', 'Навыки', 'Чему он научился?'], ['feat', 'Умения', 'Что даёт класс на старте?'], ['gear', 'Снаряжение', 'С чем выходит в путь?'], ['done', 'Итог', 'Вот он, ваш герой']];
function startCreate(){
  cr = {i:0, dir:1, name:'', race:null, sub:null, cls:null, method:'std', assign:{}, pick:null, pb:{str:8, dex:8, con:8, int:8, wis:8, cha:8}, rolled:null, bg:null, skills:[], style:null, cantrips:[], pkg:null};
  go({s:'create'});
}
const crRace = () => RACES.find(r => r.id === cr.race), crSub = () => crRace()?.subs?.find(s => s.id === cr.sub), crCls = () => clsOf(cr.cls), crBg = () => BGS.find(b => b.id === cr.bg);
const crAcc = () => crCls() ? crCls().acc : crRace() ? crRace().acc : 1;
const bonusOf = id => (crRace()?.bonus[id] || 0) + (crSub()?.bonus[id] || 0);
const baseOf = id => cr.method === 'buy' ? cr.pb[id] : cr.assign[id];
const scoreOf = id => baseOf(id) == null ? null : baseOf(id) + bonusOf(id);
const PB_COST = {8:0, 9:1, 10:2, 11:3, 12:4, 13:5, 14:7, 15:9};
const pbLeft = () => 27 - AB.reduce((s, [id]) => s + PB_COST[cr.pb[id]], 0);
const pool = () => cr.method === 'roll' ? (cr.rolled || []) : [15, 14, 13, 12, 10, 8];
const skillNeed = () => (SKILLS[cr.cls] || SKILLS._)[0];
const speedOf = () => cr.sub === 'wood' ? 35 : ['dwarf', 'halfling'].includes(cr.race) ? 25 : 30;
const hpOf = () => crCls() ? crCls().die + mod(scoreOf('con') ?? 10) + (cr.sub === 'hill' ? 1 : 0) : null;
const acOf = () => { const dex = mod(scoreOf('dex') ?? 10); if (cr.cls === 'fighter' && cr.pkg === 'a') return 18; if (cr.cls === 'fighter' && cr.pkg === 'b') return 11 + dex;
  if (cr.cls === 'barbarian') return 10 + dex + mod(scoreOf('con') ?? 10); if (cr.cls === 'monk') return 10 + dex + mod(scoreOf('wis') ?? 10); return 10 + dex; };
function chapOk(k){
  if (k === 'name') return !!cr.name.trim();
  if (k === 'race') return !!cr.race && (!crRace().subs || !!cr.sub);
  if (k === 'class') return !!cr.cls;
  if (k === 'abil') return cr.method === 'buy' ? pbLeft() >= 0 : AB.every(([id]) => cr.assign[id] != null);
  if (k === 'bg') return !!cr.bg;
  if (k === 'skills') return cr.skills.length === skillNeed();
  if (k === 'feat') return cr.cls === 'fighter' ? !!cr.style : cr.cls === 'wizard' ? cr.cantrips.length === 3 : true;
  if (k === 'gear') return !!cr.pkg;
  return true;
}
const chapHint = k => ({name:'Назовите героя', race:cr.race ? 'Выберите разновидность' : 'Выберите народ', class:'Выберите класс', abil:'Расставьте все шесть значений', bg:'Выберите предысторию',
  skills:`Выберите ещё ${skillNeed() - cr.skills.length}`, feat:cr.cls === 'fighter' ? 'Выберите боевой стиль' : `Выберите ещё ${3 - cr.cantrips.length}`, gear:'Выберите набор'})[k] || '';

/* --- the hero card that builds itself --- */
function cardInner(){
  const r = crRace(), c = crCls(), b = crBg();
  const bits = [r && ['race', r.ic, (crSub() ? crSub().n + ' ' : '') + r.n.toLowerCase()], c && ['class', c.ic, `${c.n} · к${c.die}`], b && ['bg', 'book', b.n],
    cr.skills.length && ['skills', 'target', `Навыков: ${cr.skills.length + (b ? 2 : 0)}`], hpOf() != null && AB.every(([id]) => scoreOf(id) != null) && ['hp', 'heart', `ОЗ ${hpOf()}`]].filter(Boolean);
  return `<div class="row">${`<span class="av6 lg" data-k="av">${cr.name ? cr.name.trim()[0] || '?' : c ? icon(c.ic) : '?'}</span>`}
      <span class="ft"><b class="nm ${cr.name ? '' : 'blank6'}">${cr.name || 'Безымянный герой'}</b><small>${[r ? r.n : null, c ? c.n + ', 1-й уровень' : null].filter(Boolean).join(' · ') || 'Народ и класс ещё впереди'}</small></span></div>
    ${bits.length ? `<div class="bits">${bits.map(([k, ic, t]) => `<span class="bit" data-k="${k}">${icon(ic)}${t}</span>`).join('')}</div>` : ''}`;
}
function updateCard(){
  const card = $('#hcard'); if (!card) return;
  const html = cardInner(); if (card.innerHTML === html && card.style.getPropertyValue('--acc') === `var(--a${crAcc()})`) return;
  card.style.setProperty('--acc', `var(--a${crAcc()})`);
  flip(card, () => { card.innerHTML = html; });
}

/* --- chapter bodies --- */
const groupH = (t, note = '') => `<div class="grp6"><b>${t}</b>${note ? `<small>${note}</small>` : ''}</div>`;
function chapBody(k){
  if (k === 'name') return `<label class="fld6"><span>Имя героя</span><input id="crName" value="${cr.name}" placeholder="Например, Лира" autocomplete="off" maxlength="40"></label>
    <p class="hint5">${icon('info')} Облик, возраст и характер — в анкете героя: её можно заполнить и потом.</p>`;
  if (k === 'race') return `<div class="deck6">${RACES.map(r => `<button type="button" class="dc ${cr.race === r.id ? 'on' : ''}" data-race="${r.id}" data-hold6="race:${r.id}" style="--acc:var(--a${r.acc})">${r.lib ? `<span class="lib">${r.lib}</span>` : ''}${info('race:' + r.id)}<i class="tick">${icon('check')}</i><span class="sig">${icon(r.ic)}</span><h3>${r.n}</h3><p>${r.d}</p><span class="facts">${r.facts.map(f => `<span>${f}</span>`).join('')}</span></button>`).join('')}</div>
    <p class="hint5">${icon('info')} Листайте колоду. Удержание карточки — все особенности народа.</p>
    <div class="reveal ${crRace()?.subs ? 'open' : ''}" id="subs"><div><div class="body6" id="subsIn">${subsHTML()}</div></div></div>`;
  if (k === 'class') return `<div class="deck6">${CLASSES.map(c => `<button type="button" class="dc ${cr.cls === c.id ? 'on' : ''}" data-cls="${c.id}" data-hold6="class:${c.id}" style="--acc:var(--a${c.acc})">${c.lib ? `<span class="lib">${c.lib}</span>` : ''}${info('class:' + c.id)}<i class="tick">${icon('check')}</i><span class="sig">${icon(c.ic)}</span><h3>${c.n}</h3><p>${c.d}</p><span class="facts"><span>к${c.die}</span><span>${c.key}</span><span>Спасброски: ${c.saves}</span></span></button>`).join('')}</div>
    <p class="hint5">${icon('info')} Удержание карточки — доспехи, оружие, навыки и умения 1-го уровня. Класс из вашей библиотеки стоит в той же колоде.</p>`;
  if (k === 'abil') return `${segHTML([['std', 'Набор'], ['buy', 'Покупка'], ['roll', 'Бросок']], cr.method, 'mseg')}<div class="body6" id="abody">${abilBody()}</div>`;
  if (k === 'bg') return `<div class="picks">${BGS.map(b => `<button type="button" class="pick6 card6 ${cr.bg === b.id ? 'on' : ''}" data-bg="${b.id}" data-hold6="bg:${b.id}" style="--acc:var(--a5)"><span class="ph">${seal5('book', 5)}<span class="ft"><b>${b.n}</b><small>${b.d}</small></span>${info('bg:' + b.id)}${tick}</span><span class="chips6">${b.sk.map(s => `<span class="fact6">${icon('target')}${s}</span>`).join('')}<span class="fact6">${icon('star')}${b.feat[0]}</span></span>${b.lib ? `<span class="src6">${b.lib}</span>` : ''}</button>`).join('')}</div>`;
  if (k === 'skills'){
    const [need, list] = SKILLS[cr.cls] || SKILLS._, fromBg = crBg()?.sk || [];
    return `<div class="mbar" style="--a5:var(--a${crAcc()})"><b class="num" id="skn">${odo(cr.skills.length, 'skn')}</b><span class="ft"><b>из ${need} навыков класса</b><small>Сверх лимита новый выбор сменит самый ранний</small></span></div>
      ${fromBg.length ? `${groupH('От предыстории', crBg().n)}<div class="chips6">${fromBg.map(n => `<span class="ch6 lockd">${icon('book')}${n}</span>`).join('')}</div>` : ''}
      ${groupH(`Навыки класса · ${crCls().n}`)}<div class="chips6">${list.map(n => { const bg = fromBg.includes(n);
        return `<button type="button" class="ch6 ${cr.skills.includes(n) ? 'on' : ''} ${bg ? 'off' : ''}" data-skill="${n}">${n}</button>`; }).join('')}</div>`;
  }
  if (k === 'feat'){
    const c = crCls(), feats = `${groupH('Умения класса', 'касание — подробно')}<div class="gain6">${c.f.map(([n, d, ic], i) => `<button type="button" class="gainc tap6" data-info="feature:${c.id}.${i}" style="--acc:var(--a${c.acc})">${seal5(ic, c.acc)}<span class="ft"><b>${n}</b><small>${d}</small></span>${icon('fwd', 'chev')}</button>`).join('')}</div>`;
    if (cr.cls === 'fighter') return `${groupH('Боевой стиль', 'один на выбор')}<div class="picks">${STYLES.map(([n, d]) => `<button type="button" class="pick6 card6 ${cr.style === n ? 'on' : ''}" data-style="${n}" data-hold6="style:${n}" style="--acc:var(--a3)"><span class="ph">${seal5('sword', 3)}<span class="ft"><b>${n}</b><small>${d}</small></span>${tick}</span></button>`).join('')}</div>${feats}`;
    if (cr.cls === 'wizard') return `<div class="mbar" style="--a5:var(--a4)"><b class="num" id="cn">${odo(cr.cantrips.length, 'cn')}</b><span class="ft"><b>из 3 заговоров</b><small>Удержание — описание. Сверх лимита новый сменит самый ранний.</small></span></div>
      <div class="chips6">${CANTRIPS.map(([n]) => `<button type="button" class="ch6 ${cr.cantrips.includes(n) ? 'on' : ''}" data-cant="${n}" data-hold6="cantrip:${n}">${icon('magic')}${n}</button>`).join('')}</div>${feats}`;
    return `<p class="hint5">${icon('info')} На 1-м уровне у класса нет выбора — умения добавятся сами.</p>${feats}`;
  }
  if (k === 'gear') return `<div class="picks">${pkgs().map(p => `<button type="button" class="pick6 card6 pkg ${cr.pkg === p.id ? 'on' : ''}" data-pkg="${p.id}" style="--acc:var(--a${crAcc()})">
      <span class="ph">${seal5(p.ic, crAcc())}<span class="ft"><b>${p.n}</b><small>${p.d}</small></span>${tick}</span>
      <span class="chips6">${p.items.slice(0, 4).map(([n, q, , ic]) => `<span class="fact6">${icon(ic)}${n}${q > 1 ? ' ×' + q : ''}</span>`).join('')}${p.items.length > 4 ? `<span class="fact6">+${p.items.length - 4}</span>` : ''}</span>
      <span class="more6" data-info="pkg:${p.id}">${icon('bag')}Весь состав${icon('fwd')}</span></button>`).join('')}</div>
    <p class="hint5">${icon('info')} Предметы лягут в инвентарь; менять их можно и после создания.</p>`;
  if (k === 'done') return finalHTML();
}
function subsHTML(){
  const r = crRace(); if (!r?.subs) return '';
  return `${groupH('Разновидность', r.n)}<div class="picks">${r.subs.map(s => `<button type="button" class="pick6 card6 ${cr.sub === s.id ? 'on' : ''}" data-subr="${s.id}" style="--acc:var(--a${r.acc})"><span class="ph">${seal5(r.ic, r.acc)}<span class="ft"><b>${s.n} ${r.n.toLowerCase()}</b><small>${s.d}</small></span>${tick}</span></button>`).join('')}</div>`;
}
function pkgs(){
  if (cr.cls === 'fighter') return [
    {id:'a', n:'Латник', ic:'shield', d:'Тяжёлый доспех и щит — КД 18', items:[['Кольчуга', 1, 'Тяжёлый доспех, КД 16, помеха Скрытности', 'shield'], ['Длинный меч', 1, '1к8 рубящий, универсальное 1к10', 'sword'], ['Щит', 1, '+2 КД', 'shield'], ['Лёгкий арбалет', 1, '1к8 колющий, 80/320 футов', 'target'], ['Болты', 20, 'Боеприпасы', 'target'], ['Набор исследователя подземелий', 1, 'Рюкзак, ломик, молоток, 10 шипов, 10 факелов, трутница, 10 рационов, бурдюк, верёвка 50 футов', 'bag']]},
    {id:'b', n:'Стрелок', ic:'target', d:'Кожаный доспех и длинный лук', items:[['Кожаный доспех', 1, 'Лёгкий доспех, КД 11 + Ловкость', 'shield'], ['Длинный лук', 1, '1к8 колющий, 150/600 футов', 'target'], ['Стрелы', 20, 'Боеприпасы', 'target'], ['Короткий меч', 2, '1к6 колющий, фехтовальное, лёгкое', 'sword'], ['Набор путешественника', 1, 'Рюкзак, спальник, котелок, трутница, 10 факелов, 10 рационов, бурдюк, верёвка 50 футов', 'bag']]},
    {id:'gold', n:'Золото', ic:'gem', d:'5к4 × 10 зм — купить самому', items:[['Золотые монеты', '5к4 × 10', 'В среднем 125 зм', 'gem']]}];
  return [
    {id:'a', n:'Набор класса', ic:'bag', d:'Рекомендуемое снаряжение класса', items:[['Оружие класса', 1, 'Основное оружие', 'sword'], ['Доспех класса', 1, 'Если класс владеет доспехами', 'shield'], ['Фокус или инструмент', 1, 'Для заклинаний или ремесла', 'magic'], ['Набор путешественника', 1, 'Рюкзак, спальник, котелок, трутница, факелы, рационы, бурдюк, верёвка', 'bag']]},
    {id:'b', n:'Набор попроще', ic:'bag', d:'Простое оружие и набор исследователя', items:[['Простое оружие', 1, 'Например, булава или копьё', 'sword'], ['Набор исследователя', 1, 'Рюкзак, свечи, мел, ломик, факелы, рационы', 'bag']]},
    {id:'gold', n:'Золото', ic:'gem', d:'4к4 × 10 зм — купить самому', items:[['Золотые монеты', '4к4 × 10', 'В среднем 100 зм', 'gem']]}];
}
function pkgInfo(id){ const p = pkgs().find(x => x.id === id); return {kicker:`Снаряжение · ${crCls().n}`, title:p.n, ic:p.ic, acc:crAcc(), text:p.d, list:p.items.map(([n, q, t, ic]) => [n, q, t, ic])}; }

/* --- abilities: tokens fly into tiles, numbers roll, dice tumble --- */
function abilBody(){
  const tiles = `<div class="ab6x" style="--acc:var(--a${crAcc()})">${AB.map(([id, n, sh]) => { const b = baseOf(id), bon = bonusOf(id), v = scoreOf(id), prime = (crCls()?.pri || []).slice(0, 2).includes(id);
    return `<button type="button" class="abx ${b != null ? 'set' : ''} ${prime ? 'prime' : ''}" data-at="${id}"><span class="k">${n}${prime ? ` <em>${icon('star')}</em>` : ''}</span>
      <span class="vv"><b class="num" data-v>${v == null ? '—' : odo(v, 'av' + id)}</b><i class="mod6" data-m>${v == null ? '' : sgn(mod(v))}</i></span>
      <small>${b == null ? (cr.pick != null ? 'Сюда' : 'Пусто') : bon ? `${b} + ${bon} народ` : cr.method === 'buy' ? `${PB_COST[b]} оч.` : 'Касание — вернуть'}</small></button>`; }).join('')}</div>`;
  if (cr.method === 'buy') return `<div class="budget"><span class="ringb"><svg viewBox="0 0 54 54"><circle class="bg" cx="27" cy="27" r="24"/><circle class="fg" cx="27" cy="27" r="24" style="stroke-dashoffset:${151 * (1 - pbLeft() / 27)}"/></svg><b class="num" id="pbn">${odo(pbLeft(), 'pb')}</b></span><span class="ft"><b>очков осталось из 27</b><small>Касание характеристики — выбрать значение от 8 до 15</small></span></div>${tiles}`;
  const vals = pool(), used = AB.map(([id]) => cr.assign[id]).filter(v => v != null);
  const taken = vals.map((v, i) => used.filter(u => u === v).length > vals.slice(0, i).filter(x => x === v).length);
  // Before the roll the tray waits as six empty slots under the dice.
  const tray = cr.method === 'roll' && !cr.rolled ? `<div class="rollbox" id="rollbox" style="--acc:var(--a${crAcc()})">
      <button type="button" class="btn tonal wide" id="roll6" style="height:52px">${icon('dice')} Бросить кости</button>
      <div class="dice6" id="dice6"></div><p class="rollnote" id="rollnote">Каждый кубик — 4к6 без меньшего</p></div>
      <div class="tray6" id="tray">${Array.from({length:6}, (_, i) => `<span class="tok slot" data-slot="${i}"></span>`).join('')}</div>`
    : `<div class="tray6" id="tray">${vals.map((v, i) => `<button type="button" class="tok ${cr.pick === i ? 'on' : ''} ${taken[i] ? 'used' : ''}" data-tok="${i}">${v}</button>`).join('')}</div>
      <div class="chips6"><button type="button" class="ch6" id="auto6">${icon('spark')}Расставить по классу</button><button type="button" class="ch6" id="clr6">${icon('back')}Вернуть все</button>${cr.method === 'roll' ? `<button type="button" class="ch6" id="reroll6">${icon('dice')}Перебросить</button>` : ''}</div>`;
  return `${tray}${tiles}<p class="hint5">${icon('info')} ${cr.method === 'roll' ? 'Каждый бросок — 4к6 без меньшей кости.' : 'Стандартный набор: 15, 14, 13, 12, 10, 8.'} Касание значения, затем характеристики. ${icon('star')} — главные для класса.</p>`;
}
function paintAbil(root, onChange){
  const box = $('#abody', root);
  box.innerHTML = abilBody(); bindAbil(root, onChange);
}
function setTile(root, id){
  const t = $(`[data-at="${id}"]`, root), v = scoreOf(id), b = baseOf(id), bon = bonusOf(id);
  const vEl = $('[data-v]', t);
  if (v == null) vEl.innerHTML = '—'; else if (vEl.firstElementChild) setOdo(vEl.firstElementChild, v); else vEl.innerHTML = odo(v, 'av' + id);
  $('[data-m]', t).textContent = v == null ? '' : sgn(mod(v));
  t.classList.toggle('set', b != null);
  $('small', t).textContent = b == null ? (cr.pick != null ? 'Сюда' : 'Пусто') : bon ? `${b} + ${bon} народ` : cr.method === 'buy' ? `${PB_COST[b]} оч.` : 'Касание — вернуть';
  replay(t, 'stamp5');
}
function syncTray(root){
  const vals = pool(), used = AB.map(([id]) => cr.assign[id]).filter(v => v != null);
  $$('[data-tok]', root).forEach((b, i) => { const v = vals[i]; b.classList.toggle('used', used.filter(u => u === v).length > vals.slice(0, i).filter(x => x === v).length); b.classList.toggle('on', cr.pick === i); });
  $$('[data-at] small', root).forEach(s => { const id = s.closest('[data-at]').dataset.at; if (baseOf(id) == null) s.textContent = cr.pick != null ? 'Сюда' : 'Пусто'; });
  $$('[data-at]', root).forEach(t => t.classList.toggle('want', cr.pick != null && baseOf(t.dataset.at) == null));
}
function bindAbil(root, onChange){
  const after = () => { updateCard(); onChange(); };
  $$('[data-tok]', root).forEach(b => b.addEventListener('click', () => { if (b.classList.contains('used')) return; const i = +b.dataset.tok; cr.pick = cr.pick === i ? null : i; buzz.tick(); syncTray(root); }));
  $$('[data-at]', root).forEach(t => t.addEventListener('click', () => { const id = t.dataset.at;
    if (cr.method === 'buy') return buySheet(root, id, after);
    if (cr.pick != null){ const v = pool()[cr.pick], from = $(`[data-tok="${cr.pick}"]`, root);
      // A tile that already holds a value gives it back to the tray.
      cr.assign[id] = v; cr.pick = null; buzz.light(); syncTray(root);
      fly(from, t, `<span class="tok">${v}</span>`, () => { setTile(root, id); after(); });
    } else if (cr.assign[id] != null){ const v = cr.assign[id]; delete cr.assign[id]; buzz.tick(); syncTray(root);
      const back = $$('[data-tok]', root).find(x => +x.textContent === v && !x.classList.contains('used'));
      fly(t, back, `<span class="tok">${v}</span>`); setTile(root, id); after();
    } else { buzz.light(); const tray = $('#tray', root); if (tray) replay(tray, 'nudge'); }
  }));
  $('#auto6', root)?.addEventListener('click', () => { const pri = crCls()?.pri || ['str', 'con', 'dex'];
    const order = [...pri, ...AB.map(a => a[0]).filter(x => !pri.includes(x))], vals = [...pool()].sort((a, b) => b - a);
    cr.assign = {}; cr.pick = null; syncTray(root); buzz.light();
    order.forEach((id, i) => setTimeout(() => { cr.assign[id] = vals[i]; const toks = $$('[data-tok]', root), from = toks.find(x => +x.textContent === vals[i] && !x.classList.contains('used'));
      syncTray(root); fly(from, $(`[data-at="${id}"]`, root), `<span class="tok">${vals[i]}</span>`, () => { setTile(root, id); if (i === order.length - 1) after(); }); buzz.tick(); }, reduced ? 0 : i * 110));
  });
  $('#clr6', root)?.addEventListener('click', () => { const was = Object.keys(cr.assign); cr.assign = {}; cr.pick = null; buzz.tick(); syncTray(root); was.forEach(id => setTile(root, id)); after(); });
  $('#roll6', root)?.addEventListener('click', e => { e.currentTarget.disabled = true; rollAbilities(root, onChange); });
  $('#reroll6', root)?.addEventListener('click', () => { cr.rolled = null; cr.assign = {}; cr.pick = null; buzz.tick(); const box = $('#abody', root); flip(box, () => paintAbil(root, onChange)); after(); });
}
// Six dice rise out of the button in its place and spin down smoothly, each
// slowing to its own stop; a landed die warms with a small halo and one quiet
// ring, as on the splash. Then each value drifts into its slot in the tray.
async function rollAbilities(root, onChange){
  const sleep = ms => new Promise(r => setTimeout(r, reduced ? 0 : ms));
  const sums = Array.from({length:6}, () => { const d = Array.from({length:4}, () => 1 + Math.floor(Math.random() * 6)); return d.reduce((t, x) => t + x, 0) - Math.min(...d); });
  const btn = $('#roll6', root), row = $('#dice6', root), box = $('#rollbox', root);
  row.innerHTML = sums.map((_, i) => die('d20', '', {cls:'sm', attrs:`data-k="d${i}"`})).join('');
  const ds = $$('.die2', row);
  ds.forEach(d => d.insertAdjacentHTML('afterbegin', '<i class="halo"></i><i class="ring"></i>'));
  box.classList.add('rolling'); buzz.light();
  if (reduced){ ds.forEach((d, i) => { $('b', d).textContent = sums[i]; d.classList.add('lit'); }); }
  else {
    btn.animate([{opacity:1}, {opacity:0, transform:'scale(.97)'}], {duration:260, easing:'cubic-bezier(.3,0,1,1)', fill:'forwards'});
    const br = btn.getBoundingClientRect(), soft = 'cubic-bezier(.16,1,.3,1)';
    await Promise.all(ds.map((d, i) => new Promise(res => {
      const r = d.getBoundingClientRect(), dx = br.left + br.width / 2 - (r.left + r.width / 2), spin = 300 + i * 40, dur = 1500 + i * 110;
      d.animate([{transform:`translateX(${dx}px) scale(.55) rotate(${-spin}deg)`, opacity:0},
        {transform:`translateX(${dx * .2}px) scale(.96) rotate(${-spin * .25}deg)`, opacity:1, offset:.38},
        {transform:'none', opacity:1}], {duration:dur, easing:soft, fill:'backwards'});
      // The face changes ever more slowly as the spin dies down.
      const t0 = performance.now(), b = $('b', d); let last = 0;
      const step = now => { const p = (now - t0) / dur;
        if (p >= .94){ b.textContent = sums[i]; land(d); return res(); }
        if (now - last > 60 + p * p * 260){ last = now; b.textContent = 3 + Math.floor(Math.random() * 16); }
        requestAnimationFrame(step); };
      requestAnimationFrame(step);
    })));
  }
  function land(d){
    d.classList.add('lit'); buzz.tick();
    $('b', d).animate([{transform:'scale(1.18)', opacity:.6}, {transform:'none', opacity:1}], {duration:520, easing:'cubic-bezier(.2,0,0,1)'});
    $('.halo', d).animate([{opacity:0, transform:'scale(.7)'}, {opacity:1, transform:'none'}], {duration:900, easing:'cubic-bezier(.2,0,0,1)', fill:'forwards'});
    $('.ring', d).animate([{opacity:.32, transform:'scale(.85)'}, {opacity:0, transform:'scale(1.55)'}], {duration:1100, easing:'cubic-bezier(.2,0,0,1)', fill:'forwards'});
  }
  buzz.light();
  await sleep(650);
  for (let i = 0; i < 6; i++){
    const slot = $(`[data-slot="${i}"]`, root);
    fly(ds[i], slot, `<span class="tok">${sums[i]}</span>`, () => { slot.textContent = sums[i]; slot.classList.add('filled'); replay(slot, 'stamp5'); buzz.tick(); });
    ds[i].classList.add('sent');
    await sleep(150);
  }
  await sleep(600);
  cr.rolled = sums; buzz.medium();
  flip($('#abody', root), () => paintAbil(root, onChange));
}
function buySheet(root, id, after){
  const name = AB.find(a => a[0] === id)[1];
  openSheet(`<span class="bs-kicker">Покупка очков</span><h2 class="bs-title">${name}</h2><p class="bs-sub">Осталось очков: ${pbLeft()}. Выше 13 каждое очко стоит дороже.</p>
    <div class="pbgrid">${Object.entries(PB_COST).map(([v, c]) => { const ok = pbLeft() + PB_COST[cr.pb[id]] - c >= 0;
      return `<button type="button" class="pbv ${+v === cr.pb[id] ? 'on' : ''} ${ok ? '' : 'used'}" data-pb="${v}"><b>${v}${bonusOf(id) ? `<em>→${+v + bonusOf(id)}</em>` : ''}</b><small>${c} оч.</small></button>`; }).join('')}</div>`,
    {onOpen(sh, close){ $$('[data-pb]', sh).forEach(x => x.addEventListener('click', () => { if (x.classList.contains('used')) return; cr.pb[id] = +x.dataset.pb; buzz.tick();
      close(0, () => { setTile(root, id); const left = pbLeft(); setOdo($('#pbn', root).firstElementChild, left); $('.ringb .fg', root).style.strokeDashoffset = 151 * (1 - left / 27); after(); }); })); }});
}

/* --- the finale --- */
const SKILL_AB = {'Акробатика':'dex', 'Уход за животными':'wis', 'Атлетика':'str', 'История':'int', 'Проницательность':'wis', 'Запугивание':'cha', 'Восприятие':'wis', 'Выживание':'wis',
  'Магия':'int', 'Анализ':'int', 'Медицина':'wis', 'Религия':'int', 'Обман':'cha', 'Выступление':'cha', 'Убеждение':'cha', 'Ловкость рук':'dex', 'Скрытность':'dex'};
function finalHTML(){
  const c = crCls(), r = crRace(), b = crBg(), prof = 2, dex = mod(scoreOf('dex')), pk = pkgs().find(p => p.id === cr.pkg);
  const stats = [['heart', 'ОЗ', hpOf()], ['shield', 'КД', acOf()], ['bolt', 'Инициатива', dex, true], ['run', 'Скорость', speedOf()], ['star', 'Мастерство', prof, true]];
  // The chosen style takes the place of the generic «Боевой стиль» card.
  const feats = [...c.f.map(([n, d, ic], i) => cr.style && n === 'Боевой стиль' ? [`Боевой стиль · ${cr.style}`, STYLES.find(x => x[0] === cr.style)[1], ic, 'style:' + cr.style, c.n] : [n, d, ic, 'feature:' + c.id + '.' + i, c.n]),
    ...cr.cantrips.map(n => [n, CANTRIPS.find(x => x[0] === n)[1], 'magic', 'cantrip:' + n, 'Заговор']), [b.feat[0], b.feat[1], 'book', 'bg:' + b.id, b.n]];
  const skills = [...b.sk.map(s => [s, 'book', 'предыстория']), ...cr.skills.map(s => [s, 'target', 'класс'])];
  return `<div class="final6" id="final" style="--acc:var(--a${c.acc})"><span class="wm">${icon(c.ic)}</span>
      <div class="row"><span class="av6 xl">${cr.name.trim()[0]}</span><span class="ft"><span class="cap">Новый герой · 1-й уровень</span><b class="nm">${cr.name}</b><small>${crSub() ? crSub().n + ' ' : ''}${r.n.toLowerCase()} · ${c.n} · ${b.n}</small></span></div>
      <div class="fstats">${stats.map(([ic, n, v, sg]) => `<span>${icon(ic)}<b class="num" data-to="${v}" data-sign="${sg ? 1 : ''}">${odo(0, 'fs' + n)}</b><small>${n}</small></span>`).join('')}</div>
    </div>
    ${groupH('Характеристики', 'с бонусами народа')}
    <div class="fab6" style="--acc:var(--a${c.acc})">${AB.map(([id, n, sh]) => { const v = scoreOf(id); return `<span class="${(c.pri || []).slice(0, 2).includes(id) ? 'prime' : ''}"><small>${sh}</small><b class="num" data-to="${v}">${odo(0, 'fa' + id)}</b><em class="fm">${sgn(mod(v))}</em></span>`; }).join('')}</div>
    ${groupH('Навыки', `${skills.length} · бонус мастерства +${prof}`)}
    <div class="skl6" style="--acc:var(--a${c.acc})">${skills.map(([s, ic, from]) => { const ab = SKILL_AB[s], bonus = mod(scoreOf(ab)) + prof;
      return `<span class="skr">${seal5(ic, ic === 'book' ? 5 : c.acc, 'sm')}<span class="ft"><b>${s}</b><small>${AB.find(a => a[0] === ab)[2]} · ${from}</small></span><b class="bn">${sgn(bonus)}</b></span>`; }).join('')}</div>
    ${groupH('Умения', 'касание — подробно')}
    <div class="gain6">${feats.map(([n, d, ic, key, src]) => `<button type="button" class="gainc tap6" data-info="${key}" style="--acc:var(--a${c.acc})">${seal5(ic, c.acc)}<span class="ft"><b>${n}</b><small>${src} · ${d}</small></span>${icon('fwd', 'chev')}</button>`).join('')}</div>
    ${groupH('Снаряжение', pk.n)}
    <div class="gear6" style="--acc:var(--a${c.acc})">${pk.items.map(([n, q, t, ic], i, all) => `<button type="button" class="gi6 ${i === 0 || (i === all.length - 1 && all.length % 2 === 0) ? 'wide' : ''}" data-info="pkg:${pk.id}">${seal5(ic, c.acc, 'sm')}<span class="ft"><b>${n}</b><small>${t}</small></span>${q !== 1 ? `<em>×${q}</em>` : ''}</button>`).join('')}</div>`;
}
function playFinal(root){
  // The card rises first, then its numbers count up, then the rest arrives.
  const card = $('#final', root);
  if (!reduced) card.animate([{transform:'translateY(24px) scale(.94)', opacity:0}, {transform:'none', opacity:1}], {duration:620, easing:springEasing(SPR.gentle, .62)});
  $$('[data-to]', root).forEach((el, i) => setTimeout(() => { const v = +el.dataset.to; setOdo(el.firstElementChild, Math.abs(v)); if (el.dataset.sign) el.insertAdjacentHTML('afterbegin', `<span class="sg">${v < 0 ? '−' : '+'}</span>`); if (i % 3 === 0) buzz.tick(); }, reduced ? 0 : 360 + i * 70));
  stagger(root, ':scope > :not(#final)');
  stagger($('.gear6', root)); stagger($('.skl6', root));
}

/* --- the page --- */
function createHTML(){
  const [k, n, q] = CHAP[cr.i];
  return `${top5('Новый герой', {lead:'close'})}
    <div class="scroller"><div class="page6 crpage">
      ${k === 'done' ? '' : `<div class="hc6" id="hcard" style="--acc:var(--a${crAcc()})">${cardInner()}</div>`}
      <div class="chap6" style="--acc:var(--a${crAcc()})">${CHAP.map((c, i) => { const at = cr.was ?? cr.i; return `<i class="${i < at ? 'done' : i === at ? 'now' : ''}"></i>`; }).join('')}</div>
      <div class="chaph" style="--acc:var(--a${crAcc()})"><small>${cr.i + 1} · ${n}</small><small class="nx">${cr.i < CHAP.length - 1 ? 'далее: ' + CHAP[cr.i + 1][1] : ''}</small></div>
      <h2 class="q6">${q}</h2>
      <div class="body6" id="cbody"></div>
    </div></div>
    <div class="dock6"><span class="hintd glass" id="hintd"></span><div class="dockrow glass"><button type="button" class="round dkb ${cr.i ? '' : 'gone'}" id="prev" aria-label="Назад">${icon('back')}</button>
      <button type="button" class="btn primary wide" id="next">${k === 'done' ? `Создать героя ${icon('check')}` : `Далее ${icon('fwd')}`}</button></div></div>`;
}
function bindCreate(){
  const k = CHAP[cr.i][0], root = $('#cbody');
  const paint = () => { const ok = chapOk(k); $('#next').disabled = !ok; $('#hintd').textContent = ok ? '' : chapHint(k); };
  root.innerHTML = chapBody(k); bindChap(root, k, paint); paint();
  if (k === 'race' || k === 'class') { const on = $('.dc.on', root); on?.scrollIntoView({inline:'center', block:'nearest'}); }
  if (!reduced && cr.entered){
    root.animate([{transform:`translateX(${cr.dir * 44}px)`, opacity:0}, {transform:'none', opacity:1}], {duration:460, easing:springEasing(SPR.snappy, .46)});
  }
  if (k === 'done') playFinal(root); else stagger(root);
  // The bar is drawn at the chapter we came from and then flows to this one.
  if (cr.was != null && cr.was !== cr.i) requestAnimationFrame(() => requestAnimationFrame(() => $$('.chap6 i').forEach((s, i) => { s.classList.toggle('done', i < cr.i); s.classList.toggle('now', i === cr.i); })));
  cr.was = cr.i;
  cr.entered = true;
  const move = d => { if (d > 0 && !chapOk(k)) return; cr.dir = d; cr.was = cr.i; cr.i = clamp(cr.i + d, 0, CHAP.length - 1); buzz.tick(); render(); };
  $('#next').addEventListener('click', () => k === 'done' ? finishCreate() : move(1));
  $('#prev').addEventListener('click', () => move(-1));
}
function bindChap(root, k, onChange){
  const done = () => { updateCard(); onChange(); };
  holdable(root);
  if (k === 'name'){ const inp = $('#crName', root); inp.addEventListener('input', () => { cr.name = inp.value; done(); }); if (!cr.name) setTimeout(() => inp.focus({preventScroll:true}), 400); }
  const pickIn = (sel, set) => $$(sel, root).forEach(b => b.addEventListener('click', () => { set(b); $$(sel, root).forEach(x => x.classList.toggle('on', x === b)); replay($('.tick, .tick6', b), 'stamp5'); buzz.tick(); done();
    if (b.classList.contains('dc')) b.scrollIntoView({inline:'center', block:'nearest', behavior:reduced ? 'auto' : 'smooth'}); }));
  if (k === 'race'){
    pickIn('[data-race]', b => { const was = crRace(); cr.race = b.dataset.race; cr.sub = null; const r = crRace(), rev = $('#subs', root), inner = $('#subsIn', root);
      if (r.subs && was?.subs && rev.classList.contains('open')){ flip(inner, () => { inner.innerHTML = subsHTML(); }); stagger($('.picks', inner)); bindSubs(); }
      else if (r.subs){ inner.innerHTML = subsHTML(); bindSubs(); requestAnimationFrame(() => rev.classList.add('open')); stagger($('.picks', inner)); }
      else { rev.classList.remove('open'); setTimeout(() => { if (!crRace()?.subs) inner.innerHTML = ''; }, 520); } });
    const bindSubs = () => $$('[data-subr]', root).forEach(b => b.addEventListener('click', () => { cr.sub = b.dataset.subr; $$('[data-subr]', root).forEach(x => x.classList.toggle('on', x === b)); replay($('.tick6', b), 'stamp5'); buzz.tick(); done(); }));
    bindSubs();
  }
  if (k === 'class') pickIn('[data-cls]', b => { if (cr.cls !== b.dataset.cls){ cr.skills = []; cr.style = null; cr.cantrips = []; cr.pkg = null; } cr.cls = b.dataset.cls; });
  if (k === 'bg') pickIn('[data-bg]', b => { cr.bg = b.dataset.bg; cr.skills = cr.skills.filter(s => !crBg().sk.includes(s)); });
  if (k === 'skills') $$('[data-skill]', root).forEach(b => b.addEventListener('click', () => { if (b.classList.contains('off')) return; const n = b.dataset.skill;
    if (cr.skills.includes(n)) cr.skills = cr.skills.filter(x => x !== n);
    // Over the limit the earliest pick gives way to the new one.
    else { if (cr.skills.length >= skillNeed()) { const first = cr.skills.shift(); $(`[data-skill="${first}"]`, root).classList.remove('on'); } cr.skills.push(n); }
    b.classList.toggle('on', cr.skills.includes(n)); replay(b, 'stamp5'); setOdo($('#skn', root).firstElementChild, cr.skills.length); buzz.tick(); done(); }));
  if (k === 'feat'){
    pickIn('[data-style]', b => { cr.style = b.dataset.style; });
    $$('[data-cant]', root).forEach(b => b.addEventListener('click', () => { const n = b.dataset.cant;
      if (cr.cantrips.includes(n)) cr.cantrips = cr.cantrips.filter(x => x !== n);
      else { if (cr.cantrips.length >= 3) { const first = cr.cantrips.shift(); $(`[data-cant="${first}"]`, root).classList.remove('on'); } cr.cantrips.push(n); }
      b.classList.toggle('on', cr.cantrips.includes(n)); replay(b, 'stamp5'); setOdo($('#cn', root).firstElementChild, cr.cantrips.length); buzz.tick(); done(); }));
  }
  if (k === 'gear') pickIn('[data-pkg]', b => { cr.pkg = b.dataset.pkg; });
  if (k === 'abil'){
    segment($('#mseg', root), b => { cr.method = b.dataset.v; cr.assign = {}; cr.pick = null; if (cr.method !== 'roll') cr.rolled = null; buzz.tick();
      const box = $('#abody', root); flip(box, () => paintAbil(root, onChange)); stagger(box); done(); });
    bindAbil(root, onChange);
  }
}
function finishCreate(){
  const h = {name:cr.name.trim(), race:(crSub() ? crSub().n + ' ' : '') + crRace().n.toLowerCase(), cls:cr.cls, lvl:1};
  buzz.medium();
  const card = $('#final');
  const land = () => { PARTY.push(h); arrived = h; stack = [{s:'lobby'}]; render(); toast(`${h.name} в отряде`); };
  if (reduced || !card) return land();
  card.animate([{transform:'none', opacity:1}, {transform:'translateY(-40px) scale(.55)', opacity:0}], {duration:420, easing:'cubic-bezier(.3,0,.8,.15)', fill:'forwards'}).onfinish = land;
}

/* ---------- controls panel ---------- */
function controls(){
  const at = cur().s;
  $('#controls').innerHTML = `<div class="opt"><span class="lbl">Экран</span><div class="heroes">${[['sheet', 'Лист героя'], ['levelup', 'Повышение'], ['history', 'История'], ['lobby', 'Отряд'], ['create', 'Создание']].map(([k, n]) =>
      `<button type="button" data-scr="${k}" aria-pressed="${k === at}">${n}</button>`).join('')}</div></div>
    <div class="opt"><span class="lbl">Повышение · сценарий</span><div class="heroes">${Object.entries(LV).map(([k, s]) => `<button type="button" data-scn="${k}" aria-pressed="${k === lvScn}">${s.label}</button>`).join('')}</div>
      <span class="hint">Вторая итерация: шапка «Восхождения» над листаемыми этапами. В мультиклассе этапы зависят от выбранного класса.</span></div>
    <div class="opt"><span class="lbl">Создание</span><span class="hint">«Пролог»: главы по порядку, карточка героя строится сверху. Удержание любой карточки выбора или кнопка «i» — полное описание.</span></div>
    <button type="button" class="toggle" id="redm" aria-checked="${reduced}"><span class="switch"></span>Меньше движения</button>`;
  const shut = () => { modal.innerHTML = ''; modal.style.pointerEvents = 'none'; };
  $$('[data-scr]').forEach(b => b.addEventListener('click', () => { const k = b.dataset.scr; buzz.tick(); shut();
    if (k === 'levelup'){ stack = [{s:'sheet'}]; startLevelup(); return; }
    if (k === 'create'){ stack = [{s:'lobby'}]; startCreate(); return; }
    stack = k === 'history' ? [{s:'sheet'}, {s:'history'}] : [{s:k}]; show(1); }));
  $$('[data-scn]').forEach(b => b.addEventListener('click', () => { lvScn = b.dataset.scn; SHEET = null; HISTORY = []; rollTo = null; buzz.tick(); shut();
    stack = [{s:'sheet'}]; if (at === 'levelup') startLevelup(); else show(1); }));
  $('#redm').addEventListener('click', e => { reduced = !reduced; document.body.classList.toggle('reduce', reduced); e.currentTarget.setAttribute('aria-checked', reduced); });
}
applyApp();
render();
