import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dv_auth_service.dart';

class UserIssueReport {
  final int id;
  final String subject;
  final String message;
  final String status;
  final DateTime? createdAt;

  const UserIssueReport({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory UserIssueReport.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt'];
    final createdAt = rawCreated is String ? DateTime.tryParse(rawCreated) : null;
    return UserIssueReport(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: (json['subject'] as String? ?? '').trim(),
      message: (json['message'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'open').trim().toLowerCase(),
      createdAt: createdAt,
    );
  }
}

final class SupportService {
  SupportService._();

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static Future<void> submitContactMessage({
    required String name,
    required String email,
    required String message,
    String? subject,
    bool reportIssue = false,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanMessage = message.trim();

    if (cleanName.isEmpty) {
      throw Exception('Please enter your name.');
    }
    if (cleanEmail.isEmpty) {
      throw Exception('Please enter your email.');
    }
    if (cleanMessage.isEmpty) {
      throw Exception('Please enter a message.');
    }

    final token = await DvAuthService.getDvToken();
    if (reportIssue && (token == null || token.trim().isEmpty)) {
      throw Exception('Please sign in before reporting an issue.');
    }

    final res = await http.post(
      _url('/contact'),
      headers: {
        'content-type': 'application/json',
        'accept': 'application/json',
        if ((token ?? '').isNotEmpty) 'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': cleanName,
        'email': cleanEmail,
        'message': cleanMessage,
        if ((subject ?? '').trim().isNotEmpty) 'subject': subject!.trim(),
        'kind': reportIssue ? 'issue' : 'contact',
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to send message (${res.statusCode}). Please try again.');
    }
  }

  static Future<void> submitIssueReport({
    required String name,
    required String email,
    required String summary,
    required String details,
    String? steps,
  }) async {
    final cleanSummary = summary.trim();
    final cleanDetails = details.trim();
    final cleanSteps = (steps ?? '').trim();
    if (cleanSummary.isEmpty) {
      throw Exception('Please enter an issue summary.');
    }
    if (cleanDetails.isEmpty) {
      throw Exception('Please enter issue details.');
    }

    final parts = <String>[
      cleanDetails,
      if (cleanSteps.isNotEmpty) '',
      if (cleanSteps.isNotEmpty) 'Steps to reproduce:',
      if (cleanSteps.isNotEmpty) cleanSteps,
    ];
    await submitContactMessage(
      name: name,
      email: email,
      message: parts.join('\n'),
      subject: cleanSummary,
      reportIssue: true,
    );
  }

  static Future<List<UserIssueReport>> listMyIssues({int limit = 100}) async {
    final token = await DvAuthService.getDvToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please sign in to view your issues.');
    }
    final safeLimit = limit.clamp(1, 500);
    final res = await http.get(
      _url('/contact/issues?limit=$safeLimit'),
      headers: {
        'accept': 'application/json',
        'authorization': 'Bearer $token',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to load issues (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final list = decoded['issues'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(UserIssueReport.fromJson)
        .where((issue) => issue.id > 0)
        .toList();
  }
}
