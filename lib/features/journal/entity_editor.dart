import '../../core/ui/app_menu_style.dart';
import 'package:flutter/material.dart';
import '../../core/journal/journal_graph.dart';
import 'journal_strings.dart';
import '../../core/ui/sheet_drag_region.dart';

Future<JournalEntity?> editJournalEntity(BuildContext context,
    {JournalEntity? entity,
    String name = '',
    JournalEntityKind kind = JournalEntityKind.person}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<JournalEntity>(
      context: context,
      requestFocus: false,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => SheetSafeArea(child: _EntityEditor(entity: entity, name: name, kind: kind)));
}

class _EntityEditor extends StatefulWidget {
  const _EntityEditor({this.entity, required this.name, required this.kind});
  final JournalEntity? entity;
  final String name;
  final JournalEntityKind kind;
  @override
  State<_EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends State<_EntityEditor> {
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.entity?.name ?? widget.name);
  late final _aliases =
      TextEditingController(text: widget.entity?.aliases.join(', ') ?? '');
  late final _description =
      TextEditingController(text: widget.entity?.description ?? '');
  late var _kind = widget.entity?.kind ?? widget.kind;
  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context);
    return SafeArea(
        top: false,
        child: SheetScrollDismiss(
            child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SheetDragRegion(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                                widget.entity == null
                                    ? s.t('Новая история', 'New story')
                                    : s.t(
                                        'Об этой истории', 'About this story'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall))),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                            labelText:
                                s.t('Имя или название', 'Name or title')),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? s.t('Добавь название', 'Add a name')
                            : null),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<JournalEntityKind>(
                        borderRadius: AppMenuStyle.radius,
                        dropdownColor: AppMenuStyle.background(context),
                        elevation: 4,
                        initialValue: _kind,
                        decoration:
                            InputDecoration(labelText: s.t('Тип', 'Type')),
                        items: [
                          for (final k in JournalEntityKind.values)
                            DropdownMenuItem(value: k, child: Text(s.kind(k)))
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _kind = v);
                        }),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                            labelText: s.t(
                                'Кто это или что это', 'Who or what is this'),
                            hintText: s.t(
                                'Например: сын Альдрена, ищем в гавани',
                                'For example: Aldren’s son, last seen at the haven'))),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: _aliases,
                        decoration: InputDecoration(
                            labelText: s.t('Другие имена · через запятую',
                                'Other names · comma separated'),
                            helperText: s.t(
                                'Прозвища и написания, которым можно доверять',
                                'Nicknames and spellings you trust'))),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: () {
                              if (!_form.currentState!.validate()) return;
                              Navigator.pop(
                                  context,
                                  JournalEntity(
                                      id: widget.entity?.id,
                                      name: _name.text.trim(),
                                      kind: _kind,
                                      description: _description.text.trim(),
                                      aliases: _aliases.text
                                          .split(',')
                                          .map((a) => a.trim())
                                          .where((a) =>
                                              a.isNotEmpty &&
                                              a != _name.text.trim())
                                          .toSet()
                                          .toList()));
                            },
                            child: Text(s.t('Подтвердить', 'Confirm')))),
                  ])),
        )));
  }
}
