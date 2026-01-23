import 'package:hive/hive.dart';

part 'condition.g.dart';

@HiveType(typeId: 19)
enum ConditionType {
  @HiveField(0)
  blinded,
  @HiveField(1)
  charmed,
  @HiveField(2)
  deafened,
  @HiveField(3)
  frightened,
  @HiveField(4)
  grappled,
  @HiveField(5)
  incapacitated,
  @HiveField(6)
  invisible,
  @HiveField(7)
  paralyzed,
  @HiveField(8)
  petrified,
  @HiveField(9)
  poisoned,
  @HiveField(10)
  prone,
  @HiveField(11)
  restrained,
  @HiveField(12)
  stunned,
  @HiveField(13)
  unconscious,
}

extension ConditionTypeExtension on ConditionType {
  String get displayName {
    final name = toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1);
  }

  Map<String, String> get description {
    switch (this) {
      case ConditionType.blinded:
        return {
          'en': 'Cannot see. Auto-fail sight checks. Attacks against: advantage. Your attacks: disadvantage.',
          'ru': 'Не видит. Автопровал проверок зрения. Атаки по вам: с преимуществом. Ваши атаки: с помехой.',
        };
      case ConditionType.charmed:
        return {
          'en': 'Cannot attack charmer. Charmer has advantage on social checks.',
          'ru': 'Не можете атаковать очаровавшего. Он имеет преимущество в социальных проверках.',
        };
      case ConditionType.deafened:
        return {
          'en': 'Cannot hear. Auto-fail hearing checks.',
          'ru': 'Не слышит. Автопровал проверок слуха.',
        };
      case ConditionType.frightened:
        return {
          'en': 'Disadvantage on checks while source is in sight. Cannot move closer to source.',
          'ru': 'Помеха на проверки, пока источник виден. Не можете приблизиться к источнику.',
        };
      case ConditionType.grappled:
        return {
          'en': 'Speed = 0. Cannot benefit from speed bonuses.',
          'ru': 'Скорость = 0. Не получаете бонусов к скорости.',
        };
      case ConditionType.incapacitated:
        return {
          'en': 'Cannot take actions or reactions.',
          'ru': 'Не можете совершать действия или реакции.',
        };
      case ConditionType.invisible:
        return {
          'en': 'Cannot be seen. Attacks: advantage. Attacks against: disadvantage.',
          'ru': 'Невидимы. Ваши атаки: с преимуществом. Атаки по вам: с помехой.',
        };
      case ConditionType.paralyzed:
        return {
          'en': 'Incapacitated. Cannot move or speak. Auto-fail STR/DEX saves. Attacks against: advantage. Melee hits = critical.',
          'ru': 'Недееспособен. Не можете двигаться/говорить. Автопровал СИЛ/ЛОВ. Атаки по вам: преимущество. Ближний бой = крит.',
        };
      case ConditionType.petrified:
        return {
          'en': 'Incapacitated. Cannot move or speak. Resistance to all damage. Immune to poison/disease.',
          'ru': 'Недееспособен. Не можете двигаться/говорить. Сопротивление всему урону. Иммунитет к яду/болезням.',
        };
      case ConditionType.poisoned:
        return {
          'en': 'Disadvantage on attack rolls and ability checks.',
          'ru': 'Помеха на броски атаки и проверки характеристик.',
        };
      case ConditionType.prone:
        return {
          'en': 'Disadvantage on attack rolls. Melee attacks against: advantage. Ranged attacks against: disadvantage.',
          'ru': 'Помеха на броски атаки. Ближние атаки по вам: преимущество. Дальние: помеха.',
        };
      case ConditionType.restrained:
        return {
          'en': 'Speed = 0. Attacks: disadvantage. DEX saves: disadvantage. Attacks against: advantage.',
          'ru': 'Скорость = 0. Атаки: помеха. Спасброски ЛОВ: помеха. Атаки по вам: преимущество.',
        };
      case ConditionType.stunned:
        return {
          'en': 'Incapacitated. Cannot move. Can only speak falteringly. Auto-fail STR/DEX saves. Attacks against: advantage.',
          'ru': 'Недееспособен. Не можете двигаться. Говорите с трудом. Автопровал СИЛ/ЛОВ. Атаки по вам: преимущество.',
        };
      case ConditionType.unconscious:
        return {
          'en': 'Incapacitated. Cannot move or speak. Unaware of surroundings. Drop held items. Fall prone. Auto-fail STR/DEX saves. Attacks against: advantage. Melee hits = critical.',
          'ru': 'Недееспособен. Без сознания. Роняете предметы. Падаете ничком. Автопровал СИЛ/ЛОВ. Атаки: преимущество. Ближний бой = крит.',
        };
    }
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en']!;
  }
}
