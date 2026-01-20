import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';
import '../models/routine_todo_item.dart';
import '../services/routine_storage_service.dart';
import '../services/logical_date_service.dart';
import '../utils/app_typography.dart';

class RoutineExecutionScreen extends StatefulWidget {
  final Routine routine;

  const RoutineExecutionScreen({
    super.key,
    required this.routine,
  });

  @override
  State<RoutineExecutionScreen> createState() => _RoutineExecutionScreenState();
}

class _RoutineExecutionScreenState extends State<RoutineExecutionScreen> {
  late SharedPreferences _prefs;
  bool _loading = true;
  int _currentTodoIndex = 0;
  Routine? _routine;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _routine = widget.routine;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    _isRunning = true;
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
  }

  void _resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _elapsedSeconds = 0;
    _startTime = null;
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _markTodoComplete(RoutineTodoItem todo) async {
    final logicalDate = await LogicalDateService.getLogicalDate(prefs: _prefs);
    final updatedTodo = todo.toggleForDate(logicalDate);

    setState(() {
      final index = _routine!.todos.indexWhere((t) => t.id == todo.id);
      if (index >= 0) {
        _routine!.todos[index] = updatedTodo;
      }
    });

    // Save routine
    final routines = await RoutineStorageService.loadRoutines(prefs: _prefs);
    final updated = routines.map((r) => r.id == _routine!.id ? _routine! : r).toList();
    await RoutineStorageService.saveRoutines(updated, prefs: _prefs);
  }

  void _nextTodo() {
    if (_currentTodoIndex < _routine!.todos.length - 1) {
      setState(() {
        _currentTodoIndex++;
        _resetTimer();
      });
    }
  }

  void _previousTodo() {
    if (_currentTodoIndex > 0) {
      setState(() {
        _currentTodoIndex--;
        _resetTimer();
      });
    }
  }

  RoutineTodoItem? get _currentTodo {
    if (_routine == null || _routine!.todos.isEmpty) return null;
    if (_currentTodoIndex >= _routine!.todos.length) return null;
    return _routine!.todos[_currentTodoIndex];
  }

  double get _progress {
    if (_routine == null || _routine!.todos.isEmpty) return 0.0;
    final completed = _routine!.todos.where((todo) {
      final logicalDate = LogicalDateService.getLogicalDateSync(prefs: _prefs);
      return todo.isCompletedOnDate(logicalDate);
    }).length;
    return completed / _routine!.todos.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _routine == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentTodo = _currentTodo;

    if (currentTodo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_routine!.title)),
        body: const Center(child: Text('No todos in routine')),
      );
    }

    final icon = IconData(currentTodo.iconCodePoint, fontFamily: 'MaterialIcons');
    final isCompleted = currentTodo.isCompletedOnDate(
      LogicalDateService.getLogicalDateSync(prefs: _prefs),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_routine!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: colorScheme.surfaceVariant,
            minHeight: 4,
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current todo number
                  Center(
                    child: Text(
                      '${_currentTodoIndex + 1} of ${_routine!.todos.length}',
                      style: AppTypography.caption(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Todo icon
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 64,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Todo title
                  Center(
                    child: Text(
                      currentTodo.title,
                      style: AppTypography.heading2(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Timer section (if per_todo mode)
                  if (_routine!.timeMode == 'per_todo' && currentTodo.durationMinutes != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Timer',
                              style: AppTypography.heading3(context),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _formatDuration(_elapsedSeconds),
                              style: AppTypography.heading1(context).copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${currentTodo.durationMinutes} minutes',
                              style: AppTypography.bodySmall(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isRunning)
                                  FilledButton.icon(
                                    onPressed: _startTimer,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Start'),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: _pauseTimer,
                                    icon: const Icon(Icons.pause),
                                    label: const Text('Pause'),
                                  ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: _resetTimer,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Overall timer (if overall mode)
                  if (_routine!.timeMode == 'overall' && _routine!.overallDurationMinutes != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Overall Timer',
                              style: AppTypography.heading3(context),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _formatDuration(_elapsedSeconds),
                              style: AppTypography.heading1(context).copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${_routine!.overallDurationMinutes} minutes',
                              style: AppTypography.bodySmall(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isRunning)
                                  FilledButton.icon(
                                    onPressed: _startTimer,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Start'),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: _pauseTimer,
                                    icon: const Icon(Icons.pause),
                                    label: const Text('Pause'),
                                  ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: _resetTimer,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Completion checkbox
                  Card(
                    child: CheckboxListTile(
                      title: Text(
                        'Mark as complete',
                        style: AppTypography.body(context),
                      ),
                      value: isCompleted,
                      onChanged: (value) {
                        _markTodoComplete(currentTodo);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentTodoIndex > 0 ? _previousTodo : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _currentTodoIndex < _routine!.todos.length - 1
                          ? _nextTodo
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
