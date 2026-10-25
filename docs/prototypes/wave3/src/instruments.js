/* ================= Class instruments in combat ================= */
// The accepted wave 2 instruments (same markup and styles), mounted in a
// sheet when a feature is used from the arsenal: the hero applies an
// ability through its own widget, and the use pays for itself.
const byLvl = (l, steps) => { let v; for (const [from, x] of steps) if (l >= from) v = x; return v; };
const fuse = (n, at, cls = '') => `<div class="fuse ${cls}">${Array.from({length:n}, (_, i) => `<i class="${i < at - 1 ? 'burnt' : i === at - 1 ? 'now' : ''}"></i>`).join('')}</div>`;
const SWORD = `<svg class="swd" viewBox="0 0 40 120" aria-hidden="true"><defs><clipPath id="bladeC"><path d="M20 4 27 18v62H13V18z"/></clipPath><linearGradient id="shineG" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient></defs><path class="blade" d="M20 4 27 18v62H13V18z"/><g clip-path="url(#bladeC)"><rect class="shine" x="0" y="0" width="40" height="46" fill="url(#shineG)"/></g><rect class="guard" x="3" y="80" width="34" height="7" rx="3.5"/><rect class="grip" x="16" y="87" width="8" height="21" rx="3"/><circle class="pommel" cx="20" cy="112" r="5"/></svg>`;
const RINGS = `<svg class="rings" viewBox="0 0 80 80" aria-hidden="true"><circle cx="40" cy="40" r="9"/><circle cx="40" cy="40" r="20"/><circle cx="40" cy="40" r="31"/></svg>`;
const EYE = `<svg class="eyesvg" viewBox="0 0 120 70" aria-hidden="true"><circle class="rip r1" cx="60" cy="35" r="18"/><circle class="rip r2" cx="60" cy="35" r="18"/><g class="eyeg"><path class="lid" d="M8 35Q60-5 112 35Q60 75 8 35Z"/><circle class="iris" cx="60" cy="35" r="15"/><circle class="pupil" cx="60" cy="35" r="6"/></g><path class="lash" d="M8 35Q60 62 112 35"/></svg>`;
const MOVES = [['dash', 'Рывок', 'dash', 'Скорость удваивается до конца хода'], ['back', 'Отход', 'stepback', 'Перемещение не провоцирует атак'], ['hide', 'Засада', 'hood', 'Спрятаться: Скрытность к20 + 10'], ['hand', 'Руки', 'hand', 'Быстрые руки: предмет, ловкость рук или воровские инструменты']];

function instSheet(kicker, html, bind){
  openSheet(`<span class="bs-kicker">${kicker}</span><div class="stack inst-sheet">${html}</div>`, {onOpen(sh, close){ bind(sh, close); }, onClose(){ live(render); }});
}
// Finish a use: the widget plays its moment, then the sheet steps aside.
const settle = (close, ms = 620) => setTimeout(() => close(0, () => $$('.tok.spent').forEach(t => replay(t, 'flash'))), reduced ? 0 : ms);

/* ---------- paladin: vessel of light ---------- */
function palLay(){
  const r = H.res[0]; let amt = Math.max(1, Math.min(r.left, H.max - H.hp || 5));
  const W = r.left / r.max * 100, pw = Math.min(amt, r.left) / r.max * 100;
  instSheet('Действие · касание', `<div class="inst lay" style="--acc:var(--a2)" id="lay">
      <div class="inst-h"><span class="cap">Наложение рук</span><span class="used">${icon('heart')} ${H.hp} / ${H.max}</span></div>
      <div class="row" style="margin-top:12px;align-items:flex-end"><div style="white-space:nowrap">${odo(amt, 'amt', 'huge')}<span class="of">ОЗ</span></div>
        <span class="poolv" data-peek="Запас|${r.left} из ${r.max} до длительного отдыха">${icon('hand')}${odo(r.left, 'lay')}<small>/ ${r.max}</small></span></div>
      <div class="vessel" id="vessel" aria-label="Отмерить исцеление"><i class="liquid" style="width:${W}%"></i><i class="pour" style="left:${W - pw}%;width:${pw}%"></i><span class="knob" style="left:${W - pw}%">${icon('hand')}</span></div>
      <div class="hint c" style="margin-top:8px">Ведите пальцем по свету — отмерить</div>
      <div class="two" style="margin-top:10px"><button type="button" class="go" data-i="heal">${icon('heart')} Исцелить</button><button type="button" class="ghost" data-i="cure" ${r.left >= 5 ? '' : 'disabled'}>${icon('drop')} Очистить · 5</button></div></div>`,
    (sh, close) => {
      const v = $('#vessel', sh); let drag = false;
      const place = (x, snapEnd) => { const Wd = v.clientWidth, end = r.left / r.max * Wd, unit = Wd / r.max;
        const left = snapEnd ? end - amt * unit : clamp(x, 0, end - unit), a = clamp(Math.round((end - left) / unit), 1, r.left);
        $('.pour', v).style.left = left + 'px'; $('.pour', v).style.width = (end - left) + 'px'; $('.knob', v).style.left = left + 'px';
        if (a !== amt) { amt = a; buzz.tick(); setOdo($('[data-odo="amt"]', sh), a); } };
      v.addEventListener('pointerdown', e => { drag = true; v.classList.add('drag'); v.setPointerCapture(e.pointerId); place(e.clientX - v.getBoundingClientRect().left); });
      v.addEventListener('pointermove', e => drag && place(e.clientX - v.getBoundingClientRect().left));
      ['pointerup', 'pointercancel'].forEach(k => v.addEventListener(k, () => { if (!drag) return; drag = false; v.classList.remove('drag'); place(0, true); }));
      sh.addEventListener('click', e => { const b = e.target.closest('[data-i]'); if (!b) return;
        const n = b.dataset.i === 'cure' ? 5 : amt; snap(); payCost('act'); r.left -= n;
        $('.liquid', v).style.width = r.left / r.max * 100 + '%'; $('.pour', v).classList.add('rise'); setOdo($('[data-odo="lay"]', sh), r.left);
        if (b.dataset.i === 'heal') { const was = H.hp; H.hp = Math.min(H.max, H.hp + n); floatUp(v, `+${H.hp - was} ОЗ`, 'var(--heal)'); log(`Наложение рук: +${H.hp - was} ОЗ`, 'a2'); }
        else { log('Наложение рук: очищение', 'a2'); toast('Болезнь или яд излечены'); }
        buzz.light(); settle(close, 700); });
    });
}
/* ---------- paladin: channel divinity ---------- */
function palChannel(){
  const r = H.res[2], lit = C.effects.find(e => e.k === 'sacred');
  instSheet('Действие · канал клятвы', `<div class="inst holy" style="--acc:var(--a4)" id="holy">
      <div class="inst-h"><span class="cap">Божественный канал</span><span class="used">${r.left}/${r.max} · короткий отдых</span></div>
      <div class="chan3">
        <button type="button" class="cdv ${lit ? 'lit' : ''}" id="sacred" data-i="weapon" ${!r.left || lit ? 'disabled' : ''}>${SWORD}<b>Священное оружие</b><small>${lit ? `ещё ${lit.left} ${plural(lit.left, 'раунд', 'раунда', 'раундов')}` : '+5 к атаке · минута'}</small></button>
        <span class="cflame ${r.left ? '' : 'out'}">${icon('flame')}<small>${r.left}/1</small></span>
        <button type="button" class="cdv turn" id="unholy" data-i="turn" ${r.left ? '' : 'disabled'}>${RINGS}<b>Изгнание нечестивых</b><small>Сл ${ARSENAL.paladin.dc}</small></button></div>
      ${lit ? `<div style="margin-top:12px">${fuse(10, 11 - lit.left, 'gold')}</div>` : ''}</div>
      ${r.left ? '' : `<p class="hint c">Канал вернёт короткий отдых</p>`}`,
    (sh, close) => sh.addEventListener('click', e => { const b = e.target.closest('[data-i]'); if (!b || b.disabled) return;
      snap(); payCost('act'); r.left--; buzz.medium(); $('.cflame', sh).classList.add('out');
      if (b.dataset.i === 'weapon') { addEffect({k:'sacred', n:'Священное оружие', ic:'sword', acc:2, dur:10}); log('Священное оружие · минута', 'a2'); b.classList.add('lit'); replay(b, 'ignite'); }
      else { log(`Изгнание нечестивых · Сл ${ARSENAL.paladin.dc}`, 'a4'); replay(b, 'wave'); toast(`Изгнание нечестивых: спасбросок Мудрости Сл ${ARSENAL.paladin.dc}`); }
      settle(close, 900); }));
}
/* ---------- paladin: divine sense ---------- */
function palSense(){
  const r = H.res[1];
  instSheet('Действие · до конца следующего хода', `<button type="button" class="inst sense" style="--acc:var(--a4)" id="sense" data-i="sense">
      ${EYE}<span class="ft"><span class="cap">Божественное чувство</span><b>Открыть взор</b><span class="eyes">${Array.from({length:r.max}, (_, i) => `<i class="eye ${i < r.left ? '' : 'off'}"></i>`).join('')}</span></span></button>
      <p class="hint c">Небожители, исчадия и нежить в 60 фт. — где они и кто</p>`,
    (sh, close) => $('#sense', sh).addEventListener('click', e => { const b = e.currentTarget; if (b.classList.contains('open')) return;
      snap(); payCost('act'); r.left--; b.classList.add('open'); $('b', b).textContent = 'Глаза открыты'; $$('.eye', b)[r.left]?.classList.add('off'); replay(b, 'scan'); buzz.medium(); log('Божественное чувство', 'a4'); settle(close, 1100); }));
}
/* ---------- barbarian: rage ---------- */
function barbRage(){
  const on = C.effects.find(e => e.k === 'rage');
  instSheet(on ? 'Ярость идёт' : 'Бонусное действие', `<div class="inst barb ${on ? 'on' : ''} ${C.reckless ? 'reck' : ''}" style="--acc:var(--a0)" id="barb"><i class="heat"></i><i class="hazard"></i>
      <div class="inst-h"><span class="cap">${on ? 'В ярости' : 'Ярость'}</span><span class="used">без ограничений · 20 ур.</span></div>
      <div class="row" style="margin-top:12px;align-items:flex-end"><div class="claws">${Array.from({length:6}, () => '<i class="claw"></i>').join('')}</div>
        <div class="dmg"><span class="huge">+4</span><small>урон</small></div></div>
      <div class="rbadges"><span class="rb">${icon('shield')}<small>Стойкость</small></span><span class="rb">${icon('up')}<small>Сила</small></span><span class="rb">${icon('axe')}<small>Неукротимость</small></span></div>
      ${on ? `${fuse(10, 11 - on.left)}<div class="rctl"><button type="button" class="ghost" data-i="end">Конец ярости</button><div class="rnum"><small>осталось</small><span class="big">${on.left}</span><span class="of">раунд.</span></div></div>`
        : `<button type="button" class="hold" id="hold"><i class="fill"></i><span>Удерживайте — ярость</span></button>`}
      <button type="button" class="reck-t" role="switch" aria-checked="${!!C.reckless}" data-i="reckless"><span class="rk">${icon('strikes')}</span><b>Безрассудная атака</b><span class="switch"></span></button></div>`,
    (sh, close) => {
      const barb = $('#barb', sh);
      sh.addEventListener('click', e => { const b = e.target.closest('[data-i]'); if (!b) return;
        if (b.dataset.i === 'reckless') { C.reckless = !C.reckless; b.setAttribute('aria-checked', C.reckless); barb.classList.toggle('reck', C.reckless); if (C.reckless) replay(barb, 'jolt'); buzz.tick(); return; }
        if (b.dataset.i === 'end') { snap(); C.effects = C.effects.filter(x => x.k !== 'rage'); log('Ярость окончена', 'a0'); buzz.light(); settle(close, 200); } });
      const hold = $('#hold', sh); if (!hold) return;
      const fill = $('.fill', hold); let t0 = 0, raf = 0, ticks = 0;
      const tick = now => { const p = clamp((now - t0) / 650, 0, 1); fill.style.transform = `scaleX(${p})`;
        if (p > (ticks + 1) / 3 && ticks < 2) { ticks++; buzz.tick(); }
        if (p >= 1) { raf = 0; snap(); payCost('bonus'); addEffect({k:'rage', n:'Ярость', ic:'axe', acc:0, dur:10, resist:true}); log('Ярость!', 'a0'); buzz.medium();
          barb.classList.add('on'); replay(barb, 'flare'); $('span', hold).textContent = 'В ярости'; return settle(close, 900); }
        raf = requestAnimationFrame(tick); };
      hold.addEventListener('pointerdown', e => { t0 = performance.now(); ticks = 0; hold.setPointerCapture(e.pointerId); raf = requestAnimationFrame(tick); });
      const cancel = () => { if (!raf) return; cancelAnimationFrame(raf); raf = 0; const from = parseFloat((fill.style.transform.match(/[\d.]+/) || [0])[0]);
        new Spring(from, SPR.snappy, v => fill.style.transform = `scaleX(${Math.max(0, v)})`).to(0); };
      ['pointerup', 'pointercancel', 'pointerleave'].forEach(k => hold.addEventListener(k, cancel));
    });
}
/* ---------- rogue: cunning action and uncanny dodge ---------- */
function rogueCunning(){
  instSheet('Бонусное действие', `<div class="lite cun2" style="--acc:var(--a4)"><div class="inst-h"><span class="cap">Хитрое действие</span><span class="used">${C.used.bonus ? 'бонусное потрачено' : 'бонусное'}</span></div>
      <div class="moves">${MOVES.map(([k, n, ic, d]) => `<button type="button" class="mv" data-i="${k}" data-peek="${n}|${d}"><span class="mg">${icon(ic)}</span><b>${n}</b><span class="mvv" id="mv-${k}">${k === 'dash' ? `${odo(budget(), 'spd')} фт.` : k === 'hide' ? 'к20' : ''}</span></button>`).join('')}</div></div>`,
    (sh, close) => sh.addEventListener('click', e => { const b = e.target.closest('[data-i]'); if (!b || b.disabled) return; const k = b.dataset.i;
      snap(); payCost('bonus'); b.classList.add('on'); $$('.mv', sh).forEach(x => { if (x !== b) x.disabled = true; }); buzz.light();
      log(`Хитрое действие: ${$('b', b).textContent}`, 'a1');
      if (k === 'dash') { C.dash = true; setOdo($('[data-odo="spd"]', sh), budget()); return settle(close, 800); }
      if (k === 'hide') { const r = d20(); return tumble([$('#mv-hide', sh)], [r + 10], 20, () => { log(`Засада: Скрытность ${r + 10}`, 'a4'); settle(close, 900); }); }
      settle(close, 500); }));
}
function rogueDodge(){
  keypadSheet({kicker:'Реакция · Невероятное уклонение', title:'Урон по вам', onDone(n){ payCost('react'); log(`Уклонение: ${n} → ${Math.floor(n / 2)}`, 'a4'); damage(Math.floor(n / 2), null); }});
}
const INSTRUMENT = {loh:palLay, sacred:palChannel, sense:palSense, rage:barbRage, reckless:barbRage, cunning:rogueCunning, uncanny:rogueDodge};
