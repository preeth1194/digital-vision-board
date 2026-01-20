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
  int _tileColorValue = const Color(0xFFE0F2FE).value;
  String _timeMode = 'overall'; // 'overall' | 'per_todo'
  int? _overallDurationMinutes;
  List<RoutineTodoItem> _todos = [];

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
      _timeMode = widget.routine!.timeMode;
      _overallDurationMinutes = widget.routine!.overallDurationMinutes;
      _todos = List.from(widget.routine!.todos);
      _titleController.text = _title;
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

    if (_timeMode == 'overall' && (_overallDurationMinutes == null || _overallDurationMinutes! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set overall duration')),
      );
      return;
    }

    if (_timeMode == 'per_todo') {
      for (final todo in _todos) {
        if (todo.durationMinutes == null || todo.durationMinutes! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Todo "${todo.title}" needs a duration')),
          );
          return;
        }
      }
    }

    final routine = Routine(
      id: widget.routine?.id ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAtMs: widget.routine?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      iconCodePoint: _iconCodePoint,
      tileColorValue: _tileColorValue,
      todos: _todos,
      timeMode: _timeMode,
      overallDurationMinutes: _overallDurationMinutes,
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
    });
    _editTodo(newTodo);
  }

  Future<void> _editTodo(RoutineTodoItem todo) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _TodoEditDialog(
        todo: todo,
        timeMode: _timeMode,
      ),
    );

    if (result == null) return;

    setState(() {
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index >= 0) {
        _todos[index] = RoutineTodoItem(
          id: todo.id,
          title: result['title'] as String,
          iconCodePoint: result['iconCodePoint'] as int,
          order: todo.order,
          durationMinutes: result['durationMinutes'] as int?,
          timerType: result['timerType'] as String?,
          reminderEnabled: result['reminderEnabled'] as bool,
          reminderMinutes: result['reminderMinutes'] as int?,
          timeOfDay: result['timeOfDay'] as String?,
          completedDates: todo.completedDates,
        );
      }
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Routine Title',
                hintText: 'e.g., Morning Routine',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: AppTypography.body(context),
            ),
            const SizedBox(height: 24),

            // Time Mode Selection
            Text(
              'Time Mode',
              style: AppTypography.heading3(context),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'overall',
                  label: Text('Overall Time'),
                  icon: Icon(Icons.timer_outlined),
                ),
                ButtonSegment(
                  value: 'per_todo',
                  label: Text('Per Todo Time'),
                  icon: Icon(Icons.list_alt),
                ),
              ],
              selected: {_timeMode},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _timeMode = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Overall duration picker (if overall mode)
            if (_timeMode == 'overall') ...[
              Text(
                'Overall Duration',
                style: AppTypography.heading3(context),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        hintText: '30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: 'minutes',
                      ),
                      onChanged: (value) {
                        _overallDurationMinutes = int.tryParse(value);
                      },
                      controller: TextEditingController(
                        text: _overallDurationMinutes?.toString() ?? '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Todos section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Todo Items',
                  style: AppTypography.heading3(context),
                ),
                FilledButton.icon(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Todo'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_todos.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.list_alt_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No todos yet',
                          style: AppTypography.body(context).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first todo item to get started',
                          style: AppTypography.bodySmall(context).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _todos.length,
                onReorder: _reorderTodos,
                itemBuilder: (context, index) {
                  final todo = _todos[index];
                  return _TodoItemCard(
                    key: ValueKey(todo.id),
                    todo: todo,
                    timeMode: _timeMode,
                    onTap: () => _editTodo(todo),
                    onDelete: () => _deleteTodo(todo),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TodoItemCard extends StatelessWidget {
  final RoutineTodoItem todo;
  final String timeMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TodoItemCard({
    super.key,
    required this.todo,
    required this.timeMode,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = IconData(todo.iconCodePoint, fontFamily: 'MaterialIcons');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          todo.title.isEmpty ? 'Untitled Todo' : todo.title,
          style: todo.title.isEmpty
              ? AppTypography.body(context).copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                )
              : AppTypography.body(context),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timeMode == 'per_todo' && todo.durationMinutes != null)
              Text(
                '${todo.durationMinutes} min • ${todo.timerType ?? 'regular'} timer',
                style: AppTypography.caption(context),
              ),
            if (todo.reminderEnabled && todo.timeOfDay != null)
              Text(
                'Reminder: ${todo.timeOfDay}',
                style: AppTypography.caption(context),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TodoEditDialog extends StatefulWidget {
  final RoutineTodoItem todo;
  final String timeMode;

  const _TodoEditDialog({
    required this.todo,
    required this.timeMode,
  });

  @override
  State<_TodoEditDialog> createState() => _TodoEditDialogState();
}

class _TodoEditDialogState extends State<_TodoEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late final TextEditingController _timeOfDayController;

  String _title = '';
  int _iconCodePoint = Icons.check_circle_outline.codePoint;
  int? _durationMinutes;
  String? _timerType; // 'rhythmic' | 'regular'
  bool _reminderEnabled = false;
  int? _reminderMinutes;
  String? _timeOfDay;

  @override
  void initState() {
    super.initState();
    _title = widget.todo.title;
    _iconCodePoint = widget.todo.iconCodePoint;
    _durationMinutes = widget.todo.durationMinutes;
    _timerType = widget.todo.timerType;
    _reminderEnabled = widget.todo.reminderEnabled;
    _reminderMinutes = widget.todo.reminderMinutes;
    _timeOfDay = widget.todo.timeOfDay;

    _titleController = TextEditingController(text: _title);
    _durationController = TextEditingController(
      text: _durationMinutes?.toString() ?? '',
    );
    _timeOfDayController = TextEditingController(text: _timeOfDay ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _timeOfDayController.dispose();
    super.dispose();
  }

  Future<void> _pickTimeOfDay() async {
    final initial = _reminderMinutes != null
        ? TimeOfDay(hour: _reminderMinutes! ~/ 60, minute: _reminderMinutes! % 60)
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    if (!mounted) return;

    final label = MaterialLocalizations.of(context).formatTimeOfDay(picked);
    final minutes = (picked.hour * 60) + picked.minute;

    setState(() {
      _timeOfDayController.text = label;
      _timeOfDay = label;
      _reminderMinutes = minutes;
      _reminderEnabled = true;
    });
  }

  void _updateIcon() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        _iconCodePoint = IconService.getIconCodePointForTitle(title);
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a todo title')),
      );
      return;
    }

    if (widget.timeMode == 'per_todo') {
      final duration = int.tryParse(_durationController.text);
      if (duration == null || duration <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid duration')),
        );
        return;
      }
      _durationMinutes = duration;
    }

    Navigator.of(context).pop({
      'title': title,
      'iconCodePoint': _iconCodePoint,
      'durationMinutes': _durationMinutes,
      'timerType': _timerType,
      'reminderEnabled': _reminderEnabled,
      'reminderMinutes': _reminderMinutes,
      'timeOfDay': _timeOfDay,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = IconData(_iconCodePoint, fontFamily: 'MaterialIcons');

    return AlertDialog(
      title: const Text('Edit Todo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon preview
            Center(
              child: Icon(icon, size: 48, color: colorScheme.primary),
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Todo Title',
                hintText: 'e.g., Brush teeth',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _updateIcon(),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Duration (if per_todo mode)
            if (widget.timeMode == 'per_todo') ...[
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  hintText: '5',
                  border: OutlineInputBorder(),
                  suffixText: 'minutes',
                ),
              ),
              const SizedBox(height: 16),

              // Timer type selector
              DropdownButtonFormField<String>(
                value: _timerType ?? 'regular',
                decoration: const InputDecoration(
                  labelText: 'Timer Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'regular',
                    child: Text('Regular Timer'),
                  ),
                  DropdownMenuItem(
                    value: 'rhythmic',
                    child: Text('Rhythmic Timer'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _timerType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Reminder section
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Set Reminder',
                    style: AppTypography.body(context),
                  ),
                ),
                Switch(
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() {
                      _reminderEnabled = value;
                      if (!value) {
                        _timeOfDay = null;
                        _reminderMinutes = null;
                        _timeOfDayController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            if (_reminderEnabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _timeOfDayController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                readOnly: true,
                onTap: _pickTimeOfDay,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
