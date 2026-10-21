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
}
