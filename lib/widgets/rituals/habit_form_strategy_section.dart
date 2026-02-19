import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_action_step.dart';
import '../../models/habit_item.dart';
import '../../services/icon_service.dart';
import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// --- STEP 6: ACTION STEPS ---
class Step6Strategy extends StatefulWidget {
  final Color habitColor;
  final bool habitStackingEnabled;
  final ValueChanged<bool> onHabitStackingToggle;
  final List<HabitItem> existingHabits;
  final String? afterHabitId;
  final String anchorHabitText;
  final String relationship;
  final bool isEditing;
  final ValueChanged<String?> onAfterHabitIdChanged;
  final ValueChanged<String> onAnchorTextChanged;
  final ValueChanged<String> onRelationshipChanged;
  final String? anchorHabitError;

  final bool actionStepsEnabled;
  final ValueChanged<bool> onActionStepsToggle;
  final String? actionStepsError;
  final List<HabitActionStep> actionSteps;
  final ValueChanged<List<HabitActionStep>> onActionStepsChanged;

  const Step6Strategy({
    super.key,
    required this.habitColor,
    required this.habitStackingEnabled,
    required this.onHabitStackingToggle,
    required this.existingHabits,
    required this.afterHabitId,
    required this.anchorHabitText,
    required this.relationship,
    required this.onAfterHabitIdChanged,
    required this.onAnchorTextChanged,
    required this.onRelationshipChanged,
    this.isEditing = false,
    this.anchorHabitError,
    required this.actionStepsEnabled,
    required this.onActionStepsToggle,
    this.actionStepsError,
    required this.actionSteps,
    required this.onActionStepsChanged,
  });

  @override
  State<Step6Strategy> createState() => _Step6StrategyState();
}

class _Step6StrategyState extends State<Step6Strategy> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.anchorHabitText.isNotEmpty) {
      _searchController.text = widget.anchorHabitText;
    }
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void didUpdateWidget(covariant Step6Strategy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchorHabitText != oldWidget.anchorHabitText &&
        widget.anchorHabitText != _searchController.text) {
      _searchController.text = widget.anchorHabitText;
    }
    // Auto-focus the search field when habit stacking is toggled on
    if (widget.habitStackingEnabled && !oldWidget.habitStackingEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Builds the merged + filtered suggestion list from user habits and defaults.
  List<HabitSuggestion> _buildSuggestions() {
    final query = _searchController.text.trim().toLowerCase();
    final existingNames =
        widget.existingHabits.map((h) => h.name.toLowerCase()).toSet();

    final List<HabitSuggestion> results = [];

    // User's own habits
    for (final h in widget.existingHabits) {
      if (query.isEmpty || h.name.toLowerCase().contains(query)) {
        results.add(HabitSuggestion(
          label: h.name,
          habitId: h.id,
          isDefault: false,
        ));
      }
    }

    // Default habits (exclude duplicates already in user habits)
    for (final name in kDefaultStackingHabits) {
      if (!existingNames.contains(name.toLowerCase())) {
        if (query.isEmpty || name.toLowerCase().contains(query)) {
          results.add(HabitSuggestion(
            label: name,
            habitId: null,
            isDefault: true,
          ));
        }
      }
    }

    return results;
  }

  void _selectSuggestion(HabitSuggestion suggestion) {
    _searchController.text = suggestion.label;
    widget.onAnchorTextChanged(suggestion.label);
    widget.onAfterHabitIdChanged(suggestion.habitId);
    _searchFocusNode.unfocus();
    setState(() => _showSuggestions = false);
  }

  void _clearSelection() {
    _searchController.clear();
    widget.onAnchorTextChanged('');
    widget.onAfterHabitIdChanged(null);
    setState(() {});
  }

  void _addStep() {
    final steps = List<HabitActionStep>.from(widget.actionSteps);
    steps.add(HabitActionStep(
      id: 'step_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      iconCodePoint: Icons.check_circle_outline.codePoint,
      order: steps.length,
    ));
    widget.onActionStepsChanged(steps);
  }

  void _deleteStep(int index) {
    final steps = List<HabitActionStep>.from(widget.actionSteps);
    steps.removeAt(index);
    for (int i = 0; i < steps.length; i++) {
      steps[i] = steps[i].copyWith(order: i);
    }
    widget.onActionStepsChanged(steps);
  }

  void _updateStepTitle(int index, String title) {
    final steps = List<HabitActionStep>.from(widget.actionSteps);
    final newIcon = title.trim().isNotEmpty
        ? IconService.getIconCodePointForTitle(title.trim())
        : steps[index].iconCodePoint;
    steps[index] = steps[index].copyWith(title: title, iconCodePoint: newIcon);
    widget.onActionStepsChanged(steps);
  }

  Widget _buildInlineAddButton(ColorScheme colorScheme) {
    return IconButton(
      icon: Icon(Icons.add_circle_rounded, size: 22, color: colorScheme.primary),
      onPressed: _addStep,
      visualDensity: VisualDensity.compact,
      tooltip: 'Add step',
    );
  }

  Widget _buildAddStepRow(ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _addStep,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Add a step',
                style: AppTypography.body(context).copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    final steps = List<HabitActionStep>.from(widget.actionSteps);
    if (newIndex > oldIndex) newIndex--;
    final item = steps.removeAt(oldIndex);
    steps.insert(newIndex, item);
    for (int i = 0; i < steps.length; i++) {
      steps[i] = steps[i].copyWith(order: i);
    }
    widget.onActionStepsChanged(steps);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Action Steps",
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        CupertinoListTile.notched(
          leading: Icon(
            Icons.checklist_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
          title: Text(
            "Break into small steps",
            style: AppTypography.body(context).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: CupertinoSwitch(
            value: widget.actionStepsEnabled,
            onChanged: widget.onActionStepsToggle,
            activeTrackColor: widget.habitColor,
          ),
          onTap: null,
        ),
        if (widget.actionStepsEnabled) ...[
          if (widget.actionSteps.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: widget.actionSteps.length,
              onReorder: _reorderSteps,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final step = widget.actionSteps[index];
                return _ActionStepTile(
                  key: ValueKey(step.id),
                  step: step,
                  stepNumber: index + 1,
                  colorScheme: colorScheme,
                  onTitleChanged: (title) => _updateStepTitle(index, title),
                  onDelete: () => _deleteStep(index),
                  reorderIndex: index,
                  trailing: index == widget.actionSteps.length - 1
                      ? _buildInlineAddButton(colorScheme)
                      : null,
                );
              },
            )
          else
            _buildAddStepRow(colorScheme),
          if (widget.actionStepsError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                widget.actionStepsError!,
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                Icons.link,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              title: Text(
                "Anchor to an existing habit",
                style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: CupertinoSwitch(
                value: widget.habitStackingEnabled,
                onChanged: widget.onHabitStackingToggle,
                activeTrackColor: widget.habitColor,
              ),
              onTap: null,
            ),
            if (widget.habitStackingEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Builder(builder: (context) {
                      const options = ['Before', 'After'];
                      final safeValue = options.contains(widget.relationship)
                          ? widget.relationship
                          : 'Before';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          dropdownColor: colorScheme.surfaceContainerHighest,
                          value: safeValue,
                          isExpanded: true,
                          style: AppTypography.body(context),
                          underline: const SizedBox(),
                          icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurfaceVariant),
                          items: ['Before', 'After']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => widget.onRelationshipChanged(v!),
                        ),
                      );
                    }),
                    SizedBox(height: kControlSpacing),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: AppTypography.body(context),
                      onChanged: (v) {
                        widget.onAnchorTextChanged(v);
                        if (widget.afterHabitId != null) {
                          widget.onAfterHabitIdChanged(null);
                        }
                        setState(() => _showSuggestions = true);
                      },
                      decoration: InputDecoration(
                        hintText: "Search or type a habit...",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        errorText: widget.anchorHabitError,
                        errorStyle: AppTypography.caption(context).copyWith(color: colorScheme.error),
                        prefixIcon: Icon(
                          Icons.search,
                          color: widget.anchorHabitError != null
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: colorScheme.onSurfaceVariant),
                                onPressed: _clearSelection,
                              )
                            : null,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: widget.anchorHabitError != null
                              ? BorderSide(color: colorScheme.error)
                              : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: widget.anchorHabitError != null
                              ? BorderSide(color: colorScheme.error)
                              : BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.anchorHabitError != null
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    if (_showSuggestions) _buildSuggestionList(colorScheme),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionList(ColorScheme colorScheme) {
    final suggestions = _buildSuggestions();
    final query = _searchController.text.trim();

    // Split into user habits and default habits
    final userHabits =
        suggestions.where((s) => !s.isDefault).toList();
    final defaultHabits =
        suggestions.where((s) => s.isDefault).toList();

    // Check if typed text matches any suggestion exactly
    final exactMatch = suggestions.any(
      (s) => s.label.toLowerCase() == query.toLowerCase(),
    );

    if (suggestions.isEmpty && query.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            // "Use custom" option when typed text doesn't match any suggestion
            if (query.isNotEmpty && !exactMatch)
              SuggestionTile(
                label: 'Use "$query"',
                icon: Icons.add_circle_outline,
                iconColor: widget.habitColor,
                colorScheme: colorScheme,
                onTap: () {
                  widget.onAnchorTextChanged(query);
                  widget.onAfterHabitIdChanged(null);
                  _searchFocusNode.unfocus();
                  setState(() => _showSuggestions = false);
                },
              ),

            // User's own habits section
            if (userHabits.isNotEmpty) ...[
              SectionLabel(
                label: 'Your Habits',
                colorScheme: colorScheme,
              ),
              ...userHabits.map((s) => SuggestionTile(
                    label: s.label,
                    icon: Icons.person_outline,
                    iconColor: colorScheme.primary,
                    colorScheme: colorScheme,
                    isSelected: widget.afterHabitId == s.habitId,
                    onTap: () => _selectSuggestion(s),
                  )),
            ],

            // Default habits section
            if (defaultHabits.isNotEmpty) ...[
              SectionLabel(
                label: 'Common Habits',
                colorScheme: colorScheme,
              ),
              ...defaultHabits.map((s) => SuggestionTile(
                    label: s.label,
                    icon: Icons.auto_awesome_outlined,
                    iconColor: colorScheme.tertiary,
                    colorScheme: colorScheme,
                    isSelected:
                        s.label == widget.anchorHabitText &&
                            widget.afterHabitId == null,
                    onTap: () => _selectSuggestion(s),
                  )),
            ],

            // Empty state
            if (suggestions.isEmpty && query.isNotEmpty && exactMatch)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No matching habits found',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context).copyWith(
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Internal model for a habit suggestion entry.
class HabitSuggestion {
  final String label;
  final String? habitId;
  final bool isDefault;

  const HabitSuggestion({
    required this.label,
    this.habitId,
    required this.isDefault,
  });
}

/// Section header label inside the suggestion list.
class SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const SectionLabel({super.key, required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Single tappable row in the suggestion list.
class SuggestionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final ColorScheme colorScheme;
  final bool isSelected;
  final VoidCallback onTap;

  const SuggestionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.colorScheme,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body(context).copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 18, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline editable tile for a single action step inside the Action Steps section.
class _ActionStepTile extends StatefulWidget {
  final HabitActionStep step;
  final int stepNumber;
  final ColorScheme colorScheme;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onDelete;
  final int reorderIndex;
  final Widget? trailing;

  const _ActionStepTile({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.colorScheme,
    required this.onTitleChanged,
    required this.onDelete,
    required this.reorderIndex,
    this.trailing,
  });

  @override
  State<_ActionStepTile> createState() => _ActionStepTileState();
}

class _ActionStepTileState extends State<_ActionStepTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.step.title);
  }

  @override
  void didUpdateWidget(_ActionStepTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id) {
      _controller.text = widget.step.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final icon = IconService.iconFromCodePoint(widget.step.iconCodePoint);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.reorderIndex,
            child: Icon(Icons.drag_handle_rounded, size: 22, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, size: 18, color: cs.onPrimaryContainer)),
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 1.5),
                    ),
                    child: Text(
                      '${widget.stepNumber}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onPrimary, height: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLength: 200,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(
                hintText: 'Step title...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                counterText: '',
              ),
              style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w500),
              onChanged: widget.onTitleChanged,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: cs.error.withValues(alpha: 0.7)),
            onPressed: widget.onDelete,
            tooltip: 'Remove',
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}
