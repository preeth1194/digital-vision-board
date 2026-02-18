import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

/// Shows an iOS-style time picker with scroll wheels (hours, minutes, AM/PM).
Future<TimeOfDay?> showCupertinoTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  final now = DateTime.now();
  DateTime selected = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(TimeOfDay.fromDateTime(selected)),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: selected,
                  use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                  minuteInterval: 1,
                  onDateTimeChanged: (v) => selected = v,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// --- STEP 4: TRIGGERS ---
class Step4Triggers extends StatefulWidget {
  final Color habitColor;
  final bool showReminderFields;
  final bool showDurationField;
  final TimeOfDay? scheduleStartTime;
  final TimeOfDay? selectedTime;
  final bool reminderEnabled;
  final TimeOfDay? reminderTime;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderMinutesBeforeChanged;
  final int durationValue;
  final String durationUnit;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final void Function(int value, String unit) onDurationChanged;
  final bool locationEnabled;
  final double? lat;
  final double? lng;
  final int radius;
  final String triggerMode;
  final int dwellMinutes;
  final ValueChanged<TimeOfDay?> onTimeChanged;
  final ValueChanged<bool> onReminderToggle;
  final ValueChanged<TimeOfDay?> onReminderTimeChanged;
  final ValueChanged<bool> onLocationToggle;
  final void Function(double, double) onLocationSelected;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<String> onTriggerModeChanged;
  final ValueChanged<int> onDwellMinutesChanged;

  final String? timeConflictError;
  final TimeOfDay? suggestedStartTime;
  final String? slotAvailableInfo;
  final VoidCallback? onSuggestionTap;

  const Step4Triggers({
    super.key,
    required this.habitColor,
    this.showReminderFields = true,
    this.showDurationField = true,
    this.scheduleStartTime,
    required this.selectedTime,
    required this.reminderEnabled,
    required this.reminderTime,
    this.reminderMinutesBefore,
    required this.onReminderMinutesBeforeChanged,
    required this.durationValue,
    required this.durationUnit,
    required this.onStartTimeChanged,
    required this.onDurationChanged,
    required this.locationEnabled,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.triggerMode,
    required this.dwellMinutes,
    required this.onTimeChanged,
    required this.onReminderToggle,
    required this.onReminderTimeChanged,
    required this.onLocationToggle,
    required this.onLocationSelected,
    required this.onRadiusChanged,
    required this.onTriggerModeChanged,
    required this.onDwellMinutesChanged,
    this.timeConflictError,
    this.suggestedStartTime,
    this.slotAvailableInfo,
    this.onSuggestionTap,
  });

  @override
  State<Step4Triggers> createState() => _Step4TriggersState();
}

class _Step4TriggersState extends State<Step4Triggers> {
  bool _startTimePickerExpanded = false;
  bool _durationExpanded = false;
  bool _alertExpanded = false;
  late DateTime _pendingStartDateTime;
  late TextEditingController _durationController;
  late FocusNode _durationFocusNode;

  void _syncPendingFromStartTime() {
    final st = widget.scheduleStartTime ?? TimeOfDay.now();
    final now = DateTime.now();
    _pendingStartDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      st.hour,
      st.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.durationValue.toString(),
    );
    _durationFocusNode = FocusNode();
    _durationFocusNode.addListener(() {
      if (!_durationFocusNode.hasFocus && mounted) {
        setState(() => _durationExpanded = false);
      }
    });
    _syncPendingFromStartTime();
  }

  @override
  void didUpdateWidget(Step4Triggers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationValue != widget.durationValue &&
        _durationController.text != widget.durationValue.toString()) {
      _durationController.text = widget.durationValue.toString();
    }
    if (oldWidget.scheduleStartTime != widget.scheduleStartTime &&
        !_startTimePickerExpanded) {
      _syncPendingFromStartTime();
    }
    if (oldWidget.reminderEnabled && !widget.reminderEnabled) {
      _alertExpanded = false;
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _durationFocusNode.dispose();
    super.dispose();
  }

  void _onDurationTextChanged(String text) {
    final parsed = int.tryParse(text);
    final value = parsed ?? 0;
    final maxVal = widget.durationUnit == 'hours' ? 24 : 1440;
    widget.onDurationChanged(value.clamp(0, maxVal), widget.durationUnit);
  }

  void _confirmStartTime() {
    widget.onStartTimeChanged(TimeOfDay.fromDateTime(_pendingStartDateTime));
    setState(() => _startTimePickerExpanded = false);
  }

  static String _formatMinutesBefore(int mins) =>
      mins == 60 ? '1 hour before' : '$mins mins before';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final startDefault = TimeOfDay.now();
    final displayStart = widget.scheduleStartTime ?? startDefault;

    final String sectionTitle;
    if (widget.showReminderFields && widget.showDurationField) {
      sectionTitle = "Reminders & Timer";
    } else if (widget.showDurationField) {
      sectionTitle = "Timer";
    } else {
      sectionTitle = "Reminders";
    }

    return CupertinoListSection.insetGrouped(
      header: Text(
        sectionTitle,
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
        // Start time row
        if (widget.showReminderFields) Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    if (_startTimePickerExpanded) {
                      _confirmStartTime();
                    } else {
                      _syncPendingFromStartTime();
                      _startTimePickerExpanded = true;
                      _durationExpanded = false;
                      _alertExpanded = false;
                    }
                  });
                },
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Start time",
                              style: AppTypography.bodySmall(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              displayStart.format(context),
                              style: AppTypography.body(context).copyWith(
                                color: widget.timeConflictError != null
                                    ? colorScheme.error
                                    : widget.habitColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.timeConflictError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.timeConflictError!,
                                style: TextStyle(color: colorScheme.error, fontSize: 12),
                              ),
                              if (widget.suggestedStartTime != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: GestureDetector(
                                    onTap: widget.onSuggestionTap,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Try ${widget.suggestedStartTime!.format(context)}',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ] else if (widget.slotAvailableInfo != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 14, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.slotAvailableInfo!,
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_startTimePickerExpanded)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: theme.brightness == Brightness.dark
                          ? Brightness.dark
                          : Brightness.light,
                    ),
                    child: SizedBox(
                      height: 180,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: _pendingStartDateTime,
                        use24hFormat: MediaQuery.of(context)
                            .alwaysUse24HourFormat,
                        minuteInterval: 1,
                        onDateTimeChanged: (v) =>
                            setState(() => _pendingStartDateTime = v),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirmStartTime,
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        // Duration row
        if (widget.showDurationField) Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _durationExpanded = true;
                    _startTimePickerExpanded = false;
                    _alertExpanded = false;
                  });
                },
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Duration",
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          _durationExpanded
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      child: TextField(
                                        controller: _durationController,
                                        focusNode: _durationFocusNode,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        autofocus: true,
                                        style: AppTypography.body(context)
                                            .copyWith(
                                              fontSize: 18,
                                              color: widget.habitColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        decoration: InputDecoration(
                                          hintText: '5',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: widget.habitColor,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        onChanged: _onDurationTextChanged,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: widget.durationUnit,
                                        isExpanded: false,
                                        underline: const SizedBox.shrink(),
                                        style: AppTypography.body(context)
                                            .copyWith(
                                              fontSize: 18,
                                              color: widget.habitColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'minutes',
                                            child: Text('min'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'hours',
                                            child: Text('hr'),
                                          ),
                                        ],
                                        onChanged: (unit) {
                                          if (unit != null) {
                                            widget.onDurationChanged(
                                              widget.durationValue,
                                              unit,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  "${widget.durationValue} ${widget.durationUnit == 'hours' ? 'hr' : 'min'}",
                                  style: AppTypography.body(context)
                                      .copyWith(
                                        color: widget.habitColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Alert row (collapsible when reminder enabled)
        if (widget.showReminderFields) Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.reminderEnabled
                    ? () {
                        setState(() {
                          _alertExpanded = !_alertExpanded;
                          _startTimePickerExpanded = false;
                          _durationExpanded = false;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Alert",
                              style: AppTypography.bodySmall(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              widget.reminderEnabled
                                  ? _formatMinutesBefore(
                                      widget.reminderMinutesBefore ??
                                          kReminderMinutesBeforeOptions.first,
                                    )
                                  : "Off",
                              style: AppTypography.body(context).copyWith(
                                color: widget.reminderEnabled
                                    ? widget.habitColor
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: widget.reminderEnabled,
                        onChanged: widget.onReminderToggle,
                        activeTrackColor: widget.habitColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_alertExpanded && widget.reminderEnabled)
              Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    ...kReminderMinutesBeforeOptions.map((mins) {
                      final isSelected =
                          (widget.reminderMinutesBefore ?? 15) == mins;
                      return InkWell(
                        onTap: () {
                          widget.onReminderMinutesBeforeChanged(mins);
                          setState(() => _alertExpanded = false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatMinutesBefore(mins),
                                  style: AppTypography.body(context),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check,
                                  color: widget.habitColor,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
        // Location row
        if (widget.showReminderFields) Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                Icons.location_on_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              title: Text(
                "Location",
                style: AppTypography.body(context),
              ),
              additionalInfo: widget.lat != null
                  ? Text(
                      "Location set",
                      style: AppTypography.body(context).copyWith(
                        color: widget.habitColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              trailing: CupertinoSwitch(
                value: widget.locationEnabled,
                onChanged: widget.onLocationToggle,
                activeTrackColor: widget.habitColor,
              ),
              onTap: () async {
                if (widget.locationEnabled) return;
                try {
                  LocationPermission p =
                      await Geolocator.checkPermission();
                  if (p == LocationPermission.denied) {
                    p = await Geolocator.requestPermission();
                  }
                  if (p == LocationPermission.whileInUse ||
                      p == LocationPermission.always) {
                    final pos =
                        await Geolocator.getCurrentPosition();
                    widget.onLocationSelected(
                        pos.latitude, pos.longitude);
                    widget.onLocationToggle(true);
                  }
                } catch (e) {
                  debugPrint('Location error: $e');
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
