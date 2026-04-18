import 'package:flutter/material.dart';

IconData resolveAbilitiesFeatureIcon(String? iconName) {
  switch (iconName) {
    case 'healing':
      return Icons.favorite;
    case 'visibility':
      return Icons.visibility;
    case 'flash_on':
      return Icons.flash_on;
    case 'swords':
      return Icons.shield;
    case 'auto_fix_high':
      return Icons.auto_fix_high;
    case 'health_and_safety':
      return Icons.health_and_safety;
    case 'auto_awesome':
      return Icons.auto_awesome;
    case 'filter_2':
      return Icons.filter_2;
    case 'security':
      return Icons.security;
    case 'back_hand':
      return Icons.back_hand;
    case 'wifi_tethering':
      return Icons.wifi_tethering;
    default:
      return Icons.star;
  }
}
