import '../../core/ui/sheet_drag_region.dart';
import 'package:flutter/material.dart';
import '../../core/journal/journal_graph.dart';
import 'journal_strings.dart';

Widget journalSelectionToolbar(
    BuildContext context, EditableTextState state, void Function(String) onLink,
    {bool enabled = true}) {
  final selection = state.widget.controller.selection;
  final text = selection.isValid && !selection.isCollapsed
      ? selection.textInside(state.widget.controller.text).trim()
      : '';
  final s = JournalStrings(context);
  return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        ...state.contextMenuButtonItems,
        if (enabled && text.isNotEmpty)
          ContextMenuButtonItem(
              label: s.t('Связать с историей', 'Link to story'),
              onPressed: () {
                state.hideToolbar();
                onLink(text);
              }),
      ]);
}

Future<String?> chooseSelectionStory(
    BuildContext context, String text, List<JournalEntity> entities) {
  final s = JournalStrings(context);
  return showResponsiveSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .6,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(text, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ListTile(
                        leading: const Icon(Icons.add),
                        title: Text(s.t('Создать историю из выделения',
                            'Create a story from selection')),
                        onTap: () => Navigator.pop(context, 'new')),
                    for (final entity in entities)
                      ListTile(
                          leading: Icon(s.icon(entity.kind)),
                          title: Text(entity.name),
                          subtitle: entity.description.isEmpty
                              ? null
                              : Text(entity.description),
                          onTap: () => Navigator.pop(context, entity.id)),
                  ]))));
}
