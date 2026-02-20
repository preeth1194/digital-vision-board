import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/notifications_service.dart';
import '../../services/sound_preview_service.dart';
import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';
import 'location_map_picker_screen.dart';

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
  final String? locationAddress;
  final ValueChanged<String?> onAddressChanged;
  final ValueChanged<bool> onLocationToggle;
  final void Function(double, double) onLocationSelected;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<String> onTriggerModeChanged;
  final ValueChanged<int> onDwellMinutesChanged;

  final String? timeConflictError;
  final TimeOfDay? suggestedStartTime;
  final String? slotAvailableInfo;
  final VoidCallback? onSuggestionTap;

  final String notificationSound;
  final ValueChanged<String> onNotificationSoundChanged;
  final String vibrationType;
  final ValueChanged<String> onVibrationTypeChanged;

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
    this.locationAddress,
    required this.onAddressChanged,
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
    required this.notificationSound,
    required this.onNotificationSoundChanged,
    required this.vibrationType,
    required this.onVibrationTypeChanged,
  });

  @override
  State<Step4Triggers> createState() => _Step4TriggersState();
}

class _Step4TriggersState extends State<Step4Triggers> {
  bool _startTimePickerExpanded = false;
  bool _durationExpanded = false;
  late DateTime _pendingStartDateTime;
  late TextEditingController _durationController;
  late FocusNode _durationFocusNode;

  // Location picker state
  /// 'current' or 'custom'
  String _locationPickerType = 'current';
  bool _isGeocodingLoading = false;

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

  Future<void> _grabCurrentLocation() async {
    setState(() => _isGeocodingLoading = true);
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        widget.onLocationSelected(pos.latitude, pos.longitude);
        widget.onLocationToggle(true);
        await _reverseGeocode(pos.latitude, pos.longitude);
        // Ensure notification permission so geofence completion alerts can show.
        NotificationsService.requestPermissionsIfNeeded();
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
    if (mounted) setState(() => _isGeocodingLoading = false);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          [
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
          ].join(', '),
          [
            if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ].join(' '),
        ].where((s) => s.trim().isNotEmpty).toList();
        widget.onAddressChanged(parts.join('\n'));
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  Widget _buildLocationExpanded(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          // Type selector row
          Row(
            children: [
              _buildLocationTypeButton(
                colorScheme: colorScheme,
                icon: Icons.near_me_rounded,
                label: 'Current',
                type: 'current',
              ),
              const SizedBox(width: 12),
              _buildLocationTypeButton(
                colorScheme: colorScheme,
                icon: Icons.search_rounded,
                label: 'Custom',
                type: 'custom',
              ),
            ],
          ),
          // Loading indicator
          if (_isGeocodingLoading) ...[
            const SizedBox(height: 12),
            const Center(child: CupertinoActivityIndicator()),
          ],
          // Address display
          if (!_isGeocodingLoading && widget.locationAddress != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.locationAddress!,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Arriving / Leaving segmented control
          if (widget.lat != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: widget.triggerMode,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                thumbColor: theme.brightness == Brightness.dark
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surface,
                children: {
                  'arrival': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'Arriving',
                      style: AppTypography.bodySmall(context).copyWith(
                        fontWeight: widget.triggerMode == 'arrival' ? FontWeight.w600 : FontWeight.normal,
                        color: widget.triggerMode == 'arrival'
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  'departure': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'Leaving',
                      style: AppTypography.bodySmall(context).copyWith(
                        fontWeight: widget.triggerMode == 'departure' ? FontWeight.w600 : FontWeight.normal,
                        color: widget.triggerMode == 'departure'
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                },
                onValueChanged: (v) {
                  if (v != null) widget.onTriggerModeChanged(v);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LocationMapPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationMapPickerScreen(
          initialLat: widget.lat,
          initialLng: widget.lng,
        ),
      ),
    );
    if (result != null && mounted) {
      widget.onLocationSelected(result.lat, result.lng);
      widget.onLocationToggle(true);
      widget.onAddressChanged(result.address);
      setState(() => _locationPickerType = 'custom');
    }
  }

  Widget _buildLocationTypeButton({
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String type,
  }) {
    final selected = _locationPickerType == type;
    return GestureDetector(
      onTap: () {
        if (type == 'current') {
          setState(() => _locationPickerType = type);
          _grabCurrentLocation();
        } else if (type == 'custom') {
          _openMapPicker();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showSoundPickerSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _SoundPickerSheetBody(
          currentSound: widget.notificationSound,
          isCustom: _isCustomSound,
          onSoundSelected: (id) {
            widget.onNotificationSoundChanged(id);
          },
          onCustomFilePicked: (path) {
            widget.onNotificationSoundChanged(path);
          },
        );
      },
    ).then((_) => SoundPreviewService.dispose());
  }

  bool get _isCustomSound {
    final s = widget.notificationSound;
    return !kNotificationSoundOptions.any((opt) => opt.$1 == s);
  }

  Widget _buildNotificationSoundRow(ColorScheme colorScheme, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSoundPickerSheet(context),
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.volume_up_outlined,
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
                      'Notification sound',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      notificationSoundLabel(widget.notificationSound),
                      style: AppTypography.body(context).copyWith(
                        color: widget.habitColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVibrateTypeRow(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.vibration_outlined,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                'Vibrate',
                style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: widget.vibrationType,
              backgroundColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              thumbColor: theme.brightness == Brightness.dark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              children: {
                for (final opt in kVibrateTypeOptions)
                  opt.$1: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      opt.$2,
                      style: AppTypography.bodySmall(context).copyWith(
                        fontWeight: widget.vibrationType == opt.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: widget.vibrationType == opt.$1
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
              },
              onValueChanged: (v) {
                if (v != null) {
                  HapticFeedback.selectionClick();
                  widget.onVibrationTypeChanged(v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final startDefault = TimeOfDay.now();
    final displayStart = widget.scheduleStartTime ?? startDefault;

    final String sectionTitle;
    if (widget.showReminderFields && widget.showDurationField) {
      sectionTitle = "Timer & Location";
    } else if (widget.showDurationField) {
      sectionTitle = "Timer";
    } else {
      sectionTitle = "Location";
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
        // Start time row (part of Timer addon)
        if (widget.showDurationField) Column(
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
                                style: AppTypography.caption(context).copyWith(color: colorScheme.error),
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
                                        style: AppTypography.caption(context).copyWith(
                                          color: colorScheme.primary,
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
                                      style: AppTypography.caption(context).copyWith(
                                        color: colorScheme.primary,
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
                  if (_startTimePickerExpanded) {
                    _confirmStartTime();
                  }
                  setState(() {
                    _durationExpanded = true;
                    _startTimePickerExpanded = false;
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
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                        ],
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
        // Notification sound row
        if (widget.showDurationField) _buildNotificationSoundRow(colorScheme, theme),
        // Vibrate type row
        if (widget.showDurationField) _buildVibrateTypeRow(colorScheme, theme),
        // Location row
        if (widget.showReminderFields) Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Location",
                        style: AppTypography.body(context),
                      ),
                    ),
                    CupertinoSwitch(
                      value: widget.locationEnabled,
                      onChanged: (v) {
                        widget.onLocationToggle(v);
                        if (!v) {
                          widget.onAddressChanged(null);
                        }
                      },
                      activeTrackColor: widget.habitColor,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.locationEnabled) _buildLocationExpanded(colorScheme, theme),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sound picker bottom sheet (stateful so selection + preview update inline)
// ---------------------------------------------------------------------------

class _SoundPickerSheetBody extends StatefulWidget {
  final String currentSound;
  final bool isCustom;
  final ValueChanged<String> onSoundSelected;
  final ValueChanged<String> onCustomFilePicked;

  const _SoundPickerSheetBody({
    required this.currentSound,
    required this.isCustom,
    required this.onSoundSelected,
    required this.onCustomFilePicked,
  });

  @override
  State<_SoundPickerSheetBody> createState() => _SoundPickerSheetBodyState();
}

class _SoundPickerSheetBodyState extends State<_SoundPickerSheetBody> {
  late String _selected;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSound;
  }

  bool get _isCustomSelected =>
      !kNotificationSoundOptions.any((opt) => opt.$1 == _selected);

  Future<void> _selectAndPreview(String id) async {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = id;
      _playingId = id;
    });
    widget.onSoundSelected(id);
    await SoundPreviewService.playPreview(id);
    if (mounted) setState(() => _playingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Notification Sound',
              style: AppTypography.body(context).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Scrollable list of options
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final opt in kNotificationSoundOptions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      opt.$3,
                      color: _selected == opt.$1
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    title: Text(
                      opt.$2,
                      style: AppTypography.body(context).copyWith(
                        fontWeight: _selected == opt.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _selected == opt.$1
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_playingId == opt.$1)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        if (_selected == opt.$1)
                          Icon(Icons.check_rounded,
                              color: colorScheme.primary, size: 20),
                      ],
                    ),
                    onTap: () => _selectAndPreview(opt.$1),
                  ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: _isCustomSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  title: Text(
                    _isCustomSelected
                        ? 'Custom (selected)'
                        : 'Choose from files...',
                    style: AppTypography.body(context).copyWith(
                      fontWeight: _isCustomSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _isCustomSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  trailing: _isCustomSelected
                      ? Icon(Icons.check_rounded,
                          color: colorScheme.primary, size: 20)
                      : null,
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.audio,
                    );
                    if (result != null && result.files.single.path != null) {
                      final path = result.files.single.path!;
                      widget.onCustomFilePicked(path);
                      setState(() => _selected = path);
                      await SoundPreviewService.playPreview(path);
                    }
                  },
                ),
              ],
            ),
          ),
          // Done button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
