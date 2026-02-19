import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dv_auth_service.dart';
import '../widgets/rituals/habit_form_constants.dart';

/// Structured result from parsing a voice description of a habit.
class ParsedHabitData {
  final String? name;
  final String? category;
  final int? iconIndex;
  final List<int>? weeklyDays;
  final int? duration;
  final String? durationUnit;
  final int? deadlineDays;
  final int? startTimeHour;
  final int? startTimeMinute;
  final String? anchorHabit;
  final String? relationship;
  final String? predictedObstacle;
  final String? ifThenPlan;
  final String? vibrationType;
  final String? notificationSound;
  final List<String>? actionSteps;

  const ParsedHabitData({
    this.name,
    this.category,
    this.iconIndex,
    this.weeklyDays,
    this.duration,
    this.durationUnit,
    this.deadlineDays,
    this.startTimeHour,
    this.startTimeMinute,
    this.anchorHabit,
    this.relationship,
    this.predictedObstacle,
    this.ifThenPlan,
    this.vibrationType,
    this.notificationSound,
    this.actionSteps,
  });

  factory ParsedHabitData.fromJson(Map<String, dynamic> json) {
    return ParsedHabitData(
      name: json['name'] as String?,
      category: json['category'] as String?,
      iconIndex: (json['iconIndex'] as num?)?.toInt(),
      weeklyDays: (json['weeklyDays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      duration: (json['duration'] as num?)?.toInt(),
      durationUnit: json['durationUnit'] as String?,
      deadlineDays: (json['deadlineDays'] as num?)?.toInt(),
      startTimeHour: (json['startTimeHour'] as num?)?.toInt(),
      startTimeMinute: (json['startTimeMinute'] as num?)?.toInt(),
      anchorHabit: json['anchorHabit'] as String?,
      relationship: json['relationship'] as String?,
      predictedObstacle: json['predictedObstacle'] as String?,
      ifThenPlan: json['ifThenPlan'] as String?,
      vibrationType: json['vibrationType'] as String?,
      notificationSound: json['notificationSound'] as String?,
      actionSteps: (json['actionSteps'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  bool get isEmpty =>
      name == null &&
      category == null &&
      weeklyDays == null &&
      duration == null &&
      startTimeHour == null &&
      anchorHabit == null &&
      predictedObstacle == null &&
      ifThenPlan == null &&
      actionSteps == null;
}

/// Sends transcribed voice text to the backend for AI-powered parsing into
/// structured habit fields. Falls back to on-device regex parsing on failure.
final class VoiceHabitParserService {
  VoiceHabitParserService._();

  static Future<ParsedHabitData> parse(String text) async {
    try {
      return await _parseViaBackend(text);
    } catch (_) {
      return _parseLocally(text);
    }
  }

  // ---------------------------------------------------------------------------
  // Backend AI parsing
  // ---------------------------------------------------------------------------

  static Future<ParsedHabitData> _parseViaBackend(String text) async {
    final token = await DvAuthService.getDvToken();
    final base = DvAuthService.backendBaseUrl();
    final uri = Uri.parse('$base/habits/parse-voice');

    final categoriesList = kHabitCategories.join(', ');
    final iconsList = habitIcons
        .asMap()
        .entries
        .map((e) => '${e.key}:${e.value.$2}')
        .join(', ');

    final res = await http
        .post(
          uri,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          body: jsonEncode({
            'text': text,
            'categories': categoriesList,
            'icons': iconsList,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? json;
      return ParsedHabitData.fromJson(data);
    }
    throw Exception('Backend returned ${res.statusCode}');
  }

  // ---------------------------------------------------------------------------
  // On-device fallback (regex / keyword matching)
  // ---------------------------------------------------------------------------

  static ParsedHabitData _parseLocally(String text) {
    final lower = text.toLowerCase().trim();

    final name = _extractName(lower, text);
    final category = _matchCategory(lower);
    final iconIndex = _matchIcon(lower, name);
    final weeklyDays = _extractWeeklyDays(lower);
    final duration = _extractDuration(lower);
    final deadline = _extractDeadlineDays(lower);
    final time = _extractTime(lower);
    final anchor = _extractAnchorHabit(lower);
    final safetyNet = _extractSafetyNet(lower);
    final vibration = _extractVibration(lower);
    final sound = _extractSound(lower);
    final steps = _extractActionSteps(lower);

    return ParsedHabitData(
      name: name,
      category: category,
      iconIndex: iconIndex,
      weeklyDays: weeklyDays,
      duration: duration?.$1,
      durationUnit: duration?.$2,
      deadlineDays: deadline,
      startTimeHour: time?.$1,
      startTimeMinute: time?.$2,
      anchorHabit: anchor?.$1,
      relationship: anchor?.$2,
      predictedObstacle: safetyNet?.$1,
      ifThenPlan: safetyNet?.$2,
      vibrationType: vibration,
      notificationSound: sound,
      actionSteps: steps,
    );
  }

  static String? _extractName(String lower, String original) {
    // "habit of <name>" or "habit to <name>"
    final habitOfRe = RegExp(r'habit\s+(?:of|to)\s+(\w[\w\s]*?)(?:\s+(?:daily|weekly|every|for|at|on|after|before|if)\b|$)');
    final m = habitOfRe.firstMatch(lower);
    if (m != null) {
      final raw = m.group(1)!.trim();
      if (raw.isNotEmpty) {
        return raw[0].toUpperCase() + raw.substring(1);
      }
    }
    return null;
  }

  static String? _matchCategory(String lower) {
    for (final cat in kHabitCategories) {
      if (lower.contains(cat.toLowerCase())) return cat;
    }
    // Infer from activity keywords
    const fitKeywords = ['walk', 'run', 'workout', 'exercise', 'cycling', 'swim', 'jog', 'stretch', 'gym'];
    const healthKeywords = ['water', 'sleep', 'medic', 'vitamin', 'diet'];
    const mindKeywords = ['meditat', 'mindful', 'breathe', 'calm', 'yoga'];
    const learnKeywords = ['read', 'study', 'learn', 'book', 'code', 'practice'];
    const prodKeywords = ['focus', 'work', 'task', 'plan', 'schedule'];

    for (final k in fitKeywords) {
      if (lower.contains(k)) return 'Fitness';
    }
    for (final k in healthKeywords) {
      if (lower.contains(k)) return 'Health';
    }
    for (final k in mindKeywords) {
      if (lower.contains(k)) return 'Mindfulness';
    }
    for (final k in learnKeywords) {
      if (lower.contains(k)) return 'Learning';
    }
    for (final k in prodKeywords) {
      if (lower.contains(k)) return 'Productivity';
    }
    return null;
  }

  static int? _matchIcon(String lower, String? name) {
    final search = (name ?? lower).toLowerCase();
    for (int i = 0; i < habitIcons.length; i++) {
      final label = habitIcons[i].$2.toLowerCase();
      if (search.contains(label) || label.contains(search.split(' ').first)) {
        return i;
      }
    }
    return null;
  }

  static List<int>? _extractWeeklyDays(String lower) {
    if (lower.contains('daily') || lower.contains('every day') || lower.contains('everyday')) {
      return [1, 2, 3, 4, 5, 6, 7];
    }
    if (lower.contains('weekday') || lower.contains('week days')) {
      return [1, 2, 3, 4, 5];
    }
    if (lower.contains('weekend')) {
      return [6, 7];
    }

    const dayMap = {
      'monday': 1, 'mon': 1,
      'tuesday': 2, 'tue': 2,
      'wednesday': 3, 'wed': 3,
      'thursday': 4, 'thu': 4,
      'friday': 5, 'fri': 5,
      'saturday': 6, 'sat': 6,
      'sunday': 7, 'sun': 7,
    };
    final found = <int>{};
    for (final entry in dayMap.entries) {
      if (RegExp('\\b${entry.key}s?\\b').hasMatch(lower)) {
        found.add(entry.value);
      }
    }
    return found.isNotEmpty ? (found.toList()..sort()) : null;
  }

  static (int, String)? _extractDuration(String lower) {
    // "10 mins", "30 minutes", "1 hour", "2 hours"
    final re = RegExp(r'(\d+)\s*(min(?:ute)?s?|hr|hours?)\b');
    final m = re.firstMatch(lower);
    if (m != null) {
      final val = int.tryParse(m.group(1)!);
      if (val != null && val > 0) {
        final u = m.group(2)!;
        final unit = u.startsWith('h') ? 'hours' : 'minutes';
        return (val, unit);
      }
    }
    return null;
  }

  static int? _extractDeadlineDays(String lower) {
    // "for next 30 days", "for 3 months", "next 2 weeks"
    final daysRe = RegExp(r'(?:for\s+)?(?:the\s+)?(?:next\s+)?(\d+)\s*days?\b');
    final monthsRe = RegExp(r'(?:for\s+)?(?:the\s+)?(?:next\s+)?(\d+)\s*months?\b');
    final weeksRe = RegExp(r'(?:for\s+)?(?:the\s+)?(?:next\s+)?(\d+)\s*weeks?\b');

    // Only match days if it doesn't look like a duration (e.g. "10 mins")
    var m = daysRe.firstMatch(lower);
    if (m != null) {
      final fullMatch = m.group(0)!;
      // Require "for" or "next" context to avoid grabbing standalone numbers
      if (fullMatch.contains('for') ||
          fullMatch.contains('next') ||
          RegExp(r'^\d+\s*days?\b').hasMatch(fullMatch.trim())) {
        final v = int.tryParse(m.group(1)!);
        if (v != null && v > 0) return v;
      }
    }
    m = monthsRe.firstMatch(lower);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v > 0) return v * 30;
    }
    m = weeksRe.firstMatch(lower);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v > 0) return v * 7;
    }
    return null;
  }

  static (int, int)? _extractTime(String lower) {
    // Prefer explicit "at" prefix: "at 6am", "at 6:30 pm", "at 14:00"
    final atRe = RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?:\b|$)');
    final result = _matchTimeRegex(atRe, lower);
    if (result != null) return result;

    // Fallback: bare time with am/pm suffix (e.g. "6am", "7:30pm")
    final bareRe = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)(?:\b|$)');
    return _matchTimeRegex(bareRe, lower);
  }

  static (int, int)? _matchTimeRegex(RegExp re, String lower) {
    for (final m in re.allMatches(lower)) {
      int h = int.tryParse(m.group(1)!) ?? -1;
      final min = int.tryParse(m.group(2) ?? '0') ?? 0;
      final ampm = (m.group(3) ?? '').replaceAll('.', '').toLowerCase();

      if (h < 0 || h > 23 || min < 0 || min > 59) continue;

      if (ampm == 'pm' && h < 12) h += 12;
      if (ampm == 'am' && h == 12) h = 0;

      return (h, min);
    }
    return null;
  }

  static (String, String)? _extractAnchorHabit(String lower) {
    // "after brushing my teeth", "before morning coffee"
    final afterRe = RegExp(r'(?:do\s+(?:it|this)\s+)?after\s+(.+?)(?:\.|,|$|\s+if\b|\s+for\b)');
    final beforeRe = RegExp(r'before\s+(.+?)(?:\.|,|$|\s+if\b|\s+for\b)');

    var m = afterRe.firstMatch(lower);
    if (m != null) {
      final raw = m.group(1)!.trim().replaceAll(RegExp(r'\s*(?:my|the)\s*'), ' ').trim();
      if (raw.isNotEmpty) return (_capitalize(raw), 'After');
    }
    m = beforeRe.firstMatch(lower);
    if (m != null) {
      final raw = m.group(1)!.trim().replaceAll(RegExp(r'\s*(?:my|the)\s*'), ' ').trim();
      if (raw.isNotEmpty) return (_capitalize(raw), 'Before');
    }
    return null;
  }

  static (String, String)? _extractSafetyNet(String lower) {
    // "if too tired I will walk 2 mins", "if not I will just do 2 minutes"
    final re = RegExp(r'if\s+(?:i(?:\'?m)?\s+)?(.+?)\s+(?:i\s+will|then\s+i(?:\'?ll)?\s+|i(?:\'?ll)\s+)(.+?)(?:\.|,|$)');
    final m = re.firstMatch(lower);
    if (m != null) {
      final obstacle = m.group(1)!.trim();
      final plan = m.group(2)!.trim();
      if (obstacle.isNotEmpty && plan.isNotEmpty) {
        return (_capitalize(obstacle), 'I will ${plan}');
      }
    }

    // Simpler: "if not <action>"
    final simpleRe = RegExp(r'if\s+not\s+(?:i\s+will\s+)?(.+?)(?:\.|,|$)');
    final sm = simpleRe.firstMatch(lower);
    if (sm != null) {
      final plan = sm.group(1)!.trim();
      if (plan.isNotEmpty) {
        return ("I'm not feeling up to it", 'I will $plan');
      }
    }
    return null;
  }

  static String? _extractVibration(String lower) {
    if (lower.contains('no vibrat')) return 'none';
    if (lower.contains('short vibrat')) return 'short';
    if (lower.contains('long vibrat')) return 'long';
    if (lower.contains('vibrat')) return 'default';
    return null;
  }

  static String? _extractSound(String lower) {
    if (lower.contains('no sound') || lower.contains('silent')) return 'none';
    if (lower.contains('chime')) return 'chime';
    if (lower.contains('bell')) return 'bell';
    if (lower.contains('gentle')) return 'gentle';
    if (lower.contains('alert sound') || lower.contains('alert notif')) return 'alert';
    return null;
  }

  static List<String>? _extractActionSteps(String lower) {
    // "steps: step1, step2, step3" or "following steps <list>"
    final re = RegExp(r'(?:steps?\s*(?:are|:|\-)\s*|following\s+steps?\s*(?:are|:|\-)?\s*)(.+?)(?:\.|$)');
    final m = re.firstMatch(lower);
    if (m != null) {
      final raw = m.group(1)!.trim();
      final parts = raw
          .split(RegExp(r'[,;]\s*|\s+and\s+|\s+then\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(_capitalize)
          .toList();
      if (parts.isNotEmpty) return parts;
    }
    return null;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
