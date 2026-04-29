import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../character_creation_state.dart';

const double _kBasicInfoMaxWidth = 720;
const Duration _kBasicFastMotion = Duration(milliseconds: 160);
const Duration _kBasicRevealMotion = Duration(milliseconds: 280);

Duration _basicMotionDuration(BuildContext context, Duration duration) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}

void _playSelectionHaptic() {
  if (!kIsWeb) {
    HapticFeedback.selectionClick();
  }
}

class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _genderController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _eyesController;
  late final TextEditingController _hairController;
  late final TextEditingController _skinController;
  late final TextEditingController _traitsController;
  late final TextEditingController _idealsController;
  late final TextEditingController _bondsController;
  late final TextEditingController _flawsController;
  late final TextEditingController _appearanceController;
  late final TextEditingController _backstoryController;
  late final ScrollController _scrollController;

  bool _avatarPressed = false;

  static const List<_AlignmentOption> _alignmentOptions = [
    _AlignmentOption(
      keyName: 'Lawful Good',
      code: 'LG',
      icon: Icons.account_balance_rounded,
    ),
    _AlignmentOption(
      keyName: 'Neutral Good',
      code: 'NG',
      icon: Icons.favorite_rounded,
    ),
    _AlignmentOption(
      keyName: 'Chaotic Good',
      code: 'CG',
      icon: Icons.local_fire_department_rounded,
    ),
    _AlignmentOption(
      keyName: 'Lawful Neutral',
      code: 'LN',
      icon: Icons.gavel_rounded,
    ),
    _AlignmentOption(
      keyName: 'True Neutral',
      code: 'TN',
      icon: Icons.balance_rounded,
    ),
    _AlignmentOption(
      keyName: 'Chaotic Neutral',
      code: 'CN',
      icon: Icons.shuffle_rounded,
    ),
    _AlignmentOption(
      keyName: 'Lawful Evil',
      code: 'LE',
      icon: Icons.shield_rounded,
    ),
    _AlignmentOption(
      keyName: 'Neutral Evil',
      code: 'NE',
      icon: Icons.warning_rounded,
    ),
    _AlignmentOption(
      keyName: 'Chaotic Evil',
      code: 'CE',
      icon: Icons.whatshot_rounded,
    ),
  ];

  static const Map<String, Color> _eyeColorValues = {
    'Amber': Color(0xFFFFBF00),
    'Blue': Color(0xFF4169E1),
    'Brown': Color(0xFF8B4513),
    'Gray': Color(0xFF808080),
    'Green': Color(0xFF228B22),
    'Hazel': Color(0xFFA0785A),
    'Red': Color(0xFFDC143C),
    'Violet': Color(0xFF8B00FF),
    'Custom': Colors.grey,
  };

  static const Map<String, Color> _hairColorValues = {
    'Auburn': Color(0xFFA52A2A),
    'Black': Color(0xFF000000),
    'Blonde': Color(0xFFFAF0BE),
    'Brown': Color(0xFF654321),
    'Gray': Color(0xFF808080),
    'Red': Color(0xFFFF0000),
    'White': Color(0xFFF5F5F5),
    'Bald': Colors.transparent,
    'Custom': Colors.grey,
  };

  static const Map<String, Color> _skinToneValues = {
    'Pale': Color(0xFFFFF0E1),
    'Fair': Color(0xFFFFE4C4),
    'Light': Color(0xFFFFDDB3),
    'Medium': Color(0xFFE8B98A),
    'Tan': Color(0xFFD2A574),
    'Brown': Color(0xFFA67C52),
    'Dark': Color(0xFF8B6F47),
    'Ebony': Color(0xFF4A3728),
    'Custom': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    final state = context.read<CharacterCreationState>();
    _scrollController = ScrollController();
    _nameController = TextEditingController(text: state.name);
    _ageController = TextEditingController(text: state.age);
    _genderController = TextEditingController(text: state.gender);
    _heightController = TextEditingController(text: state.height);
    _weightController = TextEditingController(text: state.weight);
    _eyesController = TextEditingController(text: state.eyes);
    _hairController = TextEditingController(text: state.hair);
    _skinController = TextEditingController(text: state.skin);
    _traitsController = TextEditingController(text: state.personalityTraits);
    _idealsController = TextEditingController(text: state.ideals);
    _bondsController = TextEditingController(text: state.bonds);
    _flawsController = TextEditingController(text: state.flaws);
    _appearanceController =
        TextEditingController(text: state.appearanceDescription);
    _backstoryController = TextEditingController(text: state.backstory);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _eyesController.dispose();
    _hairController.dispose();
    _skinController.dispose();
    _traitsController.dispose();
    _idealsController.dispose();
    _bondsController.dispose();
    _flawsController.dispose();
    _appearanceController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  String _getAlignmentName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'Lawful Good':
        return l10n.lg;
      case 'Neutral Good':
        return l10n.ng;
      case 'Chaotic Good':
        return l10n.cg;
      case 'Lawful Neutral':
        return l10n.ln;
      case 'True Neutral':
        return l10n.tn;
      case 'Chaotic Neutral':
        return l10n.cn;
      case 'Lawful Evil':
        return l10n.le;
      case 'Neutral Evil':
        return l10n.ne;
      case 'Chaotic Evil':
        return l10n.ce;
      default:
        return key;
    }
  }

  String _getAlignmentCode(AppLocalizations l10n, String key) {
    switch (key) {
      case 'Lawful Good':
        return l10n.alignmentCodeLg;
      case 'Neutral Good':
        return l10n.alignmentCodeNg;
      case 'Chaotic Good':
        return l10n.alignmentCodeCg;
      case 'Lawful Neutral':
        return l10n.alignmentCodeLn;
      case 'True Neutral':
        return l10n.alignmentCodeTn;
      case 'Chaotic Neutral':
        return l10n.alignmentCodeCn;
      case 'Lawful Evil':
        return l10n.alignmentCodeLe;
      case 'Neutral Evil':
        return l10n.alignmentCodeNe;
      case 'Chaotic Evil':
        return l10n.alignmentCodeCe;
      default:
        return key;
    }
  }

  String _getLocalizedColor(AppLocalizations l10n, String color) {
    switch (color) {
      case 'Amber':
        return l10n.colorAmber;
      case 'Blue':
        return l10n.colorBlue;
      case 'Brown':
        return l10n.colorBrown;
      case 'Gray':
        return l10n.colorGray;
      case 'Green':
        return l10n.colorGreen;
      case 'Hazel':
        return l10n.colorHazel;
      case 'Red':
        return l10n.colorRed;
      case 'Violet':
        return l10n.colorViolet;
      case 'Auburn':
        return l10n.colorAuburn;
      case 'Black':
        return l10n.colorBlack;
      case 'Blonde':
        return l10n.colorBlonde;
      case 'White':
        return l10n.colorWhite;
      case 'Bald':
        return l10n.colorBald;
      case 'Pale':
        return l10n.skinPale;
      case 'Fair':
        return l10n.skinFair;
      case 'Light':
        return l10n.skinLight;
      case 'Medium':
        return l10n.skinMedium;
      case 'Tan':
        return l10n.skinTan;
      case 'Dark':
        return l10n.skinDark;
      case 'Ebony':
        return l10n.skinEbony;
      case 'Custom':
        return l10n.custom;
      default:
        return color;
    }
  }

  Future<void> _pickAvatar(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null &&
          result.files.single.path != null &&
          context.mounted) {
        final pickedFile = File(result.files.single.path!);

        final appDir = await getApplicationDocumentsDirectory();
        final avatarsDir = Directory('${appDir.path}/avatars');
        if (!await avatarsDir.exists()) {
          await avatarsDir.create(recursive: true);
        }

        final fileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.${result.files.single.extension ?? 'jpg'}';
        final savedFile = File('${avatarsDir.path}/$fileName');
        await pickedFile.copy(savedFile.path);

        if (context.mounted) {
          context
              .read<CharacterCreationState>()
              .updateAvatarPath(savedFile.path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Failed to pick avatar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final constraints = MediaQuery.sizeOf(context);
    final horizontalPadding = constraints.width < 420 ? 16.0 : 24.0;

    return ListView(
      key: const Key('basic_info_scroll_view'),
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        18,
        horizontalPadding,
        132,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kBasicInfoMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BasicReveal(
                  key: const Key('basic_info_reveal_identity'),
                  scrollController: _scrollController,
                  delay: Duration.zero,
                  child: _buildIdentityBlock(context, state),
                ),
                const SizedBox(height: 16),
                _BasicReveal(
                  key: const Key('basic_info_reveal_alignment'),
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 35),
                  child: _buildAlignmentPicker(context, state),
                ),
                const SizedBox(height: 16),
                _BasicReveal(
                  key: const Key('basic_info_reveal_appearance'),
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 70),
                  child: _buildPhysicalAppearance(context, state),
                ),
                const SizedBox(height: 16),
                _BasicReveal(
                  key: const Key('basic_info_reveal_personality'),
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 105),
                  child: _buildPersonality(context),
                ),
                const SizedBox(height: 16),
                _BasicReveal(
                  key: const Key('basic_info_reveal_backstory'),
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 140),
                  child: _buildBackstory(context, state),
                ),
                const SizedBox(height: 18),
                _BasicReveal(
                  key: const Key('basic_info_reveal_ready'),
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 175),
                  child: _buildReadyMessage(context, state),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityBlock(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _ExpressiveSurface(
      accent: theme.colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 620;
          final portrait = _buildPortraitPicker(context, state, isWide);
          final nameField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SectionHeading(
                icon: Icons.badge_rounded,
                title: l10n.identity,
                subtitle: l10n.identitySubtitle,
                accent: theme.colorScheme.primary,
              ),
              const SizedBox(height: 18),
              _buildNameField(context),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                portrait,
                const SizedBox(width: 22),
                Expanded(child: nameField),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeading(
                icon: Icons.badge_rounded,
                title: l10n.identity,
                subtitle: l10n.identitySubtitle,
                accent: theme.colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Center(child: portrait),
              const SizedBox(height: 18),
              _buildNameField(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPortraitPicker(
    BuildContext context,
    CharacterCreationState state,
    bool isWide,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = isWide ? 184.0 : 218.0;
    final height = isWide ? 224.0 : 218.0;
    final radius = BorderRadius.circular(28);

    return Semantics(
      button: true,
      image: state.avatarPath != null,
      label: '${l10n.choose} ${l10n.identity}',
      child: Tooltip(
        message: l10n.choose,
        child: AnimatedScale(
          duration: _basicMotionDuration(context, _kBasicFastMotion),
          curve: Curves.easeOutCubic,
          scale: _avatarPressed ? 0.985 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: radius,
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return colorScheme.primary.withValues(alpha: 0.08);
                    }
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)) {
                      return colorScheme.primary.withValues(alpha: 0.05);
                    }
                    return Colors.transparent;
                  }),
                  onHighlightChanged: (pressed) {
                    if (_avatarPressed != pressed) {
                      setState(() => _avatarPressed = pressed);
                    }
                  },
                  onTap: () {
                    _playSelectionHaptic();
                    _pickAvatar(context);
                  },
                  child: Ink(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.86),
                          colorScheme.tertiary.withValues(alpha: 0.76),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                ),
                                child: state.avatarPath != null
                                    ? Image.file(
                                        File(state.avatarPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _AvatarPlaceholder(
                                            colorScheme: colorScheme,
                                          );
                                        },
                                      )
                                    : _AvatarPlaceholder(
                                        colorScheme: colorScheme,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.shadow
                                          .withValues(alpha: 0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    state.avatarPath == null
                                        ? Icons.add_a_photo_rounded
                                        : Icons.edit_rounded,
                                    color: colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      key: const Key('basic_info_name_field'),
      controller: _nameController,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: l10n.charName,
        hintText: l10n.charNameHint,
        prefixIcon: const Icon(Icons.person_outline_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        constraints: const BoxConstraints(minHeight: 64),
      ),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onChanged: (value) {
        context.read<CharacterCreationState>().updateName(value);
      },
    );
  }

  Widget _buildAlignmentPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedName = state.alignment == null
        ? null
        : _getAlignmentName(l10n, state.alignment!);

    return _ExpressiveSurface(
      accent: theme.colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.explore_rounded,
            title: l10n.alignment,
            subtitle: l10n.alignmentSubtitle,
            accent: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 18),
          _buildAlignmentGrid(context, state),
          AnimatedSwitcher(
            duration: _basicMotionDuration(context, _kBasicFastMotion),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: selectedName == null
                ? const SizedBox.shrink(key: ValueKey('alignment-empty'))
                : Padding(
                    key: ValueKey<String>(state.alignment!),
                    padding: const EdgeInsets.only(top: 14),
                    child: _SelectedSummaryChip(
                      icon: Icons.check_circle_rounded,
                      label: selectedName,
                      accent: theme.colorScheme.secondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentGrid(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final columnLabels = [l10n.law, l10n.neutral, l10n.chaos];
    final rowLabels = [l10n.good, l10n.neutral, l10n.evil];

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final axisWidth = compact ? 42.0 : 52.0;
            final labelGap = compact ? 10.0 : 14.0;
            final gap = compact ? 6.0 : 8.0;
            final tileHeight = compact ? 66.0 : 76.0;

            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: axisWidth + labelGap),
                    for (int index = 0;
                        index < columnLabels.length;
                        index++) ...[
                      Expanded(
                        child: _AxisLabel(columnLabels[index]),
                      ),
                      if (index < columnLabels.length - 1) SizedBox(width: gap),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 6 : 8),
                for (int row = 0; row < 3; row++) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: axisWidth,
                        height: tileHeight,
                        child: Center(child: _AxisLabel(rowLabels[row])),
                      ),
                      SizedBox(width: labelGap),
                      for (int col = 0; col < 3; col++) ...[
                        Expanded(
                          child: SizedBox(
                            height: tileHeight,
                            child: _buildAlignmentTile(
                              context,
                              _alignmentOptions[row * 3 + col],
                              state,
                            ),
                          ),
                        ),
                        if (col < 2) SizedBox(width: gap),
                      ],
                    ],
                  ),
                  if (row < 2) SizedBox(height: gap),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlignmentTile(
    BuildContext context,
    _AlignmentOption option,
    CharacterCreationState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selected = state.alignment == option.keyName;
    final localizedName = _getAlignmentName(l10n, option.keyName);
    final visibleCode = _getAlignmentCode(l10n, option.keyName);
    final duration = _basicMotionDuration(context, _kBasicFastMotion);

    return Tooltip(
      message: localizedName,
      child: Semantics(
        button: true,
        selected: selected,
        label: localizedName,
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutCubic,
          scale: selected ? 1.02 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('alignment_${option.code}'),
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                _playSelectionHaptic();
                context
                    .read<CharacterCreationState>()
                    .updateAlignment(selected ? null : option.keyName);
              },
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? colorScheme.secondary
                        : colorScheme.outlineVariant.withValues(alpha: 0.65),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            option.icon,
                            size: 20,
                            color: selected
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              visibleCode,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: selected
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: AnimatedOpacity(
                        duration: duration,
                        opacity: selected ? 1 : 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhysicalAppearance(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _ExpressiveExpansionSection(
      initiallyExpanded: true,
      icon: Icons.face_rounded,
      title: l10n.physicalAppearance,
      subtitle: l10n.physicalSubtitle,
      accent: theme.colorScheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildResponsiveFieldGrid(
            context,
            children: [
              _buildAgeInput(context),
              _buildGenderPicker(context, state),
              _buildHeightPicker(context, state),
              _buildWeightPicker(context, state),
              _buildEyesPicker(context, state),
              _buildHairPicker(context, state),
              _buildSkinPicker(context, state),
            ],
          ),
          const SizedBox(height: 12),
          _buildAutogrowTextField(
            context,
            controller: _appearanceController,
            label: l10n.appearanceDesc,
            hint: l10n.appearanceHint,
            icon: Icons.auto_fix_high_rounded,
            onChanged: (value) => context
                .read<CharacterCreationState>()
                .updateAppearanceDescription(value),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveFieldGrid(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 430
                ? 2
                : 1;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }

  Widget _buildAgeInput(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _InputTileFrame(
      icon: Icons.cake_outlined,
      title: l10n.age,
      child: TextField(
        key: const Key('basic_info_age_field'),
        controller: _ageController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          suffixText: l10n.ageYears,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          constraints: const BoxConstraints(minHeight: 36),
        ),
        onChanged: (value) =>
            context.read<CharacterCreationState>().updateAge(value),
      ),
    );
  }

  Widget _buildGenderPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final genderOptions = {
      'Male': l10n.genderMaleShort,
      'Female': l10n.genderFemaleShort,
      'Other': l10n.genderOtherShort,
    };
    final gender = state.gender ?? '';
    final currentSelection =
        gender.isNotEmpty && genderOptions.containsKey(gender)
            ? {gender}
            : <String>{};

    return _InputTileFrame(
      icon: Icons.wc_rounded,
      title: l10n.gender,
      child: Row(
        children: genderOptions.entries.map((entry) {
          final selected = currentSelection.contains(entry.key);

          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: entry.key == genderOptions.keys.last ? 0 : 6,
              ),
              child: _GenderSegment(
                label: entry.value,
                selected: selected,
                onTap: () {
                  if (selected) return;

                  _playSelectionHaptic();
                  context
                      .read<CharacterCreationState>()
                      .updateGender(entry.key);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAutogrowTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
      minLines: 1,
      maxLines: null,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
    );
  }

  Widget _buildHeightPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return _ChoiceInputTile(
      icon: Icons.height_rounded,
      title: l10n.height,
      value: _displayValue(state.height),
      onTap: () => _showHeightPicker(context, state),
    );
  }

  Widget _buildWeightPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return _ChoiceInputTile(
      icon: Icons.monitor_weight_outlined,
      title: l10n.weight,
      value: _displayValue(state.weight),
      onTap: () => _showWeightPicker(context, state),
    );
  }

  Widget _buildEyesPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return _ChoiceInputTile(
      icon: Icons.visibility_outlined,
      title: l10n.eyes,
      value: _displayColorValue(l10n, state.eyes),
      swatch: _swatchForValue(_eyeColorValues, state.eyes),
      onTap: () => _showColorPicker(
        context,
        title: l10n.selectEyeColor,
        options: const [
          'Amber',
          'Blue',
          'Brown',
          'Gray',
          'Green',
          'Hazel',
          'Red',
          'Violet',
          'Custom',
        ],
        swatches: _eyeColorValues,
        currentValue: state.eyes,
        customTitle: l10n.customEyeColor,
        onSelected: (value) =>
            context.read<CharacterCreationState>().updateEyes(value),
      ),
    );
  }

  Widget _buildHairPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return _ChoiceInputTile(
      icon: Icons.brush_outlined,
      title: l10n.hair,
      value: _displayColorValue(l10n, state.hair),
      swatch: _swatchForValue(_hairColorValues, state.hair),
      swatchIsEmpty: state.hair == 'Bald',
      onTap: () => _showColorPicker(
        context,
        title: l10n.selectHairColor,
        options: const [
          'Auburn',
          'Black',
          'Blonde',
          'Brown',
          'Gray',
          'Red',
          'White',
          'Bald',
          'Custom',
        ],
        swatches: _hairColorValues,
        currentValue: state.hair,
        customTitle: l10n.customHairColor,
        onSelected: (value) =>
            context.read<CharacterCreationState>().updateHair(value),
      ),
    );
  }

  Widget _buildSkinPicker(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return _ChoiceInputTile(
      icon: Icons.palette_outlined,
      title: l10n.skin,
      value: _displayColorValue(l10n, state.skin),
      swatch: _swatchForValue(_skinToneValues, state.skin),
      onTap: () => _showColorPicker(
        context,
        title: l10n.selectSkinTone,
        options: const [
          'Pale',
          'Fair',
          'Light',
          'Medium',
          'Tan',
          'Brown',
          'Dark',
          'Ebony',
          'Custom',
        ],
        swatches: _skinToneValues,
        currentValue: state.skin,
        customTitle: l10n.customSkinTone,
        onSelected: (value) =>
            context.read<CharacterCreationState>().updateSkin(value),
      ),
    );
  }

  String _displayValue(String? value) {
    return (value?.isNotEmpty ?? false) ? value! : '—';
  }

  String _displayColorValue(AppLocalizations l10n, String? value) {
    return (value?.isNotEmpty ?? false)
        ? _getLocalizedColor(l10n, value!)
        : '—';
  }

  Color? _swatchForValue(Map<String, Color> swatches, String? value) {
    if (value == null || value.isEmpty) return null;
    return swatches[value] ?? Colors.grey;
  }

  Future<void> _showHeightPicker(
    BuildContext context,
    CharacterCreationState state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentHeight =
        int.tryParse((state.height ?? '').replaceAll(RegExp(r'[^\d]'), '')) ??
            170;

    _playSelectionHaptic();
    int selectedHeight = currentHeight.clamp(50, 250);
    final scrollController =
        FixedExtentScrollController(initialItem: selectedHeight - 50);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.selectHeight),
              content: SizedBox(
                height: 250,
                width: 220,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: scrollController,
                        itemExtent: 50,
                        perspective: 0.005,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setDialogState(() => selectedHeight = index + 50);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 201,
                          builder: (builderContext, index) {
                            final value = index + 50;
                            final selected = value == selectedHeight;

                            return Center(
                              child: Text(
                                '$value',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.unitCm,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    _playSelectionHaptic();
                    context
                        .read<CharacterCreationState>()
                        .updateHeight('$selectedHeight ${l10n.unitCm}');
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );

    scrollController.dispose();
  }

  Future<void> _showWeightPicker(
    BuildContext context,
    CharacterCreationState state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentWeight =
        int.tryParse((state.weight ?? '').replaceAll(RegExp(r'[^\d]'), '')) ??
            70;

    _playSelectionHaptic();
    int selectedWeight = currentWeight.clamp(10, 300);
    final scrollController =
        FixedExtentScrollController(initialItem: selectedWeight - 10);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.selectWeight),
              content: SizedBox(
                height: 250,
                width: 220,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: scrollController,
                        itemExtent: 50,
                        perspective: 0.005,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setDialogState(() => selectedWeight = index + 10);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 291,
                          builder: (builderContext, index) {
                            final value = index + 10;
                            final selected = value == selectedWeight;

                            return Center(
                              child: Text(
                                '$value',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.unitKg,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    _playSelectionHaptic();
                    context
                        .read<CharacterCreationState>()
                        .updateWeight('$selectedWeight ${l10n.unitKg}');
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );

    scrollController.dispose();
  }

  Future<void> _showColorPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Map<String, Color> swatches,
    required String? currentValue,
    required String customTitle,
    required ValueChanged<String> onSelected,
  }) async {
    final parentContext = context;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _playSelectionHaptic();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(title),
          children: options.map((option) {
            final label = _getLocalizedColor(l10n, option);

            return SimpleDialogOption(
              onPressed: () async {
                _playSelectionHaptic();
                if (option == 'Custom') {
                  Navigator.pop(dialogContext);
                  final customValue = await _showCustomInputDialog(
                    parentContext,
                    customTitle,
                    l10n.enterCustom,
                    l10n,
                  );
                  if (customValue != null && parentContext.mounted) {
                    onSelected(customValue);
                  }
                } else {
                  Navigator.pop(dialogContext, option);
                }
              },
              child: Row(
                children: [
                  _ValueSwatch(
                    color: swatches[option] ?? Colors.grey,
                    isEmpty: option == 'Bald',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (currentValue == option)
                    Icon(
                      Icons.check_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    if (selected != null && context.mounted) {
      onSelected(selected);
    }
  }

  Future<String?> _showCustomInputDialog(
    BuildContext context,
    String title,
    String hint,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    _playSelectionHaptic();
                    Navigator.pop(dialogContext, controller.text);
                  }
                },
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildPersonality(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return _ExpressiveExpansionSection(
      icon: Icons.psychology_alt_rounded,
      title: l10n.personality,
      subtitle: l10n.personalitySubtitle,
      accent: theme.colorScheme.secondary,
      child: Column(
        children: [
          _buildAutogrowTextField(
            context,
            controller: _traitsController,
            label: l10n.traits,
            hint: l10n.traitsHint,
            icon: Icons.auto_awesome_rounded,
            onChanged: (value) => context
                .read<CharacterCreationState>()
                .updatePersonalityTraits(value),
          ),
          const SizedBox(height: 12),
          _buildAutogrowTextField(
            context,
            controller: _idealsController,
            label: l10n.ideals,
            hint: l10n.idealsHint,
            icon: Icons.flag_rounded,
            onChanged: (value) =>
                context.read<CharacterCreationState>().updateIdeals(value),
          ),
          const SizedBox(height: 12),
          _buildAutogrowTextField(
            context,
            controller: _bondsController,
            label: l10n.bonds,
            hint: l10n.bondsHint,
            icon: Icons.link_rounded,
            onChanged: (value) =>
                context.read<CharacterCreationState>().updateBonds(value),
          ),
          const SizedBox(height: 12),
          _buildAutogrowTextField(
            context,
            controller: _flawsController,
            label: l10n.flaws,
            hint: l10n.flawsHint,
            icon: Icons.construction_rounded,
            onChanged: (value) =>
                context.read<CharacterCreationState>().updateFlaws(value),
          ),
        ],
      ),
    );
  }

  Widget _buildBackstory(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final backstory = state.backstory?.trim() ?? '';

    return _BackstoryCard(
      title: l10n.backstory,
      subtitle: l10n.backstorySubtitle,
      preview: backstory.isEmpty ? l10n.backstoryHint : backstory,
      count: backstory.characters.length,
      accent: theme.colorScheme.primary,
      onTap: () => _showBackstoryEditor(context),
    );
  }

  Future<void> _showBackstoryEditor(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _playSelectionHaptic();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AnimatedPadding(
          duration: _basicMotionDuration(sheetContext, _kBasicFastMotion),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.94,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: Material(
                color: colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: MaterialLocalizations.of(sheetContext)
                                  .closeButtonLabel,
                              onPressed: () {
                                _playSelectionHaptic();
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.backstory,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    l10n.backstorySubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: () {
                                _playSelectionHaptic();
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: Text(l10n.confirm),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: TextField(
                            key: const Key('basic_info_backstory_editor'),
                            controller: _backstoryController,
                            autofocus: true,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textAlignVertical: TextAlignVertical.top,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: l10n.backstoryHint,
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              contentPadding: const EdgeInsets.all(18),
                            ),
                            onChanged: (value) => context
                                .read<CharacterCreationState>()
                                .updateBackstory(value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadyMessage(
    BuildContext context,
    CharacterCreationState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final name = state.name.trim();

    return AnimatedSwitcher(
      duration: _basicMotionDuration(context, _kBasicRevealMotion),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: name.isEmpty
          ? const SizedBox.shrink(key: ValueKey('ready-empty'))
          : _SelectedSummaryChip(
              key: ValueKey<String>('ready-$name'),
              icon: Icons.verified_rounded,
              label: l10n.readyMessage(name),
              accent: theme.colorScheme.primary,
              fullWidth: true,
            ),
    );
  }
}

class _BasicReveal extends StatefulWidget {
  const _BasicReveal({
    super.key,
    required this.scrollController,
    required this.delay,
    required this.child,
  });

  final ScrollController scrollController;
  final Duration delay;
  final Widget child;

  @override
  State<_BasicReveal> createState() => _BasicRevealState();
}

class _BasicRevealState extends State<_BasicReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _delayTimer;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kBasicRevealMotion,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    widget.scrollController.addListener(_checkVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void didUpdateWidget(covariant _BasicReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_checkVisibility);
      widget.scrollController.addListener(_checkVisibility);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _revealed = true;
      _controller.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    widget.scrollController.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  void _checkVisibility() {
    if (!mounted || _revealed) return;

    if (MediaQuery.of(context).disableAnimations) {
      _revealImmediately();
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final viewportTop = -renderObject.size.height * 0.08;
    final viewportBottom = viewportHeight - 72;
    final isInViewport = bottom > viewportTop && topLeft.dy < viewportBottom;

    if (isInViewport) {
      _revealed = true;
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        _delayTimer?.cancel();
        _delayTimer = Timer(widget.delay, () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    }
  }

  void _revealImmediately() {
    _delayTimer?.cancel();
    _revealed = true;
    _controller.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        ).animate(_animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.988, end: 1).animate(_animation),
          child: widget.child,
        ),
      ),
    );
  }
}

class _AlignmentOption {
  const _AlignmentOption({
    required this.keyName,
    required this.code,
    required this.icon,
  });

  final String keyName;
  final String code;
  final IconData icon;
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 72,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _ExpressiveSurface extends StatelessWidget {
  const _ExpressiveSurface({
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Color accent;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.07),
            colorScheme.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accent.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: accent, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenderSegment extends StatelessWidget {
  const _GenderSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = _basicMotionDuration(context, _kBasicFastMotion);

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return colorScheme.primary.withValues(alpha: 0.08);
              }
              return Colors.transparent;
            }),
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackstoryCard extends StatelessWidget {
  const _BackstoryCard({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String preview;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filled = count > 0;

    return Semantics(
      button: true,
      child: _ExpressiveSurface(
        accent: accent,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('basic_info_backstory_card'),
              onTap: onTap,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return accent.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return accent.withValues(alpha: 0.05);
                }
                return Colors.transparent;
              }),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: accent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CounterChip(
                                count: count,
                                accent: accent,
                                filled: filled,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: filled
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontStyle:
                                  filled ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.open_in_full_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.count,
    required this.accent,
    required this.filled,
  });

  final int count;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled
            ? accent.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled
              ? accent.withValues(alpha: 0.24)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$count',
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: filled ? accent : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SelectedSummaryChip extends StatelessWidget {
  const _SelectedSummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: chip) : chip;
  }
}

class _ExpressiveExpansionSection extends StatefulWidget {
  const _ExpressiveExpansionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_ExpressiveExpansionSection> createState() =>
      _ExpressiveExpansionSectionState();
}

class _ExpressiveExpansionSectionState
    extends State<_ExpressiveExpansionSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = _basicMotionDuration(context, _kBasicRevealMotion);
    final body = _expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: widget.child,
          )
        : const SizedBox(width: double.infinity);

    return _ExpressiveSurface(
      accent: widget.accent,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return widget.accent.withValues(alpha: 0.07);
                  }
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)) {
                    return widget.accent.withValues(alpha: 0.05);
                  }
                  return Colors.transparent;
                }),
                onTap: () {
                  _playSelectionHaptic();
                  setState(() => _expanded = !_expanded);
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SectionHeading(
                          icon: widget.icon,
                          title: widget.title,
                          subtitle: widget.subtitle,
                          accent: widget.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (duration == Duration.zero)
                body
              else
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: body,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputTileFrame extends StatelessWidget {
  const _InputTileFrame({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceInputTile extends StatelessWidget {
  const _ChoiceInputTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.swatch,
    this.swatchIsEmpty = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? swatch;
  final bool swatchIsEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (swatch != null) ...[
                            _ValueSwatch(
                              color: swatch!,
                              isEmpty: swatchIsEmpty,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: value == '—'
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                                fontWeight: value == '—'
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueSwatch extends StatelessWidget {
  const _ValueSwatch({
    required this.color,
    this.isEmpty = false,
    this.size = 22,
  });

  final Color color;
  final bool isEmpty;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outline,
          width: color.computeLuminance() > 0.72 || isEmpty ? 1.4 : 1,
        ),
      ),
      child: isEmpty
          ? Icon(Icons.block_rounded,
              size: size * 0.72, color: colorScheme.error)
          : null,
    );
  }
}
