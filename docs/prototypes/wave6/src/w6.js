/* ================= Wave 6 · iteration 2: the hero grows — level-up, history, creation ================= */
// The palette code above (from wave 5) defines set, T, palette(), applyApp().
// Author's picks after the first round: level-up joins the «Восхождение» head
// with paged steps; creation goes on as «Пролог».

/* ---------- rules data (SRD 5.1, 2014) with what the detail sheets tell ---------- */
const AB = [['str', 'Сила', 'СИЛ'], ['dex', 'Ловкость', 'ЛОВ'], ['con', 'Телосложение', 'ТЕЛ'], ['int', 'Интеллект', 'ИНТ'], ['wis', 'Мудрость', 'МДР'], ['cha', 'Харизма', 'ХАР']];
const mod = v => Math.floor((v - 10) / 2);
const sgn = n => (n >= 0 ? '+' : '−') + Math.abs(n);
// Class sigils as in the app (classSigil in instrument_kit.dart).
const CLASSES = [
  {id:'barbarian', n:'Варвар', ic:'axe', acc:0, die:12, key:'Сила', saves:'Сила, Телосложение', d:'Ярость, чутьё опасности и защита без доспехов.', pri:['str', 'con', 'dex'],
    arm:'Лёгкие и средние доспехи, щиты', wpn:'Простое и воинское оружие', sk:'2 из 6', f:[['Ярость', 'Бонусным действием впадаете в ярость: преимущество на проверки Силы, +2 к урону, сопротивление дробящему, колющему и рубящему урону.', 'flame'], ['Защита без доспехов', 'Без доспеха КД равен 10 + модификатор Ловкости + модификатор Телосложения.', 'shield']]},
  {id:'bard', n:'Бард', ic:'note', acc:0, die:8, key:'Харизма', saves:'Ловкость, Харизма', d:'Вдохновение, магия слова и мастер на все руки.', pri:['cha', 'dex', 'con'],
    arm:'Лёгкие доспехи', wpn:'Простое оружие, ручные арбалеты, длинные и короткие мечи, рапиры', sk:'3 любых', f:[['Использование заклинаний', 'Заговоры и заклинания барда, Харизма — заклинательная характеристика.', 'magic'], ['Вдохновение барда', 'Бонусным действием даёте союзнику к6, который он прибавит к броску.', 'note']]},
  {id:'cleric', n:'Жрец', ic:'sun', acc:2, die:8, key:'Мудрость', saves:'Мудрость, Харизма', d:'Божественный домен, исцеление и канал божественности.', pri:['wis', 'con', 'str'],
    arm:'Лёгкие и средние доспехи, щиты', wpn:'Простое оружие', sk:'2 из 5', f:[['Использование заклинаний', 'Каждый день готовите заклинания жреца, Мудрость — заклинательная характеристика.', 'magic'], ['Божественный домен', 'Домен даёт заклинания и умения с 1-го уровня.', 'sun']]},
  {id:'druid', n:'Друид', ic:'tree', acc:3, die:8, key:'Мудрость', saves:'Интеллект, Мудрость', d:'Дикий облик и природная магия круга.', pri:['wis', 'con', 'dex'],
    arm:'Лёгкие и средние доспехи, щиты (не из металла)', wpn:'Дубинки, кинжалы, дротики, копья, серпы и др.', sk:'2 из 8', f:[['Друидический язык', 'Тайный язык друидов и знаки, которые видят только посвящённые.', 'leaf'], ['Использование заклинаний', 'Готовите заклинания друида, Мудрость — заклинательная характеристика.', 'magic']]},
  {id:'fighter', n:'Воин', ic:'sword', acc:3, die:10, key:'Сила или Ловкость', saves:'Сила, Телосложение', d:'Боевой стиль, второе дыхание и всплеск действий.', pri:['str', 'con', 'dex'],
    arm:'Все доспехи, щиты', wpn:'Простое и воинское оружие', sk:'2 из 8', f:[['Боевой стиль', 'Особая манера боя: выберите один стиль, он действует всегда.', 'sword'], ['Второе дыхание', 'Бонусным действием восстанавливаете 1к10 + уровень воина ОЗ. Раз до короткого или долгого отдыха.', 'heart']]},
  {id:'monk', n:'Монах', ic:'lotus', acc:2, die:8, key:'Ловкость, Мудрость', saves:'Сила, Ловкость', d:'Ци, боевые искусства и движение без доспехов.', pri:['dex', 'wis', 'con'],
    arm:'Нет', wpn:'Простое оружие, короткие мечи', sk:'2 из 6', f:[['Защита без доспехов', 'КД равен 10 + Ловкость + Мудрость без доспеха и щита.', 'shield'], ['Боевые искусства', 'Безоружные удары и оружие монаха используют Ловкость и к4.', 'lotus']]},
  {id:'paladin', n:'Паладин', ic:'shield', acc:1, die:10, key:'Сила, Харизма', saves:'Мудрость, Харизма', d:'Наложение рук, божественная кара и священная клятва.', pri:['str', 'cha', 'con'],
    arm:'Все доспехи, щиты', wpn:'Простое и воинское оружие', sk:'2 из 6', f:[['Божественное чувство', 'Чувствуете небожителей, исчадий и нежить в 60 футах.', 'eye'], ['Наложение рук', 'Запас исцеления: 5 × уровень паладина ОЗ на долгий отдых.', 'hand']]},
  {id:'ranger', n:'Следопыт', ic:'target', acc:3, die:10, key:'Ловкость, Мудрость', saves:'Сила, Ловкость', d:'Избранный враг, исследователь природы и охотник.', pri:['dex', 'wis', 'con'],
    arm:'Лёгкие и средние доспехи, щиты', wpn:'Простое и воинское оружие', sk:'3 из 8', f:[['Избранный враг', 'Преимущество на выслеживание и знания о выбранном виде врагов.', 'target'], ['Исследователь природы', 'В избранной местности путь не замедляется и группа не теряется.', 'track']]},
  {id:'rogue', n:'Плут', ic:'hood', acc:4, die:8, key:'Ловкость', saves:'Ловкость, Интеллект', d:'Скрытая атака, компетентность и хитрые действия.', pri:['dex', 'int', 'con'],
    arm:'Лёгкие доспехи', wpn:'Простое оружие, ручные арбалеты, длинные и короткие мечи, рапиры', sk:'4 из 11', tools:'Воровские инструменты', f:[['Компетентность', 'Удвоенный бонус мастерства к двум навыкам или воровским инструментам.', 'star'], ['Скрытая атака', '+1к6 урона раз в ход при преимуществе или союзнике рядом с целью.', 'hood'], ['Воровской жаргон', 'Тайный язык знаков и намёков.', 'quill']]},
  {id:'sorcerer', n:'Чародей', ic:'flame', acc:1, die:6, key:'Харизма', saves:'Телосложение, Харизма', d:'Врождённая магия и метамагия чародейства.', pri:['cha', 'con', 'dex'],
    arm:'Нет', wpn:'Кинжалы, дротики, пращи, боевые посохи, лёгкие арбалеты', sk:'2 из 6', f:[['Использование заклинаний', 'Известные заклинания, Харизма — заклинательная характеристика.', 'magic'], ['Происхождение чародея', 'Источник силы: например, драконья кровь.', 'flame']]},
  {id:'warlock', n:'Колдун', ic:'eye', acc:5, die:8, key:'Харизма', saves:'Мудрость, Харизма', d:'Покровитель, магия договора и таинственные воззвания.', pri:['cha', 'con', 'dex'],
    arm:'Лёгкие доспехи', wpn:'Простое оружие', sk:'2 из 7', f:[['Потусторонний покровитель', 'Договор с могущественным существом определяет умения.', 'eye'], ['Магия договора', 'Мало ячеек, но все наивысшего круга; восстанавливаются на коротком отдыхе.', 'magic']]},
  {id:'wizard', n:'Волшебник', ic:'wand', acc:4, die:6, key:'Интеллект', saves:'Интеллект, Мудрость', d:'Книга заклинаний, магическое восстановление и школы.', pri:['int', 'con', 'dex'],
    arm:'Нет', wpn:'Кинжалы, дротики, пращи, боевые посохи, лёгкие арбалеты', sk:'2 из 6', f:[['Использование заклинаний', 'Книга заклинаний: 6 заклинаний 1-го круга и 3 заговора.', 'magic'], ['Магическое восстановление', 'Раз в день после короткого отдыха возвращаете часть ячеек.', 'spark']]},
  {id:'runeguard', n:'Страж рун', ic:'gem', acc:5, die:10, key:'Сила, Интеллект', saves:'Телосложение, Интеллект', d:'Высекает руны на оружии и щитах.', pri:['str', 'int', 'con'], lib:'Домашние правила',
    arm:'Все доспехи, щиты', wpn:'Простое и воинское оружие', sk:'2 из 6', f:[['Руны силы', 'Две руны на выбор: огонь, камень, буря. Каждая — заряд на короткий отдых.', 'gem']]},
];
const clsOf = id => CLASSES.find(c => c.id === id);
const RACES = [
  {id:'human', n:'Человек', ic:'person', acc:1, d:'Самые приспособляемые и честолюбивые среди народов.', facts:['+1 ко всем', 'Скорость 30', 'Средний'], bonus:{str:1, dex:1, con:1, int:1, wis:1, cha:1},
    tr:[['Разносторонность', '+1 ко всем шести характеристикам.', 'stats'], ['Языки', 'Общий и ещё один на выбор.', 'quill']]},
  {id:'dwarf', n:'Дварф', ic:'peaks', acc:0, d:'Крепкие и упорные хранители гор и традиций.', facts:['Тел +2', 'Скорость 25', 'Тёмное зрение'], bonus:{con:2},
    tr:[['Тёмное зрение', 'В темноте видите на 60 футов как в тусклом свете.', 'eye'], ['Дварфийская устойчивость', 'Преимущество против яда и сопротивление урону ядом.', 'shield'], ['Знание камня', 'Удвоенный бонус мастерства к Истории о каменной кладке.', 'peaks']],
    subs:[{id:'hill', n:'Холмовой', bonus:{wis:1}, d:'Мдр +1 · +1 ОЗ на каждом уровне'}, {id:'mountain', n:'Горный', bonus:{str:2}, d:'Сил +2 · лёгкие и средние доспехи'}]},
  {id:'elf', n:'Эльф', ic:'leaf', acc:3, d:'Изящные и долгоживущие, с острым чутьём.', facts:['Лов +2', 'Скорость 30', 'Тёмное зрение'], bonus:{dex:2},
    tr:[['Обострённые чувства', 'Владение навыком Восприятие.', 'eye'], ['Наследие фей', 'Преимущество против очарования, магия не усыпляет.', 'spark'], ['Транс', 'Четыре часа медитации вместо сна.', 'moon']],
    subs:[{id:'high', n:'Высший', bonus:{int:1}, d:'Инт +1 · заговор волшебника'}, {id:'wood', n:'Лесной', bonus:{wis:1}, d:'Мдр +1 · скорость 35, маскировка'}]},
  {id:'halfling', n:'Халфлинг', ic:'heart', acc:2, d:'Маленькие и удачливые, любят уют и не боятся дорог.', facts:['Лов +2', 'Скорость 25', 'Везучий'], bonus:{dex:2}, lib:'Домашние правила',
    tr:[['Везучий', 'Единицу на к20 можно перебросить.', 'dice'], ['Храбрый', 'Преимущество против испуга.', 'heart'], ['Проворство', 'Проходите сквозь клетки больших существ.', 'run']]},
];
const BGS = [
  {id:'acolyte', n:'Прислужник', sk:['Проницательность', 'Религия'], d:'Служил при храме и знает его обряды.', feat:['Приют для верующих', 'Храмы вашей веры дают кров, лечение и помощь вам и спутникам.'], extra:'Два языка · символ веры, молитвенник, 15 зм'},
  {id:'soldier', n:'Солдат', sk:['Атлетика', 'Запугивание'], d:'Прошёл войну и не забыл её уроков.', feat:['Воинское звание', 'Бывшие сослуживцы и солдаты вашей армии признают ваш чин.'], extra:'Игровой набор, транспорт · знаки отличия, 10 зм'},
  {id:'folk', n:'Народный герой', sk:['Уход за животными', 'Выживание'], d:'Вышел из простых людей и встал за них.', feat:['Деревенское гостеприимство', 'Простой люд укроет вас и спрячет от погони.'], extra:'Ремесленный инструмент, транспорт · лопата, котёл, 10 зм'},
  {id:'sage', n:'Мудрец', sk:['Магия', 'История'], d:'Годы в библиотеках: знает, где искать ответ.', feat:['Исследователь', 'Знаете, где и у кого узнать то, чего не знаете сами.'], extra:'Два языка · чернила, перо, письмо от покойного коллеги, 10 зм', lib:'Домашние правила'},
];
const SKILLS = {
  fighter:[2, ['Акробатика', 'Уход за животными', 'Атлетика', 'История', 'Проницательность', 'Запугивание', 'Восприятие', 'Выживание']],
  wizard:[2, ['Магия', 'История', 'Проницательность', 'Анализ', 'Медицина', 'Религия']],
  rogue:[4, ['Акробатика', 'Атлетика', 'Обман', 'Проницательность', 'Запугивание', 'Анализ', 'Восприятие', 'Выступление', 'Убеждение', 'Ловкость рук', 'Скрытность']],
  _:[2, ['Атлетика', 'Проницательность', 'Восприятие', 'Выживание', 'Убеждение', 'Медицина']],
};
const STYLES = [['Оборона', 'КД +1, пока вы в доспехе.'], ['Дуэлянт', '+2 к урону, когда в одной руке оружие, а в другой ничего.'], ['Стрельба', '+2 к броскам атаки дальнобойным оружием.'],
  ['Сражение большим оружием', 'Перебрасываете 1 и 2 на костях урона двуручным оружием.'], ['Защита', 'Реакцией создаёте помеху атаке по союзнику рядом, если у вас щит.'], ['Сражение двумя оружиями', 'Добавляете модификатор характеристики к урону второй атаки.']];
const CANTRIPS = [['Огненный снаряд', '1к10 урона огнём на 120 футов.'], ['Свет', 'Предмет светит как факел час.'], ['Волшебная рука', 'Призрачная рука переносит до 10 фунтов.'],
  ['Луч холода', '1к8 урона холодом и −10 к скорости цели.'], ['Фокусы', 'Мелкие магические чудеса.'], ['Брызги кислоты', '1к6 урона кислотой одной или двум целям.'], ['Малая иллюзия', 'Звук или образ на минуту.']];
const TOOLS = {thieves:['Воровские инструменты', 'Напильник, отмычки, зеркальце на ручке, ножницы и щипцы. Владение позволяет добавлять бонус мастерства к проверкам вскрытия замков и обезвреживания ловушек.', 'key']};
const GAINS = {
  asi:['Увеличение характеристик', '+2 к одной характеристике или +1 к двум, не выше 20. Вместо этого можно взять черту.', 'stats'],
  third:['Заклинания 3-го круга', 'Открываются ячейки 3-го круга: две на долгий отдых. В книгу можно вписать заклинания до 3-го круга.', 'magic'],
  health:['Божественное здоровье', 'Божественная магия защищает вас: иммунитет к болезням.', 'heart'],
  oath:['Священная клятва', 'Клятва определяет заклинания, канал божественности и умения на 7, 15 и 20-м уровнях.', 'shield'],
  sneak:['Скрытая атака', 'Раз в ход +1к6 урона атакой с преимуществом или когда союзник стоит рядом с целью. Оружие — фехтовальное или дальнобойное.', 'hood'],
  cant:['Воровской жаргон', 'Тайная смесь жаргона, знаков и символов: передаёте скрытые послания посреди разговора.', 'quill'],
  extra:['Дополнительная атака', 'Действием Атака совершаете две атаки вместо одной.', 'sword'],
  domain:['Божественный домен', 'Домен даёт заклинания домена, всегда подготовленные, и умения с 1-го уровня.', 'sun'],
};

/* ---------- the four level-up stories ---------- */
const LV = {
  fighter:{label:'Воин 3 → 4', hero:{name:'Брам', race:'Человек', cls:'fighter', lvl:3, hp:28, con:2, ab:{str:16, dex:15, con:14, int:11, wis:13, cha:9}, ac:18, skills:['Атлетика', 'Восприятие']}, to:4, prof:[2, 2]},
  wizard:{label:'Волшебник 4 → 5', hero:{name:'Илва', race:'Эльф', cls:'wizard', lvl:4, hp:26, con:1, ab:{str:8, dex:15, con:13, int:17, wis:12, cha:10}, ac:12, skills:['Магия', 'Анализ']}, to:5, prof:[2, 3], learn:2, slots:[[4, 3], [4, 3, 2]]},
  paladin:{label:'Паладин 2 → 3', hero:{name:'Элиан', race:'Человек', cls:'paladin', lvl:2, hp:20, con:1, ab:{str:16, dex:10, con:13, int:9, wis:12, cha:15}, ac:18, skills:['Атлетика', 'Убеждение']}, to:3, prof:[2, 2], slots:[[2], [3]]},
  multi:{label:'Мультикласс: Воин 4 + ?', hero:{name:'Брам', race:'Человек', cls:'fighter', lvl:4, hp:38, con:2, ab:{str:17, dex:15, con:14, int:11, wis:13, cha:9}, ac:18, skills:['Атлетика', 'Восприятие']}, to:5, prof:[2, 3]},
};
const STEP = {cls:['Класс', 'swap'], prof:['Владения', 'target'], hp:['ОЗ', 'heart'], asi:['Характеристики', 'stats'], feat:['Умения', 'star'], magic:['Магия', 'magic'], sum:['Итог', 'check']};
const SPELLS6 = [[3, 'Огненный шар', 'Воплощение', 'Взрыв в радиусе 20 футов: 8к6 огнём, спасбросок Ловкости вдвое.'], [3, 'Контрзаклинание', 'Ограждение', 'Реакцией прерываете чужое заклинание до 3-го круга.'],
  [3, 'Полёт', 'Преобразование', 'Цель летает со скоростью 60 футов, концентрация до 10 минут.'], [3, 'Ускорение', 'Преобразование', 'Удвоенная скорость, +2 КД, дополнительное действие.'],
  [3, 'Молния', 'Воплощение', 'Линия 100 футов: 8к6 электричеством.'], [3, 'Рассеивание магии', 'Ограждение', 'Оканчивает заклинания на цели.'],
  [2, 'Туманный шаг', 'Вызов', 'Бонусным действием телепортируетесь на 30 футов.'], [2, 'Невидимость', 'Иллюзия', 'Цель невидима до атаки или заклинания.'], [2, 'Паутина', 'Вызов', 'Липкая паутина опутывает существ в кубе 20 футов.'],
  [1, 'Щит', 'Ограждение', '+5 КД реакцией до вашего хода.', true], [1, 'Волшебная стрела', 'Воплощение', 'Три дротика по 1к4 + 1, всегда попадают.', true]];
const FEATS = [['Борец', 'Преимущество на атаки по схваченному вами существу; можно попытаться удержать его.', 'SRD'], ['Неутомимый', '+1 Тел; кость хитов на коротком отдыхе восстанавливает не меньше удвоенного модификатора Телосложения.', 'Домашние правила'],
  ['Наблюдательный', '+1 Инт или Мдр; +5 к пассивным Восприятию и Анализу, читаете по губам.', 'Домашние правила']];
const OATHS = [{n:'Клятва преданности', src:'SRD', acc:1, d:'Честь, правосудие и защита слабых.', in:[['Священное оружие', 'Канал божественности: оружие светится и получает + Харизму к атакам на минуту.', 'bolt'], ['Изгнание нечестивых', 'Канал божественности: исчадия и нежить бегут от вас.', 'sun'], ['Защита от зла и добра', 'Заклинание клятвы, всегда подготовлено.', 'magic'], ['Убежище', 'Заклинание клятвы, всегда подготовлено.', 'magic']]},
  {n:'Клятва мести', src:'Домашние правила', acc:0, d:'Покарать тех, кто совершил великое зло.', in:[['Отречение врага', 'Канал божественности: пугает врага и обнуляет его скорость.', 'bolt'], ['Обет вражды', 'Канал божественности: преимущество на атаки по одной цели минуту.', 'target'], ['Метка охотника', 'Заклинание клятвы, всегда подготовлено.', 'magic'], ['Сон', 'Заклинание клятвы, всегда подготовлено.', 'magic']]}];
const DOMAINS = [{n:'Домен жизни', src:'SRD', acc:2, d:'Сила исцеления и жизненной энергии.', in:[['Ученик жизни', 'Лечащие заклинания восстанавливают на 2 + круг ОЗ больше.', 'heart'], ['Тяжёлые доспехи', 'Владение тяжёлыми доспехами.', 'shield'], ['Благословение, Лечение ран', 'Заклинания домена, всегда подготовлены.', 'magic']]}];
const MC = [{id:'fighter', cont:true}, {id:'rogue', req:'Ловкость 13', ok:true}, {id:'wizard', req:'Интеллект 13', ok:false}, {id:'cleric', req:'Мудрость 13', ok:true}];
const ROGUE_SK = ['Акробатика', 'Обман', 'Анализ', 'Скрытность', 'Ловкость рук', 'Восприятие'];

/* ---------- navigation ---------- */
let stack = [{s:'sheet'}], lvScn = 'fighter';
const cur = () => stack[stack.length - 1];
function go(screen){ stack.push(screen); buzz.tick(); show(1); }
function back(){ if (stack.length < 2) return; stack.pop(); buzz.tick(); show(-1); }
function show(dir = 0){
  render();
  const page = $('#app .page5, #app .page6');
  if (!dir || reduced || !page) return;
  page.animate([{transform:`translateX(${dir * 36}px)`, opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.snappy, .42)});
}
function render(){
  const s = cur();
  $('#app').innerHTML = {sheet:sheetHTML, lobby:lobbyHTML, levelup:levelupHTML, history:historyHTML, create:createHTML}[s.s](s);
  ({sheet:() => {}, lobby:bindLobby, levelup:bindLevelup, history:bindHistory, create:bindCreate})[s.s](s);
  controls();
}
document.addEventListener('scroll', e => { if (!e.target.classList?.contains('scroller')) return;
  const bar = $('#app .top5'); if (bar && !bar.classList.contains('pinned')) bar.classList.toggle('titled', e.target.scrollTop > 90); }, true);
const top5 = (title, {lead = 'back', actions = ''} = {}) => `<div class="top5 glass">
  ${lead ? `<button type="button" class="round" data-a="${lead}" aria-label="${lead === 'back' ? 'Назад' : 'Закрыть'}">${icon(lead === 'back' ? 'back' : 'x')}</button>` : '<span class="sp40"></span>'}
  <div class="tb-title">${title}</div>${actions || '<span class="sp40"></span>'}</div>`;
const seal5 = (ic, acc, cls = '') => `<span class="seal5 ${cls}" style="--acc:var(--a${acc})">${icon(ic)}</span>`;
const av = (h, cls = '') => `<span class="av6 ${cls}" style="--acc:var(--a${clsOf(h.cls).acc})">${h.name[0] || '?'}</span>`;
const info = key => `<span class="info6" role="button" tabindex="0" data-info="${key}" aria-label="Подробнее">${icon('info')}</span>`;
document.addEventListener('click', e => {
  const i = e.target.closest('[data-info]'); if (i && i.closest('#app, #modal')) { e.stopPropagation(); e.preventDefault(); buzz.light(); return openInfo(i.dataset.info); }
  const t = e.target.closest('[data-a]'); if (!t || !t.closest('#app')) return;
  const a = t.dataset.a;
  if (a === 'back' || a === 'close') return back();
  if (a === 'levelup') return startLevelup();
  if (a === 'history') return go({s:'history'});
  if (a === 'create') return startCreate();
}, true);

/* ---------- details: a long press or the «i» opens what a choice really is ---------- */
// Long press: a ring fills under the finger, then the sheet opens and the tap
// that would have followed is swallowed.
function holdable(root = document){
  $$('[data-hold6]', root).forEach(el => {
    if (el.dataset.holdBound) return; el.dataset.holdBound = 1;
    let t = 0;
    el.addEventListener('pointerdown', () => { el.classList.add('pressing'); t = setTimeout(() => { el.classList.remove('pressing'); el.dataset.held = 1; buzz.medium(); openInfo(el.dataset.hold6); }, reduced ? 380 : 480); });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => el.addEventListener(ev, () => { clearTimeout(t); el.classList.remove('pressing'); }));
    el.addEventListener('click', e => { if (el.dataset.held) { delete el.dataset.held; e.stopImmediatePropagation(); e.preventDefault(); } }, true);
    el.addEventListener('contextmenu', e => e.preventDefault());
  });
}
function infoOf(key){
  const [kind, id] = key.split(':');
  if (kind === 'class'){ const c = clsOf(id);
    return {kicker:c.lib ? `Класс · ${c.lib}` : 'Класс · SRD', title:c.n, ic:c.ic, acc:c.acc, text:c.d,
      facts:[`Кость хитов к${c.die}`, `Основная: ${c.key}`, `Спасброски: ${c.saves}`],
      rows:[['Доспехи', c.arm, 'shield'], ['Оружие', c.wpn, 'sword'], ...(c.tools ? [['Инструменты', c.tools, 'key']] : []), ['Навыки', c.sk, 'target']],
      feats:c.f, featsTitle:'На 1-м уровне'}; }
  if (kind === 'race'){ const r = RACES.find(x => x.id === id);
    return {kicker:r.lib ? `Народ · ${r.lib}` : 'Народ · SRD', title:r.n, ic:r.ic, acc:r.acc, text:r.d, facts:r.facts, feats:[...r.tr, ...(r.subs || []).map(s => [`Разновидность: ${s.n}`, s.d, 'person'])], featsTitle:'Особенности'}; }
  if (kind === 'bg'){ const b = BGS.find(x => x.id === id);
    return {kicker:b.lib ? `Предыстория · ${b.lib}` : 'Предыстория · SRD', title:b.n, ic:'book', acc:5, text:b.d, facts:b.sk.map(s => 'Навык: ' + s),
      feats:[[b.feat[0], b.feat[1], 'star']], featsTitle:'Умение предыстории', rows:[['Ещё', b.extra, 'bag']]}; }
  if (kind === 'gain'){ const g = GAINS[id]; return {kicker:'Умение', title:g[0], ic:g[2], acc:lv ? lvAcc() : 1, text:g[1]}; }
  if (kind === 'feature'){ const [c, i] = id.split('.'), f = clsOf(c).f[+i]; return {kicker:`Умение · ${clsOf(c).n}`, title:f[0], ic:f[2], acc:clsOf(c).acc, text:f[1]}; }
  if (kind === 'tool'){ const t = TOOLS[id]; return {kicker:'Владение инструментом', title:t[0], ic:t[2], acc:4, text:t[1]}; }
  if (kind === 'sub'){ const o = [...OATHS, ...DOMAINS].find(x => x.n === id); return {kicker:o.src === 'SRD' ? 'Подкласс · SRD' : `Подкласс · ${o.src}`, title:o.n, ic:OATHS.includes(o) ? 'shield' : 'sun', acc:o.acc, text:o.d, feats:o.in, featsTitle:'Что даёт'}; }
  if (kind === 'feat'){ const f = FEATS.find(x => x[0] === id); return {kicker:`Черта · ${f[2]}`, title:f[0], ic:'star', acc:2, text:f[1]}; }
  if (kind === 'spell'){ const s = SPELLS6.find(x => x[1] === id); return {kicker:`${s[0]}-й круг · ${s[2]}`, title:s[1], ic:'magic', acc:5, text:s[3]}; }
  if (kind === 'cantrip'){ const s = CANTRIPS.find(x => x[0] === id); return {kicker:'Заговор · волшебник', title:s[0], ic:'magic', acc:4, text:s[1]}; }
  if (kind === 'style'){ const s = STYLES.find(x => x[0] === id); return {kicker:'Боевой стиль', title:s[0], ic:'sword', acc:3, text:s[1]}; }
  if (kind === 'pkg') return pkgInfo(id);
  return {kicker:'', title:key, ic:'info', acc:1, text:''};
}
function openInfo(key){
  const d = infoOf(key);
  openSheet(`<div class="ihead" style="--acc:var(--a${d.acc})">${seal5(d.ic, d.acc, 'lg')}<span class="ft"><span class="cap" style="--acc:var(--a${d.acc})">${d.kicker}</span><h2 class="bs-title">${d.title}</h2></span></div>
    ${d.text ? `<p class="itext">${d.text}</p>` : ''}
    ${d.facts ? `<div class="chips6">${d.facts.map(f => `<span class="fact6">${f}</span>`).join('')}</div>` : ''}
    ${d.rows ? `<div class="irows">${d.rows.map(([h, v, ic]) => `<div class="irow">${icon(ic)}<span class="ft"><small>${h}</small><b>${v}</b></span></div>`).join('')}</div>` : ''}
    ${d.feats ? `<div class="grp6"><b>${d.featsTitle}</b></div><div class="gain6">${d.feats.map(([n, t, ic]) => `<div class="gainc" style="--acc:var(--a${d.acc})">${seal5(ic, d.acc, 'sm')}<span class="ft"><b>${n}</b><small>${t}</small></span></div>`).join('')}</div>` : ''}
    ${d.list ? `<div class="irows">${d.list.map(([n, q, t, ic]) => `<div class="irow">${icon(ic)}<span class="ft"><b>${n}${q ? ` <em>× ${q}</em>` : ''}</b><small>${t}</small></span></div>`).join('')}</div>` : ''}`);
}

/* ---------- motion helpers ---------- */
// A value flies from one place to another as a small token.
function fly(from, to, html, done){
  if (reduced || !from || !to){ done && done(); return; }
  const ph = $('#phone').getBoundingClientRect(), a = from.getBoundingClientRect(), b = to.getBoundingClientRect();
  const el = document.createElement('div');
  el.className = 'flyer'; el.innerHTML = html;
  Object.assign(el.style, {left:a.left - ph.left + 'px', top:a.top - ph.top + 'px', width:a.width + 'px', height:a.height + 'px'});
  $('#phone').appendChild(el);
  const dx = b.left + b.width / 2 - (a.left + a.width / 2), dy = b.top + b.height / 2 - (a.top + a.height / 2);
  el.animate([{transform:'none'}, {transform:`translate(${dx * .5}px, ${dy * .5 - 30}px) scale(1.12)`, offset:.5}, {transform:`translate(${dx}px, ${dy}px) scale(.8)`, opacity:.2}],
    {duration:460, easing:'cubic-bezier(.3,0,.2,1)'}).onfinish = () => { el.remove(); done && done(); };
}
// Re-lays a block out and lets everything that moved glide from where it was.
function flip(root, change){
  if (!root || reduced){ change(); return; }
  const keyed = el => Object.fromEntries($$('[data-k]', el).map(x => [x.dataset.k, x.getBoundingClientRect()]));
  const h0 = root.offsetHeight, r0 = keyed(root);
  change();
  const h1 = root.offsetHeight;
  if (h0 !== h1) root.animate([{height:h0 + 'px', overflow:'hidden'}, {height:h1 + 'px', overflow:'hidden'}], {duration:420, easing:springEasing(SPR.gentle, .42)});
  $$('[data-k]', root).forEach(x => { const r = r0[x.dataset.k], n = x.getBoundingClientRect();
    if (!r) return x.animate([{transform:'scale(.6)', opacity:0}, {transform:'none', opacity:1}], {duration:420, easing:springEasing(SPR.snappy, .42)});
    const dx = r.left - n.left, dy = r.top - n.top;
    if (dx || dy) x.animate([{transform:`translate(${dx}px, ${dy}px)`}, {transform:'none'}], {duration:460, easing:springEasing(SPR.gentle, .46)}); });
}
// Children of a freshly shown block arrive one after another.
function stagger(root, sel = ':scope > *'){
  if (reduced || !root) return;
  $$(sel, root).forEach((el, i) => el.animate([{transform:'translateY(14px)', opacity:0}, {transform:'none', opacity:1}], {duration:420, delay:40 + i * 45, easing:springEasing(SPR.snappy, .42), fill:'backwards'}));
}

/* ---------- the hero's sheet (stub) ---------- */
let SHEET = null;
const sheetHero = () => SHEET || (SHEET = {...LV[lvScn].hero, ab:{...LV[lvScn].hero.ab}, skills:[...LV[lvScn].hero.skills], classes:[[LV[lvScn].hero.cls, LV[lvScn].hero.lvl]]});
function sheetHTML(){
  const h = sheetHero(), c = clsOf(h.cls);
  return `${top5('Лист героя', {lead:''})}
  <div class="scroller"><div class="page5 sheet6">
    <div class="hhead" style="--acc:var(--a${c.acc})">
      <div class="row">${av(h, 'lg')}<span class="ft"><b class="nm">${h.name}</b><small>${h.race} · ${h.classes.map(([id, l]) => `${clsOf(id).n} ${l}`).join(' / ')}</small></span></div>
      <div class="row" style="justify-content:space-between"><span class="lvchip">Уровень <b class="num">${h.lvl}</b><button type="button" class="up" data-a="levelup">${icon('up')}Повысить</button></span>
        <button type="button" class="round" data-a="history" aria-label="История развития">${icon('calendar')}</button></div>
      <div class="statl"><span><b class="num">${h.hp}</b><small>ОЗ максимум</small></span><span><b class="num">${h.ac}</b><small>КД</small></span><span><b class="num">+${2 + Math.floor((h.lvl - 1) / 4)}</b><small>Мастерство</small></span></div>
    </div>
    <p class="hint5">${icon('info')} Набросок листа героя — отсюда открываются повышение и история развития. Сценарий выбирается справа.</p>
    <button type="button" class="row5 tap" data-a="history">${seal5('calendar', 5)}<span class="ft"><b>История развития</b><small>Уровни, решения и откат</small></span>${icon('fwd', 'chev')}</button>
  </div></div>`;
}

/* ---------- the party (stub for creation) ---------- */
const PARTY = [{name:'Элиан', race:'Человек', cls:'paladin', lvl:18}, {name:'Илва', race:'Эльф', cls:'wizard', lvl:5}];
let arrived = null;
function lobbyHTML(){
  return `${top5('Отряд', {lead:''})}
  <div class="scroller"><div class="page5">
    <header class="mh"><span class="cap" style="--acc:var(--a1)">QDnD · отряд</span><h1>Отряд</h1><p class="sub5">Набросок лобби — отсюда начинается создание героя.</p></header>
    <div class="lob6">${PARTY.map(h => `<div class="lcard ${arrived === h ? 'arrive' : ''}" style="--acc:var(--a${clsOf(h.cls).acc})">${av(h)}<span class="ft"><b>${h.name}</b><small>${h.race} · ${clsOf(h.cls).n} ${h.lvl}</small></span></div>`).join('')}</div>
    <button type="button" class="addhero" data-a="create">${icon('plus')}<span>Создать героя</span></button>
  </div></div>`;
}
function bindLobby(){ arrived = null; }

/* ================= Level-up: the «Восхождение» head over paged steps ================= */
let lv = null;
function startLevelup(){
  lv = {S:LV[lvScn], step:0, hp:{m:null, gain:null, roll:null}, asi:{mode:'ab', pts:{}, feat:null}, sub:null, spells:new Set(), skill:null, cls:null};
  go({s:'levelup'});
}
const lvHero = () => sheetHero();
// The class this level goes to: the hero's own, or the one picked to multiclass.
const lvClassId = () => lvScn === 'multi' ? lv.cls : lv.S.hero.cls;
const lvClass = () => lvClassId() ? clsOf(lvClassId()) : null;
const lvAcc = () => (lvClass() || clsOf(lv.S.hero.cls)).acc;
const dieOf = () => (lvClass() || clsOf(lv.S.hero.cls)).die;
// What this level brings depends on the class it goes to.
function lvSteps(){
  if (lvScn === 'fighter') return ['hp', 'asi', 'sum'];
  if (lvScn === 'wizard') return ['hp', 'magic', 'sum'];
  if (lvScn === 'paladin') return ['hp', 'feat', 'magic', 'sum'];
  const tail = {rogue:['prof', 'hp', 'feat'], cleric:['prof', 'hp', 'feat'], fighter:['hp', 'feat']}[lv.cls] || ['hp', 'feat'];
  return ['cls', ...tail, 'sum'];
}
function lvGains(){
  if (lvScn === 'fighter') return ['asi'];
  if (lvScn === 'wizard') return ['third'];
  if (lvScn === 'paladin') return ['health', 'oath'];
  return {rogue:['sneak', 'cant'], cleric:['domain'], fighter:['extra']}[lv.cls] || [];
}
const ptsUsed = () => Object.values(lv.asi.pts).reduce((s, v) => s + v, 0);
function resolved(k){
  if (k === 'hp') return lv.hp.gain != null;
  if (k === 'asi') return lv.asi.mode === 'ab' ? ptsUsed() === 2 : !!lv.asi.feat;
  if (k === 'feat') return !(lvScn === 'paladin' || lv.cls === 'cleric') || !!lv.sub;
  if (k === 'magic') return lvScn !== 'wizard' || lv.spells.size === lv.S.learn;
  if (k === 'prof') return lv.cls !== 'rogue' || !!lv.skill;
  if (k === 'cls') return !!lv.cls;
  return true;
}
function stepHint(k){
  const h = {hp:() => 'Выберите, как растут ОЗ', asi:() => lv.asi.mode === 'ab' ? `Осталось очков: ${2 - ptsUsed()}` : 'Выберите черту', feat:() => lvScn === 'paladin' ? 'Выберите клятву' : 'Выберите домен',
    magic:() => `Выберите ещё ${lv.S.learn - lv.spells.size}`, prof:() => 'Выберите навык плута', cls:() => 'Выберите класс'}[k];
  return h ? h() : '';
}
const HEADS = {hp:['Как растут ОЗ', 'Среднее надёжно, бросок — азартно, своя кость — если бросали за столом.'],
  asi:['Улучшение характеристик', 'Два очка: оба в одну характеристику или по одному в две. Или черта вместо них.'],
  feat:['Новые умения', 'Что открывает этот уровень. Карточку можно открыть целиком: касание или удержание.'],
  magic:['Магия класса', ''], prof:['Владения', 'Что даёт новый класс при мультиклассе.'], cls:['В какой класс?', 'Продолжить свой класс или открыть новый. Удержание карточки — полное описание класса.'],
  sum:['Итог повышения', 'Проверьте изменения листа перед подтверждением.']};

/* --- the bodies of the steps --- */
const tick = `<i class="tick6">${icon('check')}</i>`;
function stepBody(k){
  const h = lvHero(), S = lv.S, acc = lvAcc();
  if (k === 'cls') return `<div class="picks">${MC.map(m => { const c = clsOf(m.id), lvl = m.cont ? h.lvl : 0;
    return `<button type="button" class="pick6 card6 ${lv.cls === m.id ? 'on' : ''} ${m.ok === false ? 'blocked' : ''}" data-cls="${m.id}" data-hold6="class:${m.id}" ${m.ok === false ? 'aria-disabled="true"' : ''} style="--acc:var(--a${c.acc})">
      <span class="ph">${seal5(c.ic, c.acc, 'lg')}<span class="ft"><b>${c.n} ${m.cont ? `${lvl} → ${lvl + 1}` : '1'}</b><small>${m.cont ? 'Продолжить свой класс' : m.ok ? `Новый класс · ${m.req} ✓` : `Нужно: ${m.req} · у Брама 11`}</small></span>${info('class:' + m.id)}${tick}</span>
      <span class="chips6"><span class="fact6">к${c.die}</span><span class="fact6">${c.key}</span>${m.cont ? '<span class="fact6">Дополнительная атака</span>' : ''}</span></button>`; }).join('')}</div>
    <p class="hint5">${icon('info')} Требования мультикласса проверяются по характеристикам героя.</p>`;
  if (k === 'prof'){
    if (lv.cls === 'cleric') return `<div class="gain6">${[['Лёгкие доспехи', 'shield'], ['Средние доспехи', 'shield'], ['Щиты', 'shield']].map(([n, ic]) => `<div class="gainc" style="--acc:var(--a2)">${seal5(ic, 2)}<span class="ft"><b>${n}</b><small>Владение, получено автоматически</small></span><span class="got6">${icon('check')}</span></div>`).join('')}</div>
      <p class="hint5">${icon('info')} При мультиклассе жрец даёт доспехи и щиты, но не навыки.</p>`;
    return `<div class="grp6"><b>Инструмент</b><small>получен</small></div>
      <button type="button" class="gainc tap6" data-info="tool:thieves" style="--acc:var(--a4)">${seal5('key', 4)}<span class="ft"><b>Воровские инструменты</b><small>Отмычки и напильники: вскрытие замков и ловушки</small></span><span class="got6">${icon('check')}</span></button>
      <div class="grp6"><b>Навык плута</b><small data-skc>${lv.skill ? 1 : 0} из 1</small></div>
      <div class="chips6">${ROGUE_SK.map(n => { const known = h.skills.includes(n);
        return `<button type="button" class="ch6 ${lv.skill === n ? 'on' : ''} ${known ? 'lockd off' : ''}" data-sk="${n}">${known ? icon('check') : ''}${n}</button>`; }).join('')}</div>
      <p class="hint5">${icon('info')} Навыками, которыми ${h.name} уже владеет, выбор не тратится.</p>`;
  }
  if (k === 'hp'){
    const d = dieOf(), avg = d / 2 + 1;
    return `<div class="hpcard" style="--acc:var(--heal)"><span class="big"><small>Максимум ОЗ</small><b class="num" data-hpv>${odo(h.hp + (lv.hp.gain || 0), 'hpmax')}</b><em>Кость хитов к${d} · Телосложение ${sgn(h.con)}</em></span>
        <span class="dieslot" data-dieslot style="--acc:var(--heal)">${die('d' + d, lv.hp.roll || d, {cls:'xl'})}</span></div>
      <div class="methods">
        <button type="button" class="mtile ${lv.hp.m === 'avg' ? 'on' : ''}" data-hm="avg"><span class="mi">${icon('stats')}</span><b>Среднее</b><small>${avg} ${sgn(h.con)} = ${avg + h.con}</small></button>
        <button type="button" class="mtile ${lv.hp.m === 'roll' ? 'on' : ''}" data-hm="roll"><span class="mi">${icon('dice')}</span><b>Бросок</b><small data-rollt>${lv.hp.roll ? `Выпало ${lv.hp.roll} · ещё раз` : `к${d} в приложении`}</small></button>
        <button type="button" class="mtile ${lv.hp.m === 'own' ? 'on' : ''}" data-hm="own"><span class="mi">${icon('edit')}</span><b>Своя кость</b><small>Бросок за столом</small></button>
      </div>
      <p class="hint5">${icon('heart')} Текущие ОЗ останутся ${h.hp}: повышение не лечит.</p>`;
  }
  if (k === 'asi') return `${segHTML([['ab', 'Характеристики'], ['feat', 'Черта']], lv.asi.mode, 'asiSeg')}<div class="body6" data-asi>${asiInner()}</div>`;
  if (k === 'feat'){
    const subs = lvScn === 'paladin' ? OATHS : lv.cls === 'cleric' ? DOMAINS : null;
    return `<div class="gain6">${lvGains().map((g, i) => `<button type="button" class="gainc tap6" data-info="gain:${g}" style="--acc:var(--a${acc})"><span class="lock" style="animation-delay:${i * 90}ms">${seal5(GAINS[g][2], acc)}</span><span class="ft"><b>${GAINS[g][0]}</b><small>${GAINS[g][1]}</small></span>${icon('fwd', 'chev')}</button>`).join('')}</div>
      ${subs ? `<div class="grp6"><b>${lvScn === 'paladin' ? 'Священная клятва' : 'Божественный домен'}</b><small>одна на всю жизнь</small></div>
      <div class="picks">${subs.map(o => `<button type="button" class="pick6 card6 ${lv.sub === o.n ? 'on' : ''}" data-sub="${o.n}" data-hold6="sub:${o.n}" style="--acc:var(--a${o.acc})">
        <span class="ph">${seal5(lvScn === 'paladin' ? 'shield' : 'sun', o.acc, 'lg')}<span class="ft"><b>${o.n}</b><small>${o.d}</small></span>${info('sub:' + o.n)}${tick}</span>
        <span class="chips6">${o.in.map(([n]) => `<span class="fact6">${n}</span>`).join('')}</span><span class="src6">${o.src}</span></button>`).join('')}</div>` : ''}`;
  }
  if (k === 'magic'){
    if (lvScn === 'paladin') return `<div class="pipsrow" style="--a5:var(--a1)"><div class="pr"><span>1-й круг</span>${'<i class="pip"></i>'.repeat(2)}<i class="pip new"></i></div></div>
      <div class="mbar" style="--a5:var(--a1)"><b class="num">+1</b><span class="ft"><b>Подготовленное заклинание</b><small>Паладин 3 готовит на одно больше. Заклинания клятвы всегда подготовлены.</small></span></div>
      <p class="hint5">${icon('info')} Здесь выбирать нечего: клятва уже определила новые заклинания.</p>`;
    const [before, after] = S.slots;
    return `<div class="pipsrow">${after.map((m, i) => `<div class="pr"><span>${i + 1}-й круг</span>${Array.from({length:m}, (_, j) => `<i class="pip ${j >= (before[i] || 0) ? 'new' : ''}" style="animation-delay:${j * 90}ms"></i>`).join('')}</div>`).join('')}</div>
      <div class="mbar"><b class="num" data-mcount>${odo(lv.spells.size, 'mc')}</b><span class="ft"><b>из ${S.learn} новых заклинаний</b><small>В книгу волшебника, любого круга до 3-го. Удержание — описание.</small></span></div>
      <div class="chips6">${[0, 3, 2, 1].map((c, i) => `<button type="button" class="ch6 ${!i ? 'on' : ''}" data-circ="${c}">${c ? c + '-й круг' : 'Все'}</button>`).join('')}</div>
      <div class="picks">${SPELLS6.map(([c, n, sch, , known]) => `<button type="button" class="spl ${known ? 'dim' : ''} ${lv.spells.has(n) ? 'on' : ''}" data-sp="${n}" data-c="${c}" data-hold6="spell:${n}" ${known ? 'aria-disabled="true"' : ''}><span class="circ">${c}</span><span class="ft"><b>${n}</b><small>${sch}${known ? ' · уже в книге' : ''}</small></span>${info('spell:' + n)}<i class="tick">${icon('check')}</i></button>`).join('')}</div>`;
  }
  if (k === 'sum') return sumBody();
}
function asiInner(){
  const h = lvHero();
  if (lv.asi.mode === 'feat') return `<div class="picks">${FEATS.map(([n, d, src]) => `<button type="button" class="pick6 card6 ${lv.asi.feat === n ? 'on' : ''}" data-feat="${n}" data-hold6="feat:${n}" style="--acc:var(--a2)"><span class="ph">${seal5('star', 2)}<span class="ft"><b>${n}</b><small>${src}</small></span>${info('feat:' + n)}${tick}</span><p>${d}</p></button>`).join('')}</div>`;
  return `<div class="gems" style="--acc:var(--a${lvAcc()})"><i class="gm ${ptsUsed() > 0 ? 'spent' : ''}"></i><i class="gm ${ptsUsed() > 1 ? 'spent' : ''}"></i><small>${ptsUsed() === 2 ? 'Оба очка вложены — касание возвращает' : 'Касание добавляет очко: оба в одну или по одному в две'}</small></div>
    <div class="ab6" style="--acc:var(--a${lvAcc()})">${AB.map(([id, , sh]) => { const p = lv.asi.pts[id] || 0, v = h.ab[id] + p;
      return `<button type="button" class="abt ${p ? 'up' : ''} ${h.ab[id] >= 20 ? 'max' : ''}" data-ab="${id}"><span class="k">${sh}</span><b class="num" data-abv>${odo(v, 'ab' + id)}</b><small>${sgn(mod(v))}${mod(v) !== mod(h.ab[id]) ? ' ↑' : ''}</small><span class="plus">${'<i></i>'.repeat(p)}</span></button>`; }).join('')}</div>`;
}
function sumBody(){
  const h = lvHero(), S = lv.S, c = lvClass() || clsOf(S.hero.cls), [p0, p1] = S.prof;
  const ab = AB.filter(([id]) => lv.asi.pts[id]);
  const gains = [...lvGains().filter(g => !(g === 'asi' && lv.asi.feat)).map(g => [GAINS[g][0], GAINS[g][1], GAINS[g][2], 'gain:' + g]),
    ...(lv.sub ? [[lv.sub, 'Подкласс', lvScn === 'paladin' ? 'shield' : 'sun', 'sub:' + lv.sub]] : []), ...(lv.asi.feat ? [[lv.asi.feat, 'Черта', 'star', 'feat:' + lv.asi.feat]] : []),
    ...[...lv.spells].map(n => [n, 'Заклинание в книгу', 'magic', 'spell:' + n]), ...(lv.skill ? [[lv.skill, 'Навык плута', 'target', '']] : []), ...(lv.cls === 'rogue' ? [['Воровские инструменты', 'Владение', 'key', 'tool:thieves']] : [])];
  return `<div class="sum6" style="--acc:var(--a${c.acc})">
      <div class="drow">${icon('up')}<span>Уровень героя</span><s>${h.lvl}</s>${icon('fwd', 'ar')}<b class="to">${S.to}</b></div>
      <div class="drow">${icon('heart')}<span>Максимум ОЗ</span><s>${h.hp}</s>${icon('fwd', 'ar')}<b class="to">${h.hp + (lv.hp.gain || 0)}</b></div>
      <div class="drow">${icon('dice')}<span>Кости хитов</span><s>${h.lvl}</s>${icon('fwd', 'ar')}<b class="to">${S.to}</b></div>
      ${p1 !== p0 ? `<div class="drow">${icon('star')}<span>Бонус мастерства</span><s>+${p0}</s>${icon('fwd', 'ar')}<b class="to">+${p1}</b></div>` : ''}
      ${ab.map(([id, n]) => `<div class="drow">${icon('stats')}<span>${n}</span><s>${h.ab[id]}</s>${icon('fwd', 'ar')}<b class="to">${h.ab[id] + lv.asi.pts[id]}</b></div>`).join('')}
    </div>
    <div class="grp6"><b>Новое на листе</b><small>${gains.length}</small></div>
    <div class="gain6">${gains.map(([n, d, ic, key]) => `<${key ? `button type="button" data-info="${key}"` : 'div'} class="gainc ${key ? 'tap6' : ''}" style="--acc:var(--a${c.acc})">${seal5(ic, c.acc, 'sm')}<span class="ft"><b>${n}</b><small>${d}</small></span>${key ? icon('fwd', 'chev') : ''}</${key ? 'button' : 'div'}>`).join('')}</div>
    <p class="hint5">${icon('info')} Журнал, имущество и текущие ОЗ не меняются. Повышение запишется в историю, его можно откатить.</p>`;
}
function bindStep(root, k, onChange){
  const h = lvHero();
  holdable(root);
  if (k === 'cls') $$('[data-cls]', root).forEach(b => b.addEventListener('click', () => {
    if (b.getAttribute('aria-disabled')) { buzz.light(); return toast('Не хватает Интеллекта: удержите карточку, чтобы прочитать о классе'); }
    lv.cls = b.dataset.cls; $$('[data-cls]', root).forEach(x => x.classList.toggle('on', x === b)); replay($('.tick6', b), 'stamp5'); buzz.tick(); onChange('cls'); }));
  if (k === 'prof') $$('[data-sk]', root).forEach(b => b.addEventListener('click', () => { lv.skill = b.dataset.sk; $$('[data-sk]', root).forEach(x => x.classList.toggle('on', x === b)); replay(b, 'stamp5');
    $('[data-skc]', root).textContent = '1 из 1'; buzz.tick(); onChange(); }));
  if (k === 'hp') $$('[data-hm]', root).forEach(b => b.addEventListener('click', () => {
    const m = b.dataset.hm, d = dieOf();
    $$('[data-hm]', root).forEach(x => x.classList.toggle('on', x === b)); buzz.tick();
    const apply = g => { lv.hp.gain = g; setOdo($('[data-hpv]', root).firstElementChild, h.hp + g); onChange(); };
    lv.hp.m = m;
    if (m === 'avg') apply(d / 2 + 1 + h.con);
    if (m === 'roll'){ const r = 1 + Math.floor(Math.random() * d); lv.hp.roll = r; lv.hp.gain = null; onChange();
      tumble([$('[data-dieslot] .die2', root)], [r], d, () => { $('[data-rollt]', root).textContent = `Выпало ${r} · ещё раз`; apply(Math.max(1, r + h.con)); if (r === d) buzz.medium(); }); }
    if (m === 'own') keypadSheet({kicker:'ОЗ', title:`Что выпало на к${d}?`, onDone:n => { lv.hp.roll = clamp(n, 1, d); $('[data-dieslot]', root).innerHTML = die('d' + d, lv.hp.roll, {cls:'xl'}); apply(Math.max(1, lv.hp.roll + h.con)); }});
  }));
  if (k === 'asi'){
    segment($('#asiSeg', root), b => { lv.asi.mode = b.dataset.v; if (lv.asi.mode === 'feat') lv.asi.pts = {}; else lv.asi.feat = null; buzz.tick();
      const box = $('[data-asi]', root); box.innerHTML = asiInner(); bindAsi(root, onChange); stagger($('.picks, .ab6', box)); onChange(); });
    bindAsi(root, onChange);
  }
  if (k === 'feat') $$('[data-sub]', root).forEach(b => b.addEventListener('click', () => { lv.sub = b.dataset.sub; $$('[data-sub]', root).forEach(x => x.classList.toggle('on', x === b)); replay($('.tick6', b), 'stamp5'); buzz.tick(); onChange(); }));
  if (k === 'magic'){
    $$('[data-circ]', root).forEach(b => b.addEventListener('click', () => { const c = +b.dataset.circ; $$('[data-circ]', root).forEach(x => x.classList.toggle('on', x === b)); buzz.tick();
      $$('[data-sp]', root).forEach(x => { x.style.display = !c || +x.dataset.c === c ? '' : 'none'; }); stagger($('.picks', root)); onChange(); }));
    $$('[data-sp]', root).forEach(b => b.addEventListener('click', () => { if (b.getAttribute('aria-disabled')) return; const n = b.dataset.sp;
      // Over the limit the first pick gives way to the new one.
      if (lv.spells.has(n)) lv.spells.delete(n); else { if (lv.spells.size >= lv.S.learn) { const first = [...lv.spells][0]; lv.spells.delete(first); $(`[data-sp="${first}"]`, root).classList.remove('on'); } lv.spells.add(n); }
      b.classList.toggle('on', lv.spells.has(n)); if (lv.spells.has(n)) replay($('.tick', b), 'stamp5'); setOdo($('[data-mcount]', root).firstElementChild, lv.spells.size); buzz.tick(); onChange(); }));
  }
}
function bindAsi(root, onChange){
  const h = lvHero();
  holdable(root);
  $$('[data-ab]', root).forEach(b => b.addEventListener('click', () => {
    const id = b.dataset.ab, p = lv.asi.pts[id] || 0, v = h.ab[id] + p;
    if (ptsUsed() < 2 && v < 20){ lv.asi.pts[id] = p + 1; const gem = $$('.gm:not(.spent)', root)[0]; fly(gem, b, '<i class="gm"></i>'); }
    else if (p) { lv.asi.pts[id] = p - 1; if (!lv.asi.pts[id]) delete lv.asi.pts[id]; }
    else { buzz.light(); return toast(v >= 20 ? 'Больше 20 нельзя' : 'Оба очка вложены — коснитесь отмеченной, чтобы вернуть'); }
    buzz.tick();
    $$('.gm', root).forEach((g, i) => g.classList.toggle('spent', i < ptsUsed()));
    const nv = h.ab[id] + (lv.asi.pts[id] || 0);
    setTimeout(() => { setOdo($('[data-abv]', b).firstElementChild, nv); b.classList.toggle('up', !!lv.asi.pts[id]); $('small', b).textContent = sgn(mod(nv)) + (mod(nv) !== mod(h.ab[id]) ? ' ↑' : '');
      $('.plus', b).innerHTML = '<i></i>'.repeat(lv.asi.pts[id] || 0);
      $('.gems small', root).textContent = ptsUsed() === 2 ? 'Оба очка вложены — касание возвращает' : 'Касание добавляет очко: оба в одну или по одному в две'; onChange(); }, reduced ? 0 : 380);
  }));
  $$('[data-feat]', root).forEach(b => b.addEventListener('click', () => { lv.asi.feat = b.dataset.feat; $$('[data-feat]', root).forEach(x => x.classList.toggle('on', x === b)); replay($('.tick6', b), 'stamp5'); buzz.tick(); onChange(); }));
}

function levelupHTML(){
  const S = lv.S, h = lvHero(), c = lvClass() || clsOf(S.hero.cls);
  return `${top5('Повышение уровня', {lead:'close', actions:`<button type="button" class="round" data-info="class:${c.id}" aria-label="Правила класса">${icon('book')}</button>`})}
    <div class="scroller"><div class="page6 lvpage" style="--acc:var(--a${c.acc})">
      <div class="climb" id="climb">
        <div class="lvtop">${av(h, 'lg')}<span class="lvcls"><span class="cap" data-lvcls>${lvLine()}</span><b>${h.name}</b></span><span style="flex:1"></span>
          <span class="lvnum"><span class="from num">${h.lvl}</span>${icon('fwd', 'arrow')}<span class="to num">${S.to}</span></span></div>
        <div class="ladder6">${Array.from({length:20}, (_, i) => `<i class="${i < S.to ? 'track' : ''} ${i === S.to - 1 ? 'goal' : ''}" style="height:${12 + i * 1.6}px">${i < S.to ? '<b></b>' : ''}</i>`).join('')}</div>
        <div class="changes" id="changes"></div>
      </div>
      <div class="route6" id="route"></div>
      <div class="pager6" id="pager"><div class="pages6" id="pages"></div></div>
    </div></div>
    <div class="dock6"><span class="hintd glass" id="hintd"></span><div class="dockrow glass"><button type="button" class="round dkb" id="prev" aria-label="Назад">${icon('back')}</button><button type="button" class="btn primary wide" id="next">Продолжить ${icon('fwd')}</button></div></div>`;
}
const lvLine = () => { const c = lvClass(), S = lv.S, h = lvHero();
  return lvScn === 'multi' ? (lv.cls ? (lv.cls === 'fighter' ? `Воин ${h.lvl} → ${h.lvl + 1}` : `Воин ${h.lvl} + ${c.n} 1`) : `Воин ${h.lvl} · выбор класса`) : `${c.n} ${h.lvl} → ${S.to}`; };
function bindLevelup(){
  const S = lv.S, pages = $('#pages'), pager = $('#pager');
  let steps = lvSteps();
  const fill = k => { const root = $(`[data-body="${k}"]`); if (!root) return; root.innerHTML = stepBody(k); bindStep(root, k, what => {
    if (what === 'cls'){ $('[data-lvcls]').textContent = lvLine(); build(true); }
    paint(); }); };
  // The pages and the route follow the class: rogue brings proficiencies,
  // the cleric a domain, the fighter goes straight to its 5th level.
  const build = keepCls => {
    steps = lvSteps();
    const have = new Set($$('#pages>section').map(s => s.dataset.step));
    if (!keepCls || steps.some(k => !have.has(k)) || have.size !== steps.length){
      const clsSec = keepCls ? $('#pages>section[data-step="cls"]') : null;
      pages.innerHTML = steps.map((k, i) => k === 'cls' && clsSec ? '<section data-keep></section>' : `<section data-step="${k}" data-i="${i}"><div class="sh6"><h2>${HEADS[k][0]}</h2>${k === 'magic' ? `<p>${lvScn === 'paladin' ? 'Ячейки и подготовка меняются сами.' : 'Новый круг ячеек и два заклинания в книгу.'}</p>` : HEADS[k][1] ? `<p>${HEADS[k][1]}</p>` : ''}</div><div class="body6" data-body="${k}"></div></section>`).join('');
      if (clsSec) { $('[data-keep]', pages).replaceWith(clsSec); clsSec.dataset.i = 0; }
      steps.forEach(k => { if (!(k === 'cls' && clsSec)) fill(k); });
    } else steps.filter(k => k !== 'cls').forEach(fill);
    const route = $('#route');
    flip(route, () => { route.innerHTML = steps.map((k, i) => `<button type="button" class="rstep" data-goto="${i}" data-k="${k}"><i>${i + 1}</i>${STEP[k][0]}</button>`).join(''); });
    $$('[data-goto]').forEach(b => b.addEventListener('click', () => goTo(+b.dataset.goto)));
  };
  const fit = () => { const sec = $(`#pages>section[data-i="${lv.step}"]`); if (sec) pager.style.height = sec.offsetHeight + 'px'; };
  const paint = () => {
    const k = steps[lv.step];
    $$('.rstep').forEach((b, i) => { b.classList.toggle('now', i === lv.step); const done = i < lv.step && resolved(steps[i]); b.classList.toggle('done', done);
      $('i', b).innerHTML = done ? icon('check') : i + 1; });
    pages.style.transform = `translateX(${-lv.step * 100}%)`;
    $$('#pages>section').forEach((s, i) => s.classList.toggle('off', i !== lv.step));
    fit();
    const last = k === 'sum';
    $('#next').innerHTML = last ? `Повысить до ${S.to} ${icon('check')}` : `Продолжить ${icon('fwd')}`;
    $('#next').disabled = !resolved(k);
    $('#prev').classList.toggle('gone', !lv.step);
    $('#hintd').textContent = last ? `${lvHero().name} станет героем ${S.to}-го уровня` : resolved(k) ? '' : stepHint(k);
    $('#route .now')?.scrollIntoView({inline:'center', block:'nearest', behavior:reduced ? 'auto' : 'smooth'});
    // The ladder fills from nothing up to the new level as the steps are
    // settled, several rungs at a time, the last one only partly.
    const choices = steps.filter(x => x !== 'sum'), done = choices.filter(x => resolved(x)).length + (last ? 1 : 0);
    if (ladderReady) paintLadder(lvHero().lvl + Math.min(1, done / (choices.length + 1)), {wave:0});
    paintChanges();
  };
  const goTo = i => {
    if (i === lv.step || i < 0 || i >= steps.length) return;
    if (i > lv.step && steps.slice(0, i).some(k => !resolved(k))) { buzz.light(); return toast('Сначала решите текущий шаг'); }
    lv.step = i; buzz.tick();
    if (steps[i] === 'sum') fill('sum');
    paint();
    stagger($(`#pages>section[data-i="${i}"] .body6`)); $('#app .scroller').scrollTo({top:0, behavior:reduced ? 'auto' : 'smooth'});
  };
  ladderAt = 0; ladderReady = false;
  build(false);
  $('#next').addEventListener('click', () => steps[lv.step] === 'sum' ? ceremony() : goTo(lv.step + 1));
  $('#prev').addEventListener('click', () => goTo(lv.step - 1));
  paint();
  // The page opens like the step it starts with: the head's ladder rises
  // empty, then the first step slides in and its cards arrive in turn.
  if (!reduced){
    $$('.ladder6 i').forEach((b, i) => b.animate([{transform:'scaleY(.15)'}, {transform:'none'}], {duration:560, delay:i * 18, easing:springEasing(SPR.gentle, .56), fill:'backwards'}));
    pager.animate([{transform:'translateX(56px)', opacity:0}, {transform:'none', opacity:1}], {duration:560, delay:260, easing:springEasing(SPR.snappy, .56), fill:'backwards'});
    stagger($('#pages>section[data-i="0"] .body6'));
  }
  // On the way in the levels the hero already has fill softly from the
  // bottom; after that the new rung follows the steps.
  setTimeout(() => { paintLadder(lvHero().lvl, {wave:reduced ? 0 : 90}); ladderReady = true;
    setTimeout(() => paint(), reduced ? 0 : 260 + lvHero().lvl * 90); }, reduced ? 0 : 380);
  setTimeout(fit, 60); setTimeout(fit, 900);
}
// The ladder counts rungs: the hero's own levels, then the new one, which
// fills with the settled steps. [at] is how many rungs are full.
let ladderAt = 0, ladderReady = false;
function paintLadder(at, {wave = 70} = {}){
  const rungs = $$('.ladder6 i.track'), rising = at >= ladderAt;
  rungs.forEach((r, i) => { const f = clamp(at - i, 0, 1), b = $('b', r);
    // A wave: rungs fill one after another in the direction of travel.
    const order = rising ? i - Math.floor(ladderAt) : Math.ceil(ladderAt) - i;
    b.style.transitionDelay = reduced ? '0ms' : Math.max(0, order) * wave + 'ms';
    b.style.height = f * 100 + '%'; r.classList.toggle('lit', f >= 1); });
  const goal = $('.ladder6 i.goal');
  if (goal){ goal.classList.toggle('full', at >= rungs.length); goal.classList.toggle('going', at > rungs.length - 1 && at < rungs.length); }
  ladderAt = at;
}
function paintChanges(){
  const S = lv.S, box = $('#changes'); if (!box) return;
  const chg = [['heart', 'ОЗ', lv.hp.gain != null ? '+' + lv.hp.gain : null], ['dice', 'Кость хитов', lv.cls || lvScn !== 'multi' ? 'к' + dieOf() : null],
    ...(S.prof[1] !== S.prof[0] ? [['star', 'Мастерство', '+' + S.prof[1]]] : []),
    ...(lvSteps().includes('asi') ? [['stats', lv.asi.mode === 'feat' ? 'Черта' : 'Характеристики', resolved('asi') ? (lv.asi.mode === 'feat' ? lv.asi.feat : AB.filter(([id]) => lv.asi.pts[id]).map(([, , sh]) => sh).join(' ')) : null]] : []),
    ...(lvScn === 'paladin' ? [['shield', 'Клятва', lv.sub ? lv.sub.replace('Клятва ', '') : null]] : []),
    ...(lv.cls === 'cleric' ? [['sun', 'Домен', lv.sub ? lv.sub.replace('Домен ', '') : null]] : []),
    ...(lvScn === 'wizard' ? [['magic', 'Заклинания', lv.spells.size ? `${lv.spells.size}/${S.learn}` : null]] : []),
    ...(lv.cls === 'rogue' ? [['key', 'Инструменты', '✓'], ['target', 'Навык', lv.skill]] : [])];
  const html = chg.map(([ic, n, v]) => `<span class="chg ${v == null ? 'wait' : ''}" data-k="${n}">${icon(ic)}${n}${v != null ? ` <b>${v}</b>` : ''}</span>`).join('');
  if (box.innerHTML === html) return;
  const was = new Set($$('.chg:not(.wait)', box).map(x => x.dataset.k + x.textContent));
  flip(box, () => { box.innerHTML = html; });
  $$('.chg:not(.wait)', box).forEach(x => { if (!was.has(x.dataset.k + x.textContent)) replay(x, 'pop'); });
}
// Confirmation: the new level is drawn around the hero, then the sheet returns.
function ceremony(){
  const S = lv.S, h = lvHero(), c = lvClass() || clsOf(S.hero.cls);
  buzz.medium();
  const el = document.createElement('div');
  el.className = 'cer'; el.style.setProperty('--acc', `var(--a${c.acc})`);
  el.innerHTML = `<div class="ring"><svg viewBox="0 0 200 200"><circle class="bg" cx="100" cy="100" r="95"/><circle class="fg" cx="100" cy="100" r="95"/></svg><i class="burst"></i><span class="lv num">${odo(h.lvl, 'cer')}</span>
    <span class="cap6">${h.name} · ${S.to}-й уровень<small>${lvScn === 'multi' && lv.cls !== 'fighter' ? `Воин ${h.lvl} / ${clsOf(lv.cls).n} 1` : `${c.n} ${lvScn === 'multi' ? h.lvl + 1 : S.to}`}</small></span></div>`;
  $('#phone').appendChild(el);
  requestAnimationFrame(() => { el.classList.add('in'); setTimeout(() => { setOdo($('.lv', el).firstElementChild, S.to); buzz.light(); }, reduced ? 0 : 420); });
  setTimeout(() => buzz.medium(), reduced ? 0 : 1000);
  setTimeout(() => {
    const hh = sheetHero(); histSeed(); hh.lvl = S.to; hh.hp += lv.hp.gain || 0; AB.forEach(([id]) => { hh.ab[id] += lv.asi.pts[id] || 0; });
    if (lv.skill) hh.skills.push(lv.skill);
    hh.classes = lvScn === 'multi' && lv.cls !== 'fighter' ? [['fighter', 4], [lv.cls, 1]] : [[hh.cls, S.to]];
    HISTORY.unshift({lvl:S.to, cls:lvScn === 'multi' ? lv.cls : hh.cls, hp:lv.hp.gain, ab:{...lv.asi.pts},
      picks:[lv.sub, lv.asi.feat, ...lv.spells, lv.skill, ...AB.filter(([id]) => lv.asi.pts[id]).map(([id, , sh]) => sh + ' +' + lv.asi.pts[id])].filter(Boolean)});
    el.classList.remove('in'); setTimeout(() => el.remove(), 320);
    stack = [{s:'sheet'}]; render(); toast(`${hh.name} — ${S.to}-й уровень. Повышение записано в историю`);
  }, reduced ? 600 : 2600);
}

/* ================= History: the level ladder ================= */
let HISTORY = [];
// The last level of each story was already made with the history on;
// earlier ones predate it: no records, no rollback.
const SEED = {fighter:{lvl:3, cls:'fighter', hp:8, picks:['Чемпион']}, wizard:{lvl:4, cls:'wizard', hp:5, picks:['ИНТ +2']},
  paladin:{lvl:2, cls:'paladin', hp:7, picks:['Оборона']}, multi:{lvl:4, cls:'fighter', hp:8, picks:['СИЛ +1', 'ТЕЛ +1']}};
function histSeed(){
  if (HISTORY.seededFor === lvScn) return;
  HISTORY = [{...SEED[lvScn], picks:[...SEED[lvScn].picks]}]; HISTORY.seededFor = lvScn;
}
let rollTo = null;
function historyHTML(){
  histSeed();
  if (cur().s === 'history' && !cur().seen) { histEntered = false; cur().seen = true; }
  const h = sheetHero(), rec = Object.fromEntries(HISTORY.map(r => [r.lvl, r]));
  const rows = Array.from({length:h.lvl}, (_, i) => i + 1).map(l => { const r = rec[l], c = clsOf(r ? r.cls : h.cls);
    const goes = rollTo != null && l > rollTo;
    return `<button type="button" class="rung ${r ? '' : 'old'} ${rollTo === l - 1 && r ? 'sel' : ''} ${goes ? 'goes' : ''}" data-rung="${l}" ${r ? '' : 'disabled'} style="--acc:var(--a${c.acc})">
      <span class="lvl num">${l}</span><span class="ft"><b>${c.n} · ${l}-й уровень</b><small>${r ? `ОЗ +${r.hp}${r.picks.length ? ' · ' + r.picks.slice(0, 2).join(', ') : ''}` : l === 1 ? 'Создание героя' : 'до записи истории'}</small></span>
      ${r ? `<span class="gl">${icon('back')}</span>` : ''}</button>`; }).join('');
  return `${top5('История развития')}
  <div class="scroller"><div class="page5">
    <header class="mh"><span class="cap" style="--acc:var(--a${clsOf(h.cls).acc})">${h.name} · ${h.lvl}-й уровень</span><h1>История</h1><p class="sub5">Каждое подтверждённое повышение — ступень. Откатить можно последние ступени, начиная сверху: журнал, имущество и текущие ОЗ останутся.</p></header>
    <div class="lad">${rows}</div>
    <div class="reveal" id="rbox"><div>${rollTo != null ? rollbackHTML() : ''}</div></div>
  </div></div>`;
}
function rollbackHTML(){
  const h = sheetHero(), gone = HISTORY.filter(r => r.lvl > rollTo), hp = gone.reduce((s, r) => s + (r.hp || 0), 0);
  return `<div class="sum6" style="--acc:var(--a0);margin-top:8px">
      <div class="drow">${icon('up')}<span>Уровень героя</span><s>${h.lvl}</s>${icon('fwd', 'ar')}<b class="to">${rollTo}</b></div>
      <div class="drow">${icon('heart')}<span>Максимум ОЗ</span><s>${h.hp}</s>${icon('fwd', 'ar')}<b class="to">${h.hp - hp}</b></div>
      ${gone.flatMap(r => r.picks).length ? `<div class="drow">${icon('x')}<span>Уйдут: ${gone.flatMap(r => r.picks).join(', ')}</span></div>` : ''}
    </div>
    <p class="hint5" style="margin-top:14px">${icon('check')} Журнал, имущество, деньги и текущие ОЗ (не выше нового максимума) сохранятся.</p>
    <button type="button" class="hold5 hold6" id="hold"><span class="fill"></span><span class="hl">${icon('back')}<span class="ft"><b>Удерживайте, чтобы откатить</b><small>Герой вернётся к ${rollTo}-му уровню</small></span></span></button>`;
}
let histEntered = false;
function bindHistory(){
  // The ladder is climbed once on the way in: rungs rise from the bottom.
  if (!histEntered && !reduced) $$('.rung').forEach((r, i) => r.animate([{transform:'translateY(18px) scale(.96)', opacity:0}, {transform:'none', opacity:1}], {duration:460, delay:80 + i * 60, easing:springEasing(SPR.snappy, .46), fill:'backwards'}));
  histEntered = true;
  if (rollTo != null) requestAnimationFrame(() => { $('#rbox').classList.add('open'); stagger($('#rbox .sum6')); });
  $$('[data-rung]').forEach(b => b.addEventListener('click', () => { if (b.disabled) return; const l = +b.dataset.rung; const closing = rollTo === l - 1; buzz.tick();
    const y = $('#app .scroller').scrollTop;
    if (closing){ $('#rbox').classList.remove('open'); $$('.rung').forEach(r => r.classList.remove('sel', 'goes')); setTimeout(() => { rollTo = null; render(); $('#app .scroller').scrollTop = y; }, reduced ? 0 : 460); return; }
    rollTo = l - 1; render(); $('#app .scroller').scrollTop = y;
    $$('.rung.goes').forEach((r, i) => !reduced && r.animate([{transform:'none'}, {transform:'translateX(6px)'}, {transform:'none'}], {duration:360, delay:i * 50, easing:'ease-out'})); }));
  const hb = $('#hold'); if (!hb) return;
  let t = 0;
  const start = () => { hb.classList.add('holding'); buzz.tick(); t = setTimeout(() => {
    buzz.medium(); const h = sheetHero(), gone = HISTORY.filter(r => r.lvl > rollTo);
    $$('.rung.goes').reverse().forEach((r, i) => setTimeout(() => r.classList.add('fall'), i * 120));
    setTimeout(() => { h.hp -= gone.reduce((s, r) => s + (r.hp || 0), 0); h.lvl = rollTo; gone.forEach(r => Object.entries(r.ab || {}).forEach(([id, v]) => { h.ab[id] -= v; }));
      HISTORY = HISTORY.filter(r => r.lvl <= rollTo); HISTORY.seededFor = lvScn;
      h.classes = [[h.cls, rollTo]]; const to = rollTo; rollTo = null; render(); toast(`Герой снова ${to}-го уровня`); }, reduced ? 0 : 520 + gone.length * 120);
  }, reduced ? 10 : 900); };
  const stop = () => { clearTimeout(t); hb.classList.remove('holding'); };
  hb.addEventListener('pointerdown', start); ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => hb.addEventListener(ev, stop));
}
