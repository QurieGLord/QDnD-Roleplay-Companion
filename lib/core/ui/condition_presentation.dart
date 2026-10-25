import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../models/condition.dart';

abstract final class ConditionPresentation {
  static String label(AppLocalizations l, ConditionType c) => switch (c) {
        ConditionType.blinded => l.conditionBlinded,
        ConditionType.charmed => l.conditionCharmed,
        ConditionType.deafened => l.conditionDeafened,
        ConditionType.frightened => l.conditionFrightened,
        ConditionType.grappled => l.conditionGrappled,
        ConditionType.incapacitated => l.conditionIncapacitated,
        ConditionType.invisible => l.conditionInvisible,
        ConditionType.paralyzed => l.conditionParalyzed,
        ConditionType.petrified => l.conditionPetrified,
        ConditionType.poisoned => l.conditionPoisoned,
        ConditionType.prone => l.conditionProne,
        ConditionType.restrained => l.conditionRestrained,
        ConditionType.stunned => l.conditionStunned,
        ConditionType.unconscious => l.conditionUnconscious,
      };

  static IconData icon(ConditionType c) => switch (c) {
        ConditionType.blinded => Icons.visibility_off_outlined,
        ConditionType.charmed => Icons.favorite_outline,
        ConditionType.deafened => Icons.hearing_disabled_outlined,
        ConditionType.frightened => Icons.warning_amber_rounded,
        ConditionType.grappled => Icons.front_hand_outlined,
        ConditionType.incapacitated => Icons.block,
        ConditionType.invisible => Icons.blur_on,
        ConditionType.paralyzed => Icons.pause_circle_outline,
        ConditionType.petrified => Icons.landscape_outlined,
        ConditionType.poisoned => Icons.science_outlined,
        ConditionType.prone => Icons.airline_seat_flat,
        ConditionType.restrained => Icons.link,
        ConditionType.stunned => Icons.bolt_outlined,
        ConditionType.unconscious => Icons.bedtime_outlined,
      };

  /// The prototype's glyph of each condition (wave 3, `CONDS`).
  static String glyph(ConditionType c) => switch (c) {
        ConditionType.blinded => 'eye',
        ConditionType.charmed => 'heart',
        ConditionType.deafened => 'wave',
        ConditionType.frightened => 'skull',
        ConditionType.grappled => 'hand',
        ConditionType.incapacitated => 'x',
        ConditionType.invisible => 'mask',
        ConditionType.paralyzed => 'lock',
        ConditionType.petrified => 'peaks',
        ConditionType.poisoned => 'drop',
        ConditionType.prone => 'down',
        ConditionType.restrained => 'track',
        ConditionType.stunned => 'spark',
        ConditionType.unconscious => 'moon',
      };

  /// Its accent `a0`…`a5`.
  static int accent(ConditionType c) => switch (c) {
        ConditionType.blinded => 0,
        ConditionType.charmed => 0,
        ConditionType.deafened => 4,
        ConditionType.frightened => 5,
        ConditionType.grappled => 1,
        ConditionType.incapacitated => 0,
        ConditionType.invisible => 5,
        ConditionType.paralyzed => 0,
        ConditionType.petrified => 1,
        ConditionType.poisoned => 3,
        ConditionType.prone => 2,
        ConditionType.restrained => 2,
        ConditionType.stunned => 1,
        ConditionType.unconscious => 5,
      };

  /// What it does, in one line; the full rule lives behind a hold.
  static String line(ConditionType c, bool ru) => switch (c) {
        ConditionType.blinded => ru
            ? 'Атаки по вам — с преимуществом, ваши — с помехой'
            : 'Attacks against you have advantage, yours disadvantage',
        ConditionType.charmed => ru
            ? 'Не атакуете очарователя, он — с преимуществом в общении'
            : 'You cannot attack the charmer; they have advantage socially',
        ConditionType.deafened => ru
            ? 'Проваливаете проверки, где нужен слух'
            : 'You fail checks that need hearing',
        ConditionType.frightened => ru
            ? 'Помеха, пока видите источник; не приближаетесь к нему'
            : 'Disadvantage while you see the source; you cannot approach it',
        ConditionType.grappled => ru ? 'Скорость 0' : 'Speed 0',
        ConditionType.incapacitated =>
          ru ? 'Ни действий, ни реакций' : 'No actions or reactions',
        ConditionType.invisible => ru
            ? 'Ваши атаки с преимуществом, по вам — с помехой'
            : 'Your attacks have advantage, attacks on you disadvantage',
        ConditionType.paralyzed => ru
            ? 'Недееспособен; попадание вблизи — критическое'
            : 'Incapacitated; a hit from nearby is critical',
        ConditionType.petrified => ru
            ? 'Недееспособен, сопротивление всему урону'
            : 'Incapacitated, resistant to all damage',
        ConditionType.poisoned => ru
            ? 'Помеха на атаки и проверки'
            : 'Disadvantage on attacks and checks',
        ConditionType.prone => ru
            ? 'Ползком; атаки вблизи по вам — с преимуществом'
            : 'Crawl; melee attacks against you have advantage',
        ConditionType.restrained => ru
            ? 'Скорость 0; атаки по вам с преимуществом'
            : 'Speed 0; attacks against you have advantage',
        ConditionType.stunned => ru
            ? 'Недееспособен, проваливаете спасброски СИЛ и ЛОВ'
            : 'Incapacitated, you fail STR and DEX saves',
        ConditionType.unconscious => ru
            ? 'Недееспособен, падает; попадание вблизи — крит'
            : 'Incapacitated and prone; a hit from nearby is critical',
      };
}
