import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';

Future<void> showWildShapeEditor(BuildContext context,
        {required Future<bool> Function(int, String) onSubmit}) =>
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _WildShapeEditor(onSubmit: onSubmit));

class _WildShapeEditor extends StatefulWidget {
  const _WildShapeEditor({required this.onSubmit});
  final Future<bool> Function(int, String) onSubmit;
  @override
  State<_WildShapeEditor> createState() => _WildShapeEditorState();
}

class _WildShapeEditorState extends State<_WildShapeEditor> {
  final _hp = TextEditingController(), _name = TextEditingController();
  bool _busy = false, _invalid = false;
  @override
  void dispose() {
    _hp.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru',
        theme = Theme.of(context),
        c = theme.colorScheme;
    return PopScope(
        canPop: !_busy,
        child: KeyboardPadding(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                24, 12, 24, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ru ? 'Дикий облик' : 'Wild Shape',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                      ru
                          ? 'Выбери зверя по правилам своего круга. Его ОЗ будут учитываться отдельно.'
                          : 'Choose a beast allowed by your circle. Its HP is tracked separately.',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  CompanionSurface(
                      contour: CompanionContour.soft,
                      quiet: true,
                      child: Column(children: [
                        TextField(
                            controller: _name,
                            enabled: !_busy,
                            autofocus: false,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                                labelText: ru ? 'Зверь' : 'Beast',
                                hintText: ru
                                    ? 'Например, бурый медведь'
                                    : 'For example, brown bear')),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _hp,
                            enabled: !_busy,
                            autofocus: false,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: ru ? 'ОЗ зверя' : 'Beast HP',
                                errorText: _invalid
                                    ? (ru
                                        ? 'Введи целое число больше нуля'
                                        : 'Enter a positive whole number')
                                    : null)),
                      ])),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: c.secondary,
                          foregroundColor: c.onSecondary),
                      onPressed: _busy
                          ? null
                          : () async {
                              final hp = int.tryParse(_hp.text.trim());
                              if (hp == null || hp < 1) {
                                setState(() => _invalid = true);
                                return;
                              }
                              setState(() {
                                _busy = true;
                                _invalid = false;
                              });
                              var saved = false;
                              try {
                                saved = await widget.onSubmit(
                                    hp, _name.text.trim());
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(ru
                                              ? 'Не удалось сохранить облик.'
                                              : 'Could not save Wild Shape.')));
                                }
                              }
                              if (!context.mounted) return;
                              setState(() => _busy = false);
                              if (saved) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.pets_rounded),
                      label: Text(ru ? 'Принять облик' : 'Transform')),
                ]))));
  }
}
