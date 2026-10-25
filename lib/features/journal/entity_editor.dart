import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/ui/companion_kit.dart';
import 'journal_kit.dart';
import 'journal_strings.dart';

/// A name of the Atlas, new or known: what it is called, what kind of thing
/// it is, its other names and a line about it. With [onDelete] the sheet
/// also offers to take the name out of the Atlas.
Future<JournalEntity?> editJournalEntity(BuildContext context,
    {JournalEntity? entity,
    String name = '',
    JournalEntityKind kind = JournalEntityKind.person,
    VoidCallback? onDelete}) async {
  final delete = Object();
  final result = await showCompanionSheet<Object>(context,
      builder: (_) => _EntityEditor(
          entity: entity,
          name: name,
          kind: kind,
          deleteToken: onDelete == null ? null : delete));
  if (identical(result, delete)) {
    onDelete!();
    return null;
  }
  return result is JournalEntity ? result : null;
}

class _EntityEditor extends StatefulWidget {
  const _EntityEditor(
      {this.entity, required this.name, required this.kind, this.deleteToken});
  final JournalEntity? entity;
  final String name;
  final JournalEntityKind kind;
  final Object? deleteToken;
  @override
  State<_EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends State<_EntityEditor> {
  late final _name =
      TextEditingController(text: widget.entity?.name ?? widget.name);
  late final _aliases =
      TextEditingController(text: widget.entity?.aliases.join(', ') ?? '');
  late final _description =
      TextEditingController(text: widget.entity?.description ?? '');
  late var _kind = widget.entity?.kind ?? widget.kind;
  bool _missing = false;

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    _description.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _missing = true);
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop(
        context,
        JournalEntity(
            id: widget.entity?.id,
            name: name,
            kind: _kind,
            description: _description.text.trim(),
            aliases: _aliases.text
                .split(',')
                .map((a) => a.trim())
                .where((a) => a.isNotEmpty && a != name)
                .toSet()
                .toList()));
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.t('Атлас', 'Atlas'),
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: c.secondary)),
      const SizedBox(height: 8),
      SheetHeading(widget.entity == null
          ? s.t('Новое имя', 'A new name')
          : s.t('Изменить', 'Edit')),
      const SizedBox(height: 14),
      JournalField(
          controller: _name,
          label: s.t('Имя или название', 'Name or title'),
          fieldKey: const ValueKey('journal-entity-name'),
          onChanged: (_) {
            if (_missing) setState(() => _missing = false);
          }),
      if (_missing) ...[
        const SizedBox(height: 6),
        Text(s.t('Нужно имя', 'A name is needed'),
            style: TextStyle(fontSize: 12.5, color: c.error)),
      ],
      const SizedBox(height: 14),
      JournalKindGrid<JournalEntityKind>(
          values: JournalEntityKind.values,
          selected: _kind,
          icon: JournalLook.kindIcon,
          accent: JournalLook.kindAccent,
          label: s.kind,
          onPick: (k) => setState(() => _kind = k)),
      const SizedBox(height: 14),
      JournalField(
          controller: _aliases,
          label: s.t('Другие имена — через запятую',
              'Other names — comma separated')),
      const SizedBox(height: 14),
      JournalField(
          controller: _description,
          maxLines: 3,
          label: s.t('Кто это или что', 'Who or what it is'),
          hint: s.t('Например: сын Альдрена, ищем в гавани',
              'For example: Aldren’s son, last seen at the haven')),
      const SizedBox(height: 18),
      ToneButton(
          key: const ValueKey('journal-entity-save'),
          label: s.t('Сохранить', 'Save'),
          kind: ToneKind.primary,
          height: 52,
          expand: true,
          onPressed: _confirm),
      if (widget.deleteToken != null) ...[
        const SizedBox(height: 8),
        ToneButton(
            key: const ValueKey('journal-entity-delete'),
            label: s.t('Убрать из Атласа', 'Remove from the Atlas'),
            height: 48,
            expand: true,
            onPressed: () => Navigator.pop(context, widget.deleteToken)),
      ],
    ]);
  }
}
