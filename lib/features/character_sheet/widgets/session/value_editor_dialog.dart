import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class SheetNumberField {
  const SheetNumberField(this.id, this.label, this.value,
      {this.hint, this.minimum = 0, this.maximum});
  final String id, label;
  final int value, minimum;
  final int? maximum;
  final String? hint;
}

Future<bool> showSheetValueEditor(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<SheetNumberField> fields,
  required Future<void> Function(Map<String, int> values, bool automatic)
      onSave,
  String? description,
  Widget? content,
  int? calculatedValue,
  bool initiallyAutomatic = false,
  String? actionLabel,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  return await showModalBottomSheet<bool>(
        context: context,
        requestFocus: false,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: Duration(milliseconds: 300),
                reverseDuration: Duration(milliseconds: 220)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xlPlus))),
        builder: (_) => SheetSafeArea(child: _SheetValueEditor(
            title: title,
            icon: icon,
            fields: fields,
            onSave: onSave,
            description: description,
            content: content,
            calculatedValue: calculatedValue,
            initiallyAutomatic: initiallyAutomatic,
            actionLabel: actionLabel)),
      ) ??
      false;
}

class _SheetValueEditor extends StatefulWidget {
  const _SheetValueEditor(
      {required this.title,
      required this.icon,
      required this.fields,
      required this.onSave,
      this.description,
      this.content,
      this.calculatedValue,
      this.initiallyAutomatic = false,
      this.actionLabel});
  final String title;
  final IconData icon;
  final List<SheetNumberField> fields;
  final Future<void> Function(Map<String, int>, bool) onSave;
  final String? description;
  final Widget? content;
  final int? calculatedValue;
  final bool initiallyAutomatic;
  final String? actionLabel;
  @override
  State<_SheetValueEditor> createState() => _SheetValueEditorState();
}

class _SheetValueEditorState extends State<_SheetValueEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late bool _automatic;
  bool _saving = false, _failed = false;
  @override
  void initState() {
    super.initState();
    _automatic = widget.initiallyAutomatic;
    _controllers = {
      for (final field in widget.fields)
        field.id: TextEditingController(text: '${field.value}')
    };
    if (_controllers.isNotEmpty) {
      final first = _controllers.values.first;
      first.selection =
          TextSelection(baseOffset: 0, extentOffset: first.text.length);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave({
        for (final field in widget.fields)
          field.id: int.tryParse(_controllers[field.id]!.text) ?? field.value
      }, _automatic);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: KeyboardPadding(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetDragRegion(
              key: const ValueKey('sheet-value-header'),
              enabled: !_saving,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    key: const ValueKey('sheet-value-drag-handle'),
                    height: 44,
                    width: double.infinity,
                    child: Center(
                        child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: .45),
                                borderRadius: BorderRadius.circular(AppRadii.pill))))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                            child: Icon(widget.icon,
                                color: theme.colorScheme.onSecondaryContainer)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Text(widget.title,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700))),
                      ]),
                    ])),
              ])),
          Flexible(
              child: SheetScrollDismiss(
                  enabled: !_saving,
                  child: SingleChildScrollView(
                    key: const ValueKey('sheet-value-editor'),
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            if (widget.description != null) ...[
                              Text(widget.description!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 20),
                            ],
                            if (widget.content != null) widget.content!,
                            if (widget.calculatedValue != null) ...[
                              SwitchListTile(
                                  key: const ValueKey('sheet-auto-value'),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(l10n.sheetAutomaticCalculation),
                                  subtitle: Text(l10n.gameStateArmorCalculated(
                                      widget.calculatedValue!)),
                                  value: _automatic,
                                  onChanged: _saving
                                      ? null
                                      : (value) =>
                                          setState(() => _automatic = value)),
                              const SizedBox(height: 16),
                            ],
                            for (int i = 0; i < widget.fields.length; i++) ...[
                              TextFormField(
                                key: ValueKey(
                                    'sheet-value-${widget.fields[i].id}'),
                                controller: _controllers[widget.fields[i].id],
                                enabled: !_saving &&
                                    !(widget.calculatedValue != null &&
                                        _automatic),
                                autofocus: false,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                keyboardType: TextInputType.number,
                                textInputAction: i == widget.fields.length - 1
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                decoration: InputDecoration(
                                    labelText: widget.fields[i].label,
                                    helperText: widget.fields[i].hint,
                                    helperMaxLines: 3,
                                    filled: true,
                                    fillColor:
                                        theme.colorScheme.surfaceContainerHigh,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                                        borderSide: BorderSide.none)),
                                validator: (text) {
                                  if (widget.calculatedValue != null &&
                                      _automatic) {
                                    return null;
                                  }
                                  final field = widget.fields[i];
                                  final value = int.tryParse(text ?? '');
                                  if (value == null ||
                                      value < field.minimum ||
                                      (field.maximum != null &&
                                          value > field.maximum!)) {
                                    return field.maximum == null
                                        ? (field.minimum > 0
                                            ? l10n.sheetPositiveAmount
                                            : l10n.gameStateNumbersOnly)
                                        : l10n.sheetNumberRange(
                                            field.minimum, field.maximum!);
                                  }
                                  return null;
                                },
                              ),
                              if (i < widget.fields.length - 1)
                                const SizedBox(height: 14),
                            ],
                            if (_failed) ...[
                              const SizedBox(height: 16),
                              Text(l10n.sheetSaveFailed,
                                  key: const ValueKey('sheet-value-save-error'),
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                            ],
                            const SizedBox(height: 24),
                            Row(children: [
                              Expanded(
                                  child: TextButton(
                                      onPressed: _saving
                                          ? null
                                          : () => Navigator.pop(context, false),
                                      child: Text(l10n.cancel))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: FilledButton(
                                      key: const ValueKey('sheet-value-save'),
                                      onPressed: _saving ? null : _save,
                                      style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 52)),
                                      child: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : Text(widget.actionLabel ??
                                              l10n.save))),
                            ]),
                          ]),
                    ),
                  ))),
        ])),
    );
  }
}
