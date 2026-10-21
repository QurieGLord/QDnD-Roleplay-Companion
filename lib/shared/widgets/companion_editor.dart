import 'package:flutter/material.dart';
import '../../core/magic/companion_state.dart';
import '../../core/models/character.dart';
import '../../core/services/class_session_actions_service.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';

Future<bool?> showCompanionEditor(BuildContext context, Character hero) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CompanionEditor(hero));

class _CompanionEditor extends StatefulWidget {
  const _CompanionEditor(this.hero);
  final Character hero;
  @override
  State<_CompanionEditor> createState() => _CompanionEditorState();
}

class _CompanionEditorState extends State<_CompanionEditor> {
  final _form = GlobalKey<FormState>();
  late final CompanionState? _before;
  late final TextEditingController _name, _current, _maximum;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _before = CompanionState.read(widget.hero);
    _name = TextEditingController(text: _before?.name ?? '');
    _current = TextEditingController(text: '${_before?.current ?? 0}');
    _maximum = TextEditingController(text: '${_before?.maximum ?? 0}');
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru',
        t = Theme.of(context);
    String? number(String? value) {
      final n = int.tryParse(value?.trim() ?? '');
      return n == null || n < 0
          ? (ru
              ? 'Введи целое число от нуля'
              : 'Enter a whole number of zero or more')
          : null;
    }

    return PopScope(
        canPop: !_busy,
        child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
            child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ru ? 'Зверь-спутник' : 'Beast companion',
                          style: t.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(
                          ru
                              ? 'ОЗ спутника учитываются отдельно от ОЗ героя и Дикого облика.'
                              : 'Your companion’s HP is tracked separately from your hero and Wild Shape.',
                          style: t.textTheme.bodyLarge),
                      const SizedBox(height: 20),
                      CompanionSurface(
                          quiet: true,
                          contour: CompanionContour.soft,
                          child: Column(children: [
                            TextFormField(
                                controller: _name,
                                enabled: !_busy,
                                autofocus: false,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                    labelText:
                                        ru ? 'Имя спутника' : 'Companion name'),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? (ru ? 'Укажи имя' : 'Enter a name')
                                    : null),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _current,
                                enabled: !_busy,
                                autofocus: false,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText:
                                        ru ? 'Текущие ОЗ' : 'Current HP'),
                                validator: number),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _maximum,
                                enabled: !_busy,
                                autofocus: false,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: ru
                                        ? 'Обычный максимум'
                                        : 'Normal maximum'),
                                validator: number),
                          ])),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (!_form.currentState!.validate()) return;
                                  setState(() => _busy = true);
                                  try {
                                    await ClassSessionActionsService
                                        .editCompanion(
                                            widget.hero,
                                            CompanionState(
                                                name: _name.text.trim(),
                                                current: int.parse(
                                                    _current.text.trim()),
                                                maximum: int.parse(
                                                    _maximum.text.trim())),
                                            expected: _before);
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    setState(() => _busy = false);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(ru
                                            ? 'Не удалось сохранить. Открой данные спутника заново.'
                                            : 'Could not save. Reopen the companion’s details.')));
                                  }
                                },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                              ru ? 'Сохранить спутника' : 'Save companion')),
                    ]))));
  }
}
