import 'package:flutter/material.dart';

import '../services/support_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';

class MyIssuesScreen extends StatefulWidget {
  const MyIssuesScreen({super.key});

  @override
  State<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends State<MyIssuesScreen> {
  bool _loading = true;
  String? _error;
  List<UserIssueReport> _issues = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issues = await SupportService.listMyIssues(limit: 200);
      if (!mounted) return;
      setState(() => _issues = issues);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String, Color, Color) _statusStyle(BuildContext context, String status) {
    final dcs = Theme.of(context).colorScheme;
    switch (status) {
      case 'resolved':
        return ('Resolved', dcs.primaryContainer, dcs.onPrimaryContainer);
      case 'in_progress':
        return ('In Progress', dcs.tertiaryContainer, dcs.onTertiaryContainer);
      default:
        return ('Open', dcs.secondaryContainer, dcs.onSecondaryContainer);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dcs = Theme.of(context).colorScheme;
    return Container(
      decoration: AppColors.skyDecoration(isDark: isDark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Issues'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              Text('My Issues', style: AppTypography.heading1(context)),
              const SizedBox(height: 8),
              Text(
                'Track the status of reports you sent to support.',
                style: AppTypography.secondary(context),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dcs.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: TextStyle(color: dcs.onErrorContainer)),
                )
              else if (_issues.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dcs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No issue reports yet. Submit one from Report Issue.',
                    style: AppTypography.body(context).copyWith(color: dcs.onSurface),
                  ),
                )
              else
                ..._issues.map((issue) {
                  final status = _statusStyle(context, issue.status);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dcs.surfaceContainerHighest.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                issue.subject.isNotEmpty ? issue.subject : issue.message,
                                style: AppTypography.body(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w700, color: dcs.onSurface),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: status.$2,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status.$1,
                                style: AppTypography.caption(
                                  context,
                                ).copyWith(color: status.$3, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          issue.message,
                          style: AppTypography.bodySmall(context).copyWith(color: dcs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(issue.createdAt),
                          style: AppTypography.caption(context).copyWith(color: dcs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
