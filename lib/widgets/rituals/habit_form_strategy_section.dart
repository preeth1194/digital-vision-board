import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// --- STEP 6: HABIT STACKING ---
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Habit Stacking",
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
                    // Relationship picker (Before / After)
                    Builder(builder: (context) {
                      const options = ['Before', 'After'];
                      final safeValue = options.contains(widget.relationship)
                          ? widget.relationship
                          : 'Before';
                      return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        dropdownColor:
                            colorScheme.surfaceContainerHighest,
                        value: safeValue,
                        isExpanded: true,
                        style: AppTypography.body(context),
                        underline: const SizedBox(),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        items: ['Before', 'After']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            widget.onRelationshipChanged(v!),
                      ),
                    );
                    }),
                    SizedBox(height: kControlSpacing),

                    // Searchable habit picker
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: AppTypography.body(context),
                      onChanged: (v) {
                        widget.onAnchorTextChanged(v);
                        // Clear the linked habit ID when user starts typing
                        if (widget.afterHabitId != null) {
                          widget.onAfterHabitIdChanged(null);
                        }
                        setState(() => _showSuggestions = true);
                      },
                      decoration: InputDecoration(
                        hintText: "Search or type a habit...",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        errorText: widget.anchorHabitError,
                        errorStyle: AppTypography.caption(context).copyWith(
                          color: colorScheme.error,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: widget.anchorHabitError != null
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),

                    // Suggestion list
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
