import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';
import '../models/routine_todo_item.dart';
import '../services/routine_storage_service.dart';
import '../services/icon_service.dart';
import '../utils/app_typography.dart';

class RoutineEditorScreen extends StatefulWidget {
  final Routine? routine; // null for new routine

  const RoutineEditorScreen({
    super.key,
    this.routine,
  });

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final TextEditingController _titleController;
  late final SharedPreferences _prefs;
  bool _loading = true;

  String _title = '';
  int _iconCodePoint = Icons.list.codePoint;
  int _tileColorValue = const Color(0xFFE8F5E9).value;
  List<RoutineTodoItem> _todos = [];

  // Occurrence fields
  String _occurrenceType = 'daily'; // 'daily' | 'weekdays' | 'interval'
  List<int> _weekdays = []; // 0=Mon, 1=Tue, ..., 6=Sun
  int _intervalDays = 1;
  DateTime _startDate = DateTime.now();

  // Timer mode fields
  String _timeMode = 'overall'; // 'overall' | 'per_todo'
  int _overallDurationMinutes = 30;

  // Track which todo is expanded for inline editing
  String? _expandedTodoId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    if (widget.routine != null) {
      _title = widget.routine!.title;
      _iconCodePoint = widget.routine!.iconCodePoint;
      _tileColorValue = widget.routine!.tileColorValue;
      _todos = List.from(widget.routine!.todos);
      _titleController.text = _title;
      // Load occurrence fields
      _occurrenceType = widget.routine!.occurrenceType;
      _weekdays = List.from(widget.routine!.weekdays ?? []);
      _intervalDays = widget.routine!.intervalDays ?? 1;
      _startDate = widget.routine!.startDate ?? DateTime.now();
      // Load timer mode fields
      _timeMode = widget.routine!.timeMode;
      _overallDurationMinutes = widget.routine!.overallDurationMinutes ?? 30;
    } else {
      _startDate = DateTime.now();
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine title')),
      );
      return;
    }

    if (_todos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one todo item')),
      );
      return;
    }

    final routine = Routine(
      id: widget.routine?.id ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAtMs: widget.routine?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      iconCodePoint: _iconCodePoint,
      tileColorValue: _tileColorValue,
      todos: _todos,
      occurrenceType: _occurrenceType,
      weekdays: _weekdays.isNotEmpty ? _weekdays : null,
      intervalDays: _intervalDays,
      startDate: _startDate,
      timeMode: _timeMode,
      overallDurationMinutes: _timeMode == 'overall' ? _overallDurationMinutes : null,
    );

    final routines = await RoutineStorageService.loadRoutines(prefs: _prefs);
    final updated = widget.routine == null
        ? [routine, ...routines]
        : routines.map((r) => r.id == routine.id ? routine : r).toList();

    await RoutineStorageService.saveRoutines(updated, prefs: _prefs);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _addTodo() {
    final newTodo = RoutineTodoItem(
      id: 'todo_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      iconCodePoint: Icons.check_circle_outline.codePoint,
      order: _todos.length,
    );
    setState(() {
      _todos.add(newTodo);
      _expandedTodoId = newTodo.id; // Auto-expand the new todo for editing
    });
  }

  void _deleteTodo(RoutineTodoItem todo) {
    setState(() {
      _todos.removeWhere((t) => t.id == todo.id);
      // Reorder remaining todos
      for (int i = 0; i < _todos.length; i++) {
        _todos[i] = _todos[i].copyWith(order: i);
      }
    });
  }

  void _reorderTodos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _todos.removeAt(oldIndex);
      _todos.insert(newIndex, item);
      // Update order values
      for (int i = 0; i < _todos.length; i++) {
        _todos[i] = _todos[i].copyWith(order: i);
      }
    });
  }

  void _moveTodo(int fromIndex, int toIndex) {
    setState(() {
      final item = _todos.removeAt(fromIndex);
      _todos.insert(toIndex, item);
      // Update order values
      for (int i = 0; i < _todos.length; i++) {
        _todos[i] = _todos[i].copyWith(order: i);
      }
    });
  }

  Widget _buildOccurrencePicker(ColorScheme colorScheme) {
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Occurrence options with icons and descriptions
    final occurrenceOptions = [
      (
        value: 'daily',
        label: 'Daily',
        icon: Icons.sunny,
        description: 'Repeat every day',
      ),
      (
        value: 'weekdays',
        label: 'Specific Days',
        icon: Icons.calendar_view_week_rounded,
        description: 'Choose which days',
      ),
      (
        value: 'interval',
        label: 'Custom Interval',
        icon: Icons.repeat_rounded,
        description: 'Every X days',
      ),
    ];

    final selectedOption = occurrenceOptions.firstWhere(
      (o) => o.value == _occurrenceType,
      orElse: () => occurrenceOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modern dropdown selector
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showOccurrenceBottomSheet(colorScheme, occurrenceOptions),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon container with animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        selectedOption.icon,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedOption.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedOption.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dropdown arrow
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Animated options based on selection
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Column(
            children: [
              // Weekday picker (if weekdays mode)
              if (_occurrenceType == 'weekdays') ...[
                const SizedBox(height: 16),
                _buildWeekdayPicker(colorScheme, weekdayNames),
              ],

              // Interval picker (if interval mode)
              if (_occurrenceType == 'interval') ...[
                const SizedBox(height: 16),
                _buildIntervalPicker(colorScheme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showOccurrenceBottomSheet(
    ColorScheme colorScheme,
    List<({String value, String label, IconData icon, String description})> options,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Repeat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Options
              ...options.map((option) {
                final isSelected = _occurrenceType == option.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _occurrenceType = option.value);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                option.icon,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Check icon
                            if (isSelected)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayPicker(ColorScheme colorScheme, List<String> weekdayNames) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select days',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isSelected = _weekdays.contains(index);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _weekdays.remove(index);
                    } else {
                      _weekdays.add(index);
                      _weekdays.sort();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      weekdayNames[index][0], // Just first letter
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Show selected days summary
          if (_weekdays.isNotEmpty)
            Text(
              _weekdays.map((i) => weekdayNames[i]).join(', '),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntervalPicker(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Interval row
          Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Every',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              // Interval stepper
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minus button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                        onTap: () {
                          if (_intervalDays > 1) {
                            setState(() => _intervalDays--);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: _intervalDays > 1
                                ? colorScheme.onSurface
                                : colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    // Value
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Container(
                        key: ValueKey(_intervalDays),
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$_intervalDays',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // Plus button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                        onTap: () {
                          setState(() => _intervalDays++);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _intervalDays == 1 ? 'day' : 'days',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Start date selector
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starting from',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(_startDate),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTimerModePicker(ColorScheme colorScheme) {
    final timerModeOptions = [
      (
        value: 'overall',
        label: 'Flexible Flow',
        icon: Icons.timer_outlined,
        description: 'Time the full routine',
      ),
      (
        value: 'per_todo',
        label: 'Guided Steps',
        icon: Icons.format_list_numbered_rounded,
        description: 'Each step has its own timer',
      ),
    ];

    final selectedOption = timerModeOptions.firstWhere(
      (o) => o.value == _timeMode,
      orElse: () => timerModeOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modern dropdown selector
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showTimerModeBottomSheet(colorScheme, timerModeOptions),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon container with animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        selectedOption.icon,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedOption.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedOption.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dropdown arrow
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Overall duration stepper (if overall mode)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _timeMode == 'overall'
              ? Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildOverallDurationStepper(colorScheme),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showTimerModeBottomSheet(
    ColorScheme colorScheme,
    List<({String value, String label, IconData icon, String description})> options,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Timer Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Options
              ...options.map((option) {
                final isSelected = _timeMode == option.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _timeMode = option.value);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                option.icon,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Check icon
                            if (isSelected)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  Widget _buildOverallDurationStepper(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDurationBottomSheet(colorScheme),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: Text(
                          _formatDuration(_overallDurationMinutes),
                          key: ValueKey(_overallDurationMinutes),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Dropdown arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDurationBottomSheet(ColorScheme colorScheme) {
    final durations = [5, 10, 15, 20, 30, 45, 60, 90, 120];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Select Duration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Duration grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: durations.map((minutes) {
                    final isSelected = _overallDurationMinutes == minutes;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() => _overallDurationMinutes = minutes);
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: (MediaQuery.of(ctx).size.width - 52) / 3,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                                child: Text('$minutes'),
                              ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? colorScheme.onPrimary.withValues(alpha: 0.8)
                                      : colorScheme.onSurfaceVariant,
                                ),
                                child: Text(minutes >= 60 ? 'minutes' : 'min'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Custom duration option
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await _showCustomDurationPicker(colorScheme);
                      if (result != null) {
                        setState(() => _overallDurationMinutes = result);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Custom Duration',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _showCustomDurationPicker(ColorScheme colorScheme) async {
    int tempDuration = _overallDurationMinutes;
    
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Custom Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // Duration display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Text(
                          _formatDuration(tempDuration),
                          key: ValueKey(tempDuration),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Stepper
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // -5 button
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                              onTap: () {
                                if (tempDuration > 5) {
                                  setModalState(() => tempDuration -= 5);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.remove_rounded,
                                      color: tempDuration > 5
                                          ? colorScheme.onSurface
                                          : colorScheme.outlineVariant,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '-5',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        // -1 button
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (tempDuration > 1) {
                                  setModalState(() => tempDuration -= 1);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.remove_rounded,
                                      color: tempDuration > 1
                                          ? colorScheme.onSurface
                                          : colorScheme.outlineVariant,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '-1',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        // +1 button
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setModalState(() => tempDuration += 1);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: colorScheme.onSurface,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+1',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        // +5 button
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                              onTap: () {
                                setModalState(() => tempDuration += 5);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: colorScheme.onSurface,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+5',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Confirm button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, tempDuration),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'Create Routine' : 'Edit Routine'),
        actions: [
          TextButton(
            onPressed: _saveRoutine,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title input with section styling
            _buildSectionHeader(context, 'Title', Icons.edit_rounded),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Morning Routine',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 28),

            // Occurrence Section
            _buildSectionHeader(context, 'Schedule', Icons.calendar_today_rounded),
            const SizedBox(height: 12),
            _buildOccurrencePicker(colorScheme),
            const SizedBox(height: 28),

            // Timer Mode Section
            _buildSectionHeader(context, 'Duration', Icons.timer_outlined),
            const SizedBox(height: 12),
            _buildTimerModePicker(colorScheme),
            const SizedBox(height: 28),

            // Todos section
            Row(
              children: [
                _buildSectionHeader(context, 'Steps', Icons.format_list_numbered_rounded),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _addTodo,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: colorScheme.onPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Add',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_todos.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.playlist_add_rounded,
                        size: 32,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No steps yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add steps to build your routine',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: List.generate(_todos.length, (index) {
                  final todo = _todos[index];
                  return _InlineEditableTodoItem(
                    key: ValueKey(todo.id),
                    todo: todo,
                    isExpanded: _expandedTodoId == todo.id,
                    showDurationStepper: _timeMode == 'per_todo',
                    onToggleExpand: () {
                      setState(() {
                        _expandedTodoId = _expandedTodoId == todo.id ? null : todo.id;
                      });
                    },
                    onUpdate: (updatedTodo) {
                      setState(() {
                        final idx = _todos.indexWhere((t) => t.id == updatedTodo.id);
                        if (idx >= 0) {
                          _todos[idx] = updatedTodo;
                        }
                      });
                    },
                    onDelete: () => _deleteTodo(todo),
                    onMoveUp: index > 0 ? () => _moveTodo(index, index - 1) : null,
                    onMoveDown: index < _todos.length - 1 ? () => _moveTodo(index, index + 1) : null,
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineEditableTodoItem extends StatefulWidget {
  final RoutineTodoItem todo;
  final bool isExpanded;
  final bool showDurationStepper;
  final VoidCallback onToggleExpand;
  final ValueChanged<RoutineTodoItem> onUpdate;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _InlineEditableTodoItem({
    super.key,
    required this.todo,
    required this.isExpanded,
    required this.showDurationStepper,
    required this.onToggleExpand,
    required this.onUpdate,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<_InlineEditableTodoItem> createState() => _InlineEditableTodoItemState();
}

class _InlineEditableTodoItemState extends State<_InlineEditableTodoItem> {
  late TextEditingController _titleController;
  late int _iconCodePoint;
  late int _durationMinutes;
  late bool _reminderEnabled;
  late int? _reminderMinutes;
  late String? _timeOfDay;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _iconCodePoint = widget.todo.iconCodePoint;
    _durationMinutes = widget.todo.durationMinutes ?? 5;
    _reminderEnabled = widget.todo.reminderEnabled;
    _reminderMinutes = widget.todo.reminderMinutes;
    _timeOfDay = widget.todo.timeOfDay;
  }

  @override
  void didUpdateWidget(_InlineEditableTodoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.id != widget.todo.id) {
      _titleController.text = widget.todo.title;
      _iconCodePoint = widget.todo.iconCodePoint;
      _durationMinutes = widget.todo.durationMinutes ?? 5;
      _reminderEnabled = widget.todo.reminderEnabled;
      _reminderMinutes = widget.todo.reminderMinutes;
      _timeOfDay = widget.todo.timeOfDay;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateTodo() {
    final title = _titleController.text.trim();
    widget.onUpdate(widget.todo.copyWith(
      title: title,
      iconCodePoint: _iconCodePoint,
      durationMinutes: widget.showDurationStepper ? _durationMinutes : null,
      reminderEnabled: _reminderEnabled,
      reminderMinutes: _reminderMinutes,
      timeOfDay: _timeOfDay,
    ));
  }

  void _onTitleChanged(String value) {
    final title = value.trim();
    if (title.isNotEmpty) {
      final newIcon = IconService.getIconCodePointForTitle(title);
      if (newIcon != _iconCodePoint) {
        setState(() => _iconCodePoint = newIcon);
      }
    }
    _updateTodo();
  }

  Future<void> _pickScheduledTime() async {
    final initial = _reminderMinutes != null
        ? TimeOfDay(hour: _reminderMinutes! ~/ 60, minute: _reminderMinutes! % 60)
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;

    final label = MaterialLocalizations.of(context).formatTimeOfDay(picked);
    final minutes = (picked.hour * 60) + picked.minute;

    setState(() {
      _timeOfDay = label;
      _reminderMinutes = minutes;
    });
    _updateTodo();
  }

  void _clearScheduledTime() {
    setState(() {
      _timeOfDay = null;
      _reminderMinutes = null;
    });
    _updateTodo();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = IconService.iconFromCodePoint(_iconCodePoint);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isExpanded
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isExpanded
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
          width: widget.isExpanded ? 1.5 : 1,
        ),
        boxShadow: widget.isExpanded
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Main row with icon, title, delete, drag handle
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon container
                GestureDetector(
                  onTap: widget.onToggleExpand,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.isExpanded
                          ? colorScheme.primary
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: widget.isExpanded
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Editable title
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Todo title...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    onChanged: _onTitleChanged,
                    onTap: () {
                      if (!widget.isExpanded) {
                        widget.onToggleExpand();
                      }
                    },
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
                // Reorder buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: widget.onMoveUp,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: widget.onMoveUp != null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.outlineVariant.withValues(alpha: 0.3),
                        size: 18,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onMoveDown,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.onMoveDown != null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.outlineVariant.withValues(alpha: 0.3),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expandable controls section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: widget.isExpanded
                ? _buildExpandedControls(colorScheme)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedControls(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),

          // Scheduled Time Picker
          _buildControlRow(
            colorScheme: colorScheme,
            icon: Icons.access_time_rounded,
            label: 'Start Time',
            value: _timeOfDay,
            placeholder: 'Set time',
            onTap: _pickScheduledTime,
            onClear: _timeOfDay != null ? _clearScheduledTime : null,
          ),

          // Duration Stepper (only in per-todo mode)
          if (widget.showDurationStepper) ...[
            const SizedBox(height: 12),
            _buildDurationStepper(colorScheme),
          ],

          // Reminder Toggle
          const SizedBox(height: 12),
          _buildReminderToggle(colorScheme),
        ],
      ),
    );
  }

  Widget _buildControlRow({
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final hasValue = value != null && value.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasValue
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasValue
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasValue
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: hasValue
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                        color: hasValue
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      child: Text(value ?? placeholder),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear',
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationStepper(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timer',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_durationMinutes min',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Stepper controls
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    onTap: () {
                      if (_durationMinutes > 1) {
                        setState(() => _durationMinutes--);
                        _updateTodo();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: _durationMinutes > 1
                            ? colorScheme.onSurface
                            : colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
                // Value
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Container(
                    key: ValueKey(_durationMinutes),
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      '$_durationMinutes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                // Plus button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    onTap: () {
                      setState(() => _durationMinutes++);
                      _updateTodo();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderToggle(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _reminderEnabled
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _reminderEnabled
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _reminderEnabled
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _reminderEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: _reminderEnabled
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notify Me',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _reminderEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _reminderEnabled ? FontWeight.w600 : FontWeight.w400,
                    color: _reminderEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _reminderEnabled,
              onChanged: (value) {
                setState(() {
                  _reminderEnabled = value;
                  if (!value) {
                    // Clear reminder time when disabled
                  }
                });
                _updateTodo();
              },
            ),
          ),
        ],
      ),
    );
  }
}
