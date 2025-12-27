// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'QD&D';

  @override
  String get appSubtitle => 'Roleplay Companion';

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык';

  @override
  String get theme => 'Тема';

  @override
  String get characters => 'Персонажи';

  @override
  String get compendium => 'Компендиум';

  @override
  String get diceRoller => 'Бросок кубов';

  @override
  String get inventory => 'Инвентарь';

  @override
  String get spells => 'Заклинания';

  @override
  String get features => 'Умения';

  @override
  String get stats => 'Характеристики';

  @override
  String get combat => 'Бой';

  @override
  String get notes => 'Заметки';

  @override
  String get quests => 'Задания';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get edit => 'Изменить';

  @override
  String get delete => 'Удалить';

  @override
  String get level => 'Уровень';

  @override
  String get race => 'Раса';

  @override
  String get background => 'Предыстория';

  @override
  String get classLabel => 'Класс';

  @override
  String get subclass => 'Подкласс';

  @override
  String get alignment => 'Мировоззрение';

  @override
  String get experience => 'Опыт';

  @override
  String get playerName => 'Имя игрока';

  @override
  String get createNewCharacter => 'Создать персонажа';

  @override
  String get importFC5 => 'Импорт из Fight Club 5';

  @override
  String get viewDetails => 'Подробнее';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get close => 'Закрыть';

  @override
  String get deleteConfirmationTitle => 'Удалить персонажа';

  @override
  String deleteConfirmationMessage(String name) {
    return 'Вы уверены, что хотите удалить $name? Это действие нельзя отменить.';
  }

  @override
  String deletedSuccess(String name) {
    return '$name удален';
  }

  @override
  String duplicatedSuccess(String name) {
    return '$name успешно скопирован!';
  }

  @override
  String importedSuccess(String name) {
    return '$name успешно импортирован!';
  }

  @override
  String get abilities => 'Характеристики';

  @override
  String get savingThrows => 'Спасброски';

  @override
  String get skills => 'Навыки';

  @override
  String get abilityStr => 'Сила';

  @override
  String get abilityDex => 'Ловкость';

  @override
  String get abilityCon => 'Телосложение';

  @override
  String get abilityInt => 'Интеллект';

  @override
  String get abilityWis => 'Мудрость';

  @override
  String get abilityCha => 'Харизма';

  @override
  String get skillAthletics => 'Атлетика';

  @override
  String get skillAcrobatics => 'Акробатика';

  @override
  String get skillSleightOfHand => 'Ловкость рук';

  @override
  String get skillStealth => 'Скрытность';

  @override
  String get skillArcana => 'Магия';

  @override
  String get skillHistory => 'История';

  @override
  String get skillInvestigation => 'Анализ';

  @override
  String get skillNature => 'Природа';

  @override
  String get skillReligion => 'Религия';

  @override
  String get skillAnimalHandling => 'Уход за животными';

  @override
  String get skillInsight => 'Проницательность';

  @override
  String get skillMedicine => 'Медицина';

  @override
  String get skillPerception => 'Восприятие';

  @override
  String get skillSurvival => 'Выживание';

  @override
  String get skillDeception => 'Обман';

  @override
  String get skillIntimidation => 'Запугивание';

  @override
  String get skillPerformance => 'Выступление';

  @override
  String get skillPersuasion => 'Убеждение';

  @override
  String get combatDashboard => 'Боевые характеристики';

  @override
  String get hitPoints => 'Очки Здоровья';

  @override
  String get hpShort => 'ОЗ';

  @override
  String get armorClassAC => 'КД';

  @override
  String get initiativeINIT => 'ИНИЦ';

  @override
  String get speedSPEED => 'СКР';

  @override
  String get proficiencyPROF => 'БОНУС';

  @override
  String get weaponsAttacks => 'Оружие и Атаки';

  @override
  String get shortRest => 'Короткий отдых';

  @override
  String get longRest => 'Длительный отдых';

  @override
  String get enterCombatMode => 'Начать Бой';

  @override
  String get rest => 'Отдых';

  @override
  String get shortRestDescription =>
      'Восстановить умения короткого отдыха и потратить кости хитов?';

  @override
  String get longRestDescription =>
      'Восстановить все ОЗ, ячейки заклинаний и умения?';

  @override
  String get restedSuccess => 'Отдых завершен успешно';

  @override
  String get unarmedStrike => 'Безоружный удар';

  @override
  String get hit => 'ПОПАД';

  @override
  String get dmg => 'УРОН';

  @override
  String get damageTypeBludgeoning => 'Дробящий';

  @override
  String get damageTypePiercing => 'Колющий';

  @override
  String get damageTypeSlashing => 'Рубящий';

  @override
  String get damageTypePhysical => 'Физический';

  @override
  String get searchItems => 'Поиск предметов...';

  @override
  String get sortBy => 'Сортировка';

  @override
  String get sortName => 'Имя';

  @override
  String get sortWeight => 'Вес';

  @override
  String get sortValue => 'Стоимость';

  @override
  String get sortType => 'Тип';

  @override
  String get filterAll => 'Всё';

  @override
  String get filterEquipped => 'Надето';

  @override
  String get filterUnequipped => 'Снято';

  @override
  String get typeWeapon => 'Оружие';

  @override
  String get typeArmor => 'Доспехи';

  @override
  String get typeGear => 'Снаряжение';

  @override
  String get typeConsumable => 'Расходники';

  @override
  String get totalWeight => 'Общий вес';

  @override
  String get currency => 'Валюта';

  @override
  String get editCurrency => 'Изменить валюту';

  @override
  String get currencyUpdated => 'Валюта обновлена';

  @override
  String get currencyPP => 'Платина (PP)';

  @override
  String get currencyGP => 'Золото (GP)';

  @override
  String get currencySP => 'Серебро (SP)';

  @override
  String get currencyCP => 'Медь (CP)';

  @override
  String get inventoryEmpty => 'Инвентарь пуст';

  @override
  String get inventoryEmptyHint => 'Нажмите + чтобы добавить предметы';

  @override
  String get quantity => 'Количество';

  @override
  String get unequip => 'Снять';

  @override
  String get equip => 'Экипировать';

  @override
  String get remove => 'Удалить';

  @override
  String get itemRemoved => 'Предмет удалён';

  @override
  String get itemEquipped => 'Экипировано';

  @override
  String get itemUnequipped => 'Снято';

  @override
  String get weaponProperties => 'СВОЙСТВА ОРУЖИЯ';

  @override
  String get armorProperties => 'СВОЙСТВА ДОСПЕХА';

  @override
  String get damage => 'Урон';

  @override
  String get damageType => 'Тип урона';

  @override
  String get versatileDamage => 'Универсальный урон';

  @override
  String get range => 'Дальность';

  @override
  String get properties => 'Свойства';

  @override
  String get armorClass => 'Класс доспеха';

  @override
  String get type => 'Тип';

  @override
  String get strRequirement => 'Требование СИЛ';

  @override
  String get stealth => 'Скрытность';

  @override
  String get disadvantage => 'Помеха';

  @override
  String get weight => 'Вес';

  @override
  String get value => 'Стоимость';

  @override
  String get spellAlmanac => 'Альманах заклинаний';

  @override
  String get resources => 'Ресурсы';

  @override
  String get activeAbilities => 'Активные умения';

  @override
  String get magic => 'Магия';

  @override
  String get spellsList => 'Список заклинаний';

  @override
  String get passiveTraits => 'Пассивные черты';

  @override
  String get cantrips => 'Заговоры';

  @override
  String levelLabel(int level) {
    return 'Уровень $level';
  }

  @override
  String get levelShort => 'Ур.';

  @override
  String get noSpellsLearned => 'Заклинания пока не изучены';

  @override
  String get castSpell => 'Накл. заклинание';

  @override
  String castAction(String name) {
    return 'Наложить $name';
  }

  @override
  String get chooseSpellSlot => 'Выберите уровень ячейки:';

  @override
  String levelSlot(int level) {
    return 'Ячейка $level ур.';
  }

  @override
  String slotsRemaining(int count) {
    return 'Осталось: $count';
  }

  @override
  String get upcast => 'Усиление';

  @override
  String get noSlotsAvailable => 'Нет доступных ячеек!';

  @override
  String spellCastSuccess(Object name) {
    return '$name наложено!';
  }

  @override
  String spellCastLevelSuccess(Object level, Object name) {
    return '$name наложено на $level уровне!';
  }

  @override
  String get spellAbility => 'Баз. хар.';

  @override
  String get spellSaveDC => 'Сл. спаса';

  @override
  String get spellAttack => 'Атака';

  @override
  String lvlShort(int level) {
    return 'Ур $level';
  }

  @override
  String useChannelDivinity(int count) {
    return 'Исп. Бож. канал (осталось: $count)';
  }

  @override
  String get noChannelDivinity => 'Нет зарядов Бож. канала';

  @override
  String get schoolAbjuration => 'Ограждение';

  @override
  String get schoolConjuration => 'Вызов';

  @override
  String get schoolDivination => 'Прорицание';

  @override
  String get schoolEnchantment => 'Очарование';

  @override
  String get schoolEvocation => 'Эвокация';

  @override
  String get schoolIllusion => 'Иллюзия';

  @override
  String get schoolNecromancy => 'Некромантия';

  @override
  String get schoolTransmutation => 'Преобразование';

  @override
  String get combatStats => 'Боевые хар-ки';

  @override
  String get rollInitiative => 'Инициатива';

  @override
  String get endCombat => 'Завершить бой';

  @override
  String get endCombatConfirm => 'Это сбросит счетчик раундов.';

  @override
  String get nextRound => 'След. раунд';

  @override
  String get startCombat => 'Начать бой';

  @override
  String get heal => 'Лечение';

  @override
  String get takeDamage => 'Урон';

  @override
  String get tempHp => 'Врем. ОЗ';

  @override
  String get deathSaves => 'Спасброски от смерти';

  @override
  String get successes => 'Успехи';

  @override
  String get failures => 'Провалы';

  @override
  String get unconscious => 'БЕЗ СОЗНАНИЯ';

  @override
  String get condition => 'Состояние';

  @override
  String get conditions => 'Состояния';

  @override
  String get actionTypeAction => 'Действие';

  @override
  String get actionTypeBonus => 'Бонус. действие';

  @override
  String get actionTypeReaction => 'Реакция';

  @override
  String get spellcastingAbility => 'Базовая характеристика';

  @override
  String get currencyPP_short => 'пм';

  @override
  String get currencyGP_short => 'зм';

  @override
  String get currencySP_short => 'см';

  @override
  String get currencyCP_short => 'мм';

  @override
  String get weightUnit => 'фнт';

  @override
  String get currencyUnit => 'зм';

  @override
  String get age => 'Возраст';

  @override
  String get height => 'Рост';

  @override
  String get eyes => 'Глаза';

  @override
  String get skin => 'Кожа';

  @override
  String get hair => 'Волосы';

  @override
  String get appearance => 'Внешность';

  @override
  String get rollType => 'Тип броска';

  @override
  String get normal => 'Норма';

  @override
  String get advantage => 'Преим.';

  @override
  String get modifier => 'Модификатор';

  @override
  String get rolling => 'Бросок...';

  @override
  String total(Object value) {
    return 'Итог: $value';
  }

  @override
  String get tapToRoll => 'Нажмите для броска';

  @override
  String get levelUp => 'Повысить уровень';

  @override
  String get levelUpTitle => 'Повышение уровня';

  @override
  String get currentLevel => 'Текущий уровень';

  @override
  String get nextLevel => 'Следующий уровень';

  @override
  String get hpIncrease => 'Увеличение ОЗ';

  @override
  String get chooseRace => 'Выберите Расу';

  @override
  String get chooseClass => 'Выберите Класс';

  @override
  String hitDieType(Object value) {
    return 'Кость хитов: d$value';
  }

  @override
  String get damageTypeAcid => 'Кислота';

  @override
  String get damageTypeCold => 'Холод';

  @override
  String get damageTypeFire => 'Огонь';

  @override
  String get damageTypeForce => 'Силовой';

  @override
  String get damageTypeLightning => 'Молния';

  @override
  String get damageTypeNecrotic => 'Некротический';

  @override
  String get damageTypePoison => 'Яд';

  @override
  String get damageTypePsychic => 'Психический';

  @override
  String get damageTypeRadiant => 'Излучение';

  @override
  String get damageTypeThunder => 'Звук';

  @override
  String conModIs(String value) {
    return 'Ваш модификатор Телосложения: $value';
  }

  @override
  String get average => 'Среднее';

  @override
  String get safeChoice => 'Надежный выбор';

  @override
  String get roll => 'Бросок';

  @override
  String get riskIt => 'Рискнуть!';

  @override
  String get conditionBlinded => 'Ослеплен';

  @override
  String get conditionCharmed => 'Очарован';

  @override
  String get conditionDeafened => 'Оглушен';

  @override
  String get conditionFrightened => 'Испуган';

  @override
  String get conditionGrappled => 'Схвачен';

  @override
  String get conditionIncapacitated => 'Недееспособен';

  @override
  String get conditionInvisible => 'Невидим';

  @override
  String get conditionParalyzed => 'Парализован';

  @override
  String get conditionPetrified => 'Окаменевший';

  @override
  String get conditionPoisoned => 'Отравлен';

  @override
  String get conditionProne => 'Сбит с ног';

  @override
  String get conditionRestrained => 'Опутан';

  @override
  String get conditionStunned => 'Ошеломлен';

  @override
  String get conditionUnconscious => 'Без сознания';

  @override
  String get stepBasicInfo => 'Основное';

  @override
  String get identity => 'Личность';

  @override
  String get identitySubtitle => 'Создайте основу вашего персонажа';

  @override
  String get charName => 'Имя персонажа *';

  @override
  String get charNameHint => 'напр., Гандрен Роксикер';

  @override
  String get alignmentSubtitle => 'Выберите моральный компас';

  @override
  String get physicalAppearance => 'Внешность';

  @override
  String get physicalSubtitle => 'Детали внешнего вида';

  @override
  String get personality => 'Личность';

  @override
  String get personalitySubtitle => 'Черты, идеалы, привязанности, слабости';

  @override
  String get backstory => 'Предыстория';

  @override
  String get backstorySubtitle => 'История вашего персонажа';

  @override
  String get backstoryHint => 'Родился в маленькой деревне...';

  @override
  String get traits => 'Черты характера';

  @override
  String get traitsHint => 'Я всегда вежлив...';

  @override
  String get ideals => 'Идеалы';

  @override
  String get idealsHint => 'Справедливость...';

  @override
  String get bonds => 'Привязанности';

  @override
  String get bondsHint => 'Я обязан жизнью...';

  @override
  String get flaws => 'Слабости';

  @override
  String get flawsHint => 'У меня слабость к...';

  @override
  String get appearanceDesc => 'Описание внешности';

  @override
  String get appearanceHint => 'Высокий и мускулистый...';

  @override
  String get ageYears => 'лет';

  @override
  String get gender => 'Пол';

  @override
  String get genderMale => 'Мужчина';

  @override
  String get genderFemale => 'Женщина';

  @override
  String get genderOther => 'Другое';

  @override
  String get genderMaleShort => 'М';

  @override
  String get genderFemaleShort => 'Ж';

  @override
  String get genderOtherShort => 'Др';

  @override
  String get chooseRaceClass => 'Раса и Класс';

  @override
  String get choose => 'Выбрать';

  @override
  String get raceClassSubtitle =>
      'Выберите расу и класс персонажа, чтобы определить его основные способности.';

  @override
  String get loadingRaces => 'Загрузка рас...';

  @override
  String get loadingClasses => 'Загрузка классов...';

  @override
  String speed(int value) {
    return 'Скорость: $value фт.';
  }

  @override
  String get abilityScoreIncreases => 'Увеличение характеристик';

  @override
  String get languages => 'Языки';

  @override
  String get racialTraits => 'Расовые особенности';

  @override
  String get savingThrowProficiencies => 'Спасброски';

  @override
  String get check => 'Проверка';

  @override
  String get saveLabel => 'Спасбросок';

  @override
  String rollDie(int sides) {
    return 'Бросок d$sides';
  }

  @override
  String get skillProficiencies => 'Навыки';

  @override
  String get armorProficiencies => 'Доспехи';

  @override
  String get weaponProficiencies => 'Оружие';

  @override
  String get langCommon => 'Общий';

  @override
  String get langDwarvish => 'Дварфийский';

  @override
  String get langElvish => 'Эльфийский';

  @override
  String get langGiant => 'Великаний';

  @override
  String get langGnomish => 'Гномий';

  @override
  String get langGoblin => 'Гоблинский';

  @override
  String get langHalfling => 'Полуросликов';

  @override
  String get langOrc => 'Орочий';

  @override
  String get langAbyssal => 'Бездны';

  @override
  String get langCelestial => 'Небесный';

  @override
  String get langDraconic => 'Драконий';

  @override
  String get langDeepSpeech => 'Глубинная речь';

  @override
  String get langInfernal => 'Инфернальный';

  @override
  String get langPrimordial => 'Первичный';

  @override
  String get langSylvan => 'Сильван';

  @override
  String get langUndercommon => 'Подземный';

  @override
  String get weaponClub => 'Дубинка';

  @override
  String get weaponDagger => 'Кинжал';

  @override
  String get weaponGreatclub => 'Великая дубина';

  @override
  String get weaponHandaxe => 'Ручной топор';

  @override
  String get weaponJavelin => 'Метательное копье';

  @override
  String get weaponLightHammer => 'Легкий молот';

  @override
  String get weaponMace => 'Булава';

  @override
  String get weaponQuarterstaff => 'Боевой посох';

  @override
  String get weaponSickle => 'Серп';

  @override
  String get weaponSpear => 'Копье';

  @override
  String get weaponLightCrossbow => 'Легкий арбалет';

  @override
  String get weaponDart => 'Дротик';

  @override
  String get weaponShortbow => 'Короткий лук';

  @override
  String get weaponSling => 'Праща';

  @override
  String get weaponBattleaxe => 'Боевой топор';

  @override
  String get weaponFlail => 'Цеп';

  @override
  String get weaponGlaive => 'Глефа';

  @override
  String get weaponGreataxe => 'Секира';

  @override
  String get weaponGreatsword => 'Двуручный меч';

  @override
  String get weaponHalberd => 'Алебарда';

  @override
  String get weaponLance => 'Длинное копье';

  @override
  String get weaponLongsword => 'Длинный меч';

  @override
  String get weaponMaul => 'Молот';

  @override
  String get weaponMorningstar => 'Моргенштерн';

  @override
  String get weaponPike => 'Пика';

  @override
  String get weaponRapier => 'Рапира';

  @override
  String get weaponScimitar => 'Скимитар';

  @override
  String get weaponShortsword => 'Короткий меч';

  @override
  String get weaponTrident => 'Трезубец';

  @override
  String get weaponWarPick => 'Клевец';

  @override
  String get weaponWarhammer => 'Боевой молот';

  @override
  String get weaponWhip => 'Кнут';

  @override
  String get weaponBlowgun => 'Духовая трубка';

  @override
  String get weaponHandCrossbow => 'Ручной арбалет';

  @override
  String get weaponHeavyCrossbow => 'Тяжелый арбалет';

  @override
  String get weaponLongbow => 'Длинный лук';

  @override
  String get weaponNet => 'Сеть';

  @override
  String get selectHeight => 'Выберите Рост';

  @override
  String get selectWeight => 'Выберите Вес';

  @override
  String get selectEyeColor => 'Выберите Цвет Глаз';

  @override
  String get selectHairColor => 'Выберите Цвет Волос';

  @override
  String get selectSkinTone => 'Выберите Тон Кожи';

  @override
  String get custom => 'Свой';

  @override
  String get customEyeColor => 'Свой цвет глаз';

  @override
  String get customHairColor => 'Свой цвет волос';

  @override
  String get customSkinTone => 'Свой тон кожи';

  @override
  String get enterCustom => 'Введите значение';

  @override
  String get confirm => 'Подтвердить';

  @override
  String readyMessage(Object name) {
    return '$name готов выбрать свой путь!';
  }

  @override
  String get law => 'ЗАКОН';

  @override
  String get neutral => 'НЕЙТРАЛ';

  @override
  String get chaos => 'ХАОС';

  @override
  String get good => 'ДОБРО';

  @override
  String get evil => 'ЗЛО';

  @override
  String get lg => 'Законно-Добрый';

  @override
  String get ng => 'Нейтрально-Добрый';

  @override
  String get cg => 'Хаотично-Добрый';

  @override
  String get ln => 'Законно-Нейтральный';

  @override
  String get tn => 'Истинно-Нейтральный';

  @override
  String get cn => 'Хаотично-Нейтральный';

  @override
  String get le => 'Законно-Злой';

  @override
  String get ne => 'Нейтрально-Злой';

  @override
  String get ce => 'Хаотично-Злой';

  @override
  String get lgDesc => 'Честь, сострадание, долг';

  @override
  String get ngDesc => 'Доброта, помощь, баланс';

  @override
  String get cgDesc => 'Свобода, доброта, бунт';

  @override
  String get lnDesc => 'Порядок, традиция, закон';

  @override
  String get tnDesc => 'Баланс, природа, нейтралитет';

  @override
  String get cnDesc => 'Свобода, непредсказуемость';

  @override
  String get leDesc => 'Тирания, порядок, власть';

  @override
  String get neDesc => 'Эгоизм, жестокость, выгода';

  @override
  String get ceDesc => 'Разрушение, жестокость, хаос';

  @override
  String get stepRaceClass => 'Раса и Класс';

  @override
  String get stepAbilities => 'Характеристики и ОЗ';

  @override
  String get stepFeatures => 'Умения и Заклинания';

  @override
  String get stepEquipment => 'Снаряжение';

  @override
  String get stepBackground => 'Предыстория';

  @override
  String get stepSkills => 'Навыки';

  @override
  String get stepReview => 'Проверка';

  @override
  String get next => 'Далее';

  @override
  String get back => 'Назад';

  @override
  String get finish => 'Готово';

  @override
  String get characterCreated => 'Персонаж успешно создан!';

  @override
  String get tapToUpgrade => 'НАЖМИТЕ ДЛЯ УЛУЧШЕНИЯ';

  @override
  String get showDetails => 'Показать подробности';

  @override
  String get hideDetails => 'Скрыть подробности';

  @override
  String get newAbilities => 'Новые умения';

  @override
  String unlocksAtLevel(int level) {
    return 'Открывается на $level уровне';
  }

  @override
  String get noNewFeaturesAtLevel =>
      'На этом уровне нет новых умений. Но характеристики улучшились!';

  @override
  String get spellSlotsIncreased => 'Увеличено ячеек заклинаний';

  @override
  String get sacredOath => 'Священная клятва';

  @override
  String get classFeatures => 'Умения класса';

  @override
  String get chooseFightingStyle => 'Выберите боевой стиль:';

  @override
  String get makeChoices => 'Сделайте выбор';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get levelUpReady => 'Уровень повышен!';

  @override
  String get confirmLevelUp => 'Подтвердите изменения персонажа.';

  @override
  String get applyChanges => 'ПРИМЕНИТЬ';

  @override
  String get colorAmber => 'Янтарный';

  @override
  String get colorBlue => 'Голубой';

  @override
  String get colorBrown => 'Карий';

  @override
  String get colorGray => 'Серый';

  @override
  String get colorGreen => 'Зеленый';

  @override
  String get colorHazel => 'Ореховый';

  @override
  String get colorRed => 'Красный';

  @override
  String get colorViolet => 'Фиолетовый';

  @override
  String get colorAuburn => 'Золотисто-каштановый';

  @override
  String get colorBlack => 'Черный';

  @override
  String get colorBlonde => 'Блондин';

  @override
  String get colorWhite => 'Белый';

  @override
  String get colorBald => 'Лысый';

  @override
  String get skinPale => 'Бледная';

  @override
  String get skinFair => 'Светлая';

  @override
  String get skinLight => 'Светлая';

  @override
  String get skinMedium => 'Средняя';

  @override
  String get skinTan => 'Смуглая';

  @override
  String get skinDark => 'Темная';

  @override
  String get skinEbony => 'Черная';

  @override
  String get unitCm => 'см';

  @override
  String get unitKg => 'кг';

  @override
  String get chooseSkillsTitle => 'Выберите навыки';

  @override
  String chooseSkills(int count, String list) {
    return 'Выберите $count из: $list';
  }

  @override
  String get assignAbilityScores => 'Распределение характеристик';

  @override
  String get abilityScoresSubtitle =>
      'Выберите способ определения характеристик.';

  @override
  String get allocationMethod => 'Метод распределения';

  @override
  String get standardArray => 'Стандартный набор';

  @override
  String get pointBuy => 'Покупка очков';

  @override
  String get manualEntry => 'Вручную';

  @override
  String get standardArrayDesc =>
      'Значения: 15, 14, 13, 12, 10, 8. Сбалансировано.';

  @override
  String get pointBuyDesc => 'Потратьте 27 очков на характеристики (8-15).';

  @override
  String get manualEntryDesc => 'Установите любое значение от 3 до 18.';

  @override
  String get strDesc => 'Физическая мощь';

  @override
  String get dexDesc => 'Ловкость и рефлексы';

  @override
  String get conDesc => 'Выносливость и здоровье';

  @override
  String get intDesc => 'Логика и память';

  @override
  String get wisDesc => 'Внимательность и интуиция';

  @override
  String get chaDesc => 'Сила личности';

  @override
  String racialBonus(int bonus, int result, String mod) {
    return 'Расовый бонус: +$bonus → Итог: $result ($mod)';
  }

  @override
  String get startingHitPoints => 'Начальные хиты';

  @override
  String hitDieConMod(int die, String mod) {
    return 'Кость хитов: d$die | ТЕЛ Мод: $mod';
  }

  @override
  String get hpMaxDesc => 'Максимум ОЗ (рекомендуется)';

  @override
  String hpAvgDesc(int avg) {
    return 'Средний бросок: $avg + модификатор ТЕЛ';
  }

  @override
  String hpRollDesc(int die) {
    return 'Бросок 1d$die для начальных ОЗ';
  }

  @override
  String reRoll(int die, int val) {
    return 'Перебросить d$die (выпало: $val)';
  }

  @override
  String pointsUsed(int used, int total, int remaining) {
    return 'Очки: $used / $total иcп. (осталось $remaining)';
  }

  @override
  String get newFeaturesLabel => 'Новые умения';

  @override
  String get searchJournal => 'Поиск в журнале...';

  @override
  String get addQuest => 'Добавить квест';

  @override
  String get noActiveQuests => 'Нет активных квестов';

  @override
  String get addNote => 'Добавить заметку';

  @override
  String get noNotes => 'Нет заметок';

  @override
  String get deleteNote => 'Удалить заметку';

  @override
  String deleteNoteConfirmation(String title) {
    return 'Удалить \"$title\"?';
  }

  @override
  String get deleteQuest => 'Удалить квест';

  @override
  String deleteQuestConfirmation(String title) {
    return 'Удалить \"$title\"?';
  }

  @override
  String characterCreatedName(String name) {
    return '$name успешно создан!';
  }

  @override
  String errorCreatingCharacter(String error) {
    return 'Ошибка при создании персонажа: $error';
  }

  @override
  String get cancelCharacterCreationTitle => 'Отменить создание персонажа?';

  @override
  String get cancelCharacterCreationMessage => 'Весь прогресс будет потерян.';

  @override
  String get continueEditing => 'Продолжить редактирование';

  @override
  String get discard => 'Сбросить';

  @override
  String get selectClassFirst => 'Пожалуйста, сначала выберите класс';

  @override
  String selectSkillProficiencies(int count, String characterClass) {
    return 'Выберите $count навыка для класса $characterClass.';
  }

  @override
  String get allSkillsSelected => 'Все навыки выбраны!';

  @override
  String chooseMoreSkills(int count) {
    return 'Выберите еще $count';
  }

  @override
  String get skillAcrobaticsDesc => 'Ловкость - Баланс, кувырки, трюки';

  @override
  String get skillAnimalHandlingDesc => 'Мудрость - Успокоение животных, езда';

  @override
  String get skillArcanaDesc => 'Интеллект - Магия, заклинания, артефакты';

  @override
  String get skillAthleticsDesc => 'Сила - Лазание, прыжки, плавание';

  @override
  String get skillDeceptionDesc => 'Харизма - Ложь, маскировка, обман';

  @override
  String get skillHistoryDesc => 'Интеллект - Исторические события, легенды';

  @override
  String get skillInsightDesc => 'Мудрость - Понимание намерений, ложь';

  @override
  String get skillIntimidationDesc => 'Харизма - Угрозы, принуждение';

  @override
  String get skillInvestigationDesc => 'Интеллект - Поиск улик, дедукция';

  @override
  String get skillMedicineDesc => 'Мудрость - Стабилизация, диагностика';

  @override
  String get skillNatureDesc => 'Интеллект - Местность, растения, животные';

  @override
  String get skillPerceptionDesc =>
      'Мудрость - Замечать, слышать, обнаруживать';

  @override
  String get skillPerformanceDesc => 'Харизма - Музыка, танец, актерство';

  @override
  String get skillPersuasionDesc => 'Харизма - Дипломатия, переговоры';

  @override
  String get skillReligionDesc => 'Интеллект - Божества, обряды, молитвы';

  @override
  String get skillSleightOfHandDesc => 'Ловкость - Карманные кражи, фокусы';

  @override
  String get skillStealthDesc => 'Скрытность - Спрятаться, двигаться тихо';

  @override
  String get skillSurvivalDesc => 'Мудрость - Следопытство, навигация';

  @override
  String get chooseBackground => 'Выберите предысторию';

  @override
  String get backgroundDescription =>
      'Предыстория отражает прошлое вашего персонажа и дает дополнительные навыки.';

  @override
  String get noBackgroundsAvailable => 'Нет доступных предысторий';

  @override
  String get abilityStrAbbr => 'СИЛ';

  @override
  String get abilityDexAbbr => 'ЛОВ';

  @override
  String get abilityConAbbr => 'ТЕЛ';

  @override
  String get abilityIntAbbr => 'ИНТ';

  @override
  String get abilityWisAbbr => 'МУД';

  @override
  String get abilityChaAbbr => 'ХАР';

  @override
  String get propertyAmmunition => 'Боеприпасы';

  @override
  String get propertyFinesse => 'Фехтовальное';

  @override
  String get propertyHeavy => 'Тяжелое';

  @override
  String get propertyLight => 'Легкое';

  @override
  String get propertyLoading => 'Перезарядка';

  @override
  String get propertyRange => 'Дальнобойное';

  @override
  String get propertyReach => 'Досягаемость';

  @override
  String get propertySpecial => 'Особое';

  @override
  String get propertyThrown => 'Метательное';

  @override
  String get propertyTwoHanded => 'Двуручное';

  @override
  String get propertyVersatile => 'Универсальное';

  @override
  String get propertyMartial => 'Воинское';

  @override
  String get propertySimple => 'Простое';

  @override
  String get armorTypeLight => 'Легкий доспех';

  @override
  String get armorTypeMedium => 'Средний доспех';

  @override
  String get armorTypeHeavy => 'Тяжелый доспех';

  @override
  String get armorTypeShield => 'Щит';

  @override
  String get searchSpells => 'Поиск заклинаний...';

  @override
  String get noSpellsFound => 'Заклинания не найдены';

  @override
  String get tryAdjustingFilters => 'Попробуйте изменить фильтры';

  @override
  String get filters => 'Фильтры';

  @override
  String get clearAll => 'Очистить';

  @override
  String get apply => 'Применить';

  @override
  String get castingTime => 'Время накл.';

  @override
  String get duration => 'Длительность';

  @override
  String get components => 'Компоненты';

  @override
  String get materials => 'Материалы';

  @override
  String get concentration => 'Концентрация';

  @override
  String get ritual => 'Ритуал';

  @override
  String get atHigherLevels => 'На более высоких уровнях';

  @override
  String get classes => 'Классы';

  @override
  String get addToKnown => 'Добавить в изученные';

  @override
  String get removeFromKnown => 'Забыть заклинание';

  @override
  String addedToKnown(String name) {
    return 'Добавлено \"$name\" в изученные';
  }

  @override
  String removedFromKnown(String name) {
    return 'Удалено \"$name\" из изученных';
  }

  @override
  String get availableToLearn => 'Доступно для изучения';

  @override
  String availableAtLevel(int level) {
    return 'Доступно на $level уровне';
  }

  @override
  String get filterAvailability => 'Доступность';

  @override
  String get filterClass => 'Класс';

  @override
  String get filterLevel => 'Уровень';

  @override
  String get filterSchool => 'Школа';

  @override
  String get filterAllSpells => 'Все заклинания';

  @override
  String get filterCanLearnNow => 'Можно изучить';

  @override
  String get filterAvailableToClass => 'Доступно классу';

  @override
  String get filterAllClasses => 'Все классы';

  @override
  String get filterAllLevels => 'Все уровни';

  @override
  String get filterAllSchools => 'Все школы';

  @override
  String get clearFilters => 'Сбросить';

  @override
  String spellsCount(int count) {
    return '$count заклинаний';
  }

  @override
  String get spellAlmanacTitle => 'Альманах';

  @override
  String get actionTypeFree => 'Свободное действие';

  @override
  String get featuresStepTitle => 'Умения класса';

  @override
  String featuresStepSubtitle(String className) {
    return 'Как $className 1-го уровня, вы получаете следующие умения:';
  }

  @override
  String get noFeaturesAtLevel1 => 'Нет умений на 1-м уровне для этого класса.';

  @override
  String get spellsStepTitle => 'Заклинания';

  @override
  String get spellsStepPlaceholder =>
      'Выбор заклинаний будет доступен в будущих обновлениях. Пока что добавьте заклинания вручную в листе персонажа после создания.';

  @override
  String get equipmentStepTitle => 'Стартовое снаряжение';

  @override
  String get equipmentStepSubtitle =>
      'Выберите начальное снаряжение для вашего класса';

  @override
  String get chooseEquipmentPackage => 'Выберите набор снаряжения';

  @override
  String get packageStandard => 'Стандартный набор';

  @override
  String get packageStandardDesc => 'Рекомендуемое снаряжение';

  @override
  String get packageAlternative => 'Альтернативный набор';

  @override
  String get packageAlternativeDesc => 'Другие варианты снаряжения';

  @override
  String get packageCustom => 'Свой набор';

  @override
  String get packageCustomDesc => 'Выберите предметы из каталога';

  @override
  String get selectedEquipment => 'Выбранное снаряжение';

  @override
  String get addItem => 'Добавить';

  @override
  String get noItemsSelected => 'Нет выбранных предметов';

  @override
  String get tapToAddItems => 'Нажмите \"Добавить\", чтобы выбрать снаряжение';

  @override
  String equipmentPreview(String className) {
    return 'Предпросмотр снаряжения: $className';
  }

  @override
  String get toolsAndGear => 'Инструменты и снаряжение';

  @override
  String get equipmentPreviewDisclaimer =>
      'Это пример типичного снаряжения. Вы сможете изменить инвентарь после создания персонажа.';

  @override
  String get itemCatalog => 'Каталог предметов';

  @override
  String get createItem => 'Создать предмет';

  @override
  String foundItems(int count, int selected) {
    return 'Найдено: $count (выбрано: $selected)';
  }

  @override
  String get noItemsFound => 'Предметы не найдены';

  @override
  String get done => 'Готово';

  @override
  String get createCustomItem => 'Создание предмета';

  @override
  String get addImage => 'Добавить\nфото';

  @override
  String errorLoadingImage(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get itemName => 'Название';

  @override
  String get itemNameHint => 'напр., Меч Света';

  @override
  String get enterItemName => 'Введите название';

  @override
  String get itemDescription => 'Описание';

  @override
  String get itemDescriptionHint => 'Опишите предмет...';

  @override
  String get itemType => 'Тип';

  @override
  String get itemRarity => 'Редкость';

  @override
  String get itemWeight => 'Вес';

  @override
  String get itemValue => 'Цена';

  @override
  String get itemQuantity => 'Количество';

  @override
  String get minQuantity1 => 'Минимум 1';

  @override
  String itemAdded(String name, int quantity) {
    return '$name (x$quantity) добавлен';
  }

  @override
  String errorCreatingItem(String error) {
    return 'Ошибка создания: $error';
  }

  @override
  String get rarityCommon => 'Обычный';

  @override
  String get rarityUncommon => 'Необычный';

  @override
  String get rarityRare => 'Редкий';

  @override
  String get rarityVeryRare => 'Очень редкий';

  @override
  String get rarityLegendary => 'Легендарный';

  @override
  String get rarityArtifact => 'Артефакт';

  @override
  String get methodStandard => 'Стандартный набор';

  @override
  String get methodPointBuy => 'Распределение очков';

  @override
  String get methodManual => 'Вручную';

  @override
  String get characterReady => 'Персонаж готов!';

  @override
  String get reviewChoices => 'Проверьте выбор перед завершением';

  @override
  String get unnamed => '(Без имени)';

  @override
  String get basicInfo => 'Основная информация';

  @override
  String get level1Info =>
      'Ваш персонаж будет создан на 1 уровне. Дополнительные умения будут добавлены на основе вашего класса и предыстории.';

  @override
  String get hpMax => 'Максимум';
}
