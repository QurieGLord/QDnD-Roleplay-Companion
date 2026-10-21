import 'package:flutter/widgets.dart';

import '../../core/search/spell_catalog.dart';

class AlmanacStrings {
  AlmanacStrings(BuildContext context)
      : ru = Localizations.localeOf(context).languageCode == 'ru';
  final bool ru;
  String t(String ru, String en) => this.ru ? ru : en;
  String availability(AlmanacAvailability value) => switch (value) {
        AlmanacAvailability.all => t('Все заклинания', 'All spells'),
        AlmanacAvailability.now => t('Доступно сейчас', 'Available now'),
        AlmanacAvailability.classList => t('По моим классам', 'My class lists'),
        AlmanacAvailability.future => t('Впереди', 'Ahead'),
        AlmanacAvailability.known => t('В моём листе', 'On my sheet'),
      };
  String property(AlmanacProperty p) => switch (p) {
        AlmanacProperty.any => t('Любые', 'Any'),
        AlmanacProperty.yes => t('Да', 'Yes'),
        AlmanacProperty.no => t('Нет', 'No'),
      };
}
