import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../services/boards_storage_service.dart';
import '../../services/dv_auth_service.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../models/board_template.dart';
import '../../services/templates_service.dart';
import '../../services/vision_board_components_storage_service.dart';
import '../../widgets/dialogs/text_input_dialog.dart';

class TemplatesAdminScreen extends StatefulWidget {
  const TemplatesAdminScreen({super.key});

  @override
  State<TemplatesAdminScreen> createState() => _TemplatesAdminScreenState();
}

class _TemplatesAdminScreenState extends State<TemplatesAdminScreen> {
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  List<BoardTemplateSummary> _templates = const [];
  String? _canvaUserId;
  bool _wizardSyncing = false;
  Timer? _wizardSyncPoll;
  String? _wizardSyncJobId;
  String? _wizardSyncStatusText;
  int _wizardSyncLastLoggedFailed = 0;

  bool get _isLocalBackend {
    final base = DvAuthService.backendBaseUrl().toLowerCase();
    // Common local dev hosts:
    // - Android emulator: 10.0.2.2
    // - iOS simulator / desktop: localhost / 127.0.0.1
    return base.contains('10.0.2.2') || base.contains('localhost') || base.contains('127.0.0.1');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wizardSyncPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final canvaUserId = await DvAuthService.getCanvaUserId();
      final token = await DvAuthService.getDvToken();
      if (token == null) throw Exception('Not authenticated.');
      final list = await TemplatesService.adminListTemplates(dvToken: token);
      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _templates = list;
        _canvaUserId = canvaUserId;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _isAdmin = !msg.contains('403') && !msg.contains('forbidden') ? _isAdmin : false;
        _error = msg;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectCanvaOAuth() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canva OAuth is not supported on web yet.')),
      );
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await DvAuthService.connectViaCanvaOAuth();
      if (!mounted) return;
      setState(() => _canvaUserId = res.canvaUserId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected as ${res.canvaUserId ?? 'Canva user'}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<VisionBoardInfo?> _pickBoard(List<VisionBoardInfo> boards) async {
    return showModalBottomSheet<VisionBoardInfo>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Pick a board', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('We will publish a sanitized snapshot (no habits/tasks/CBT).'),
            ),
            for (final b in boards)
              ListTile(
                title: Text(b.title),
                subtitle: Text(b.layoutType == VisionBoardInfo.layoutGrid ? 'Grid' : 'Goal Canvas'),
                onTap: () => Navigator.of(ctx).pop(b),
              ),
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _sanitizeGoalMetadata(Map<String, dynamic> goal) {
    return <String, dynamic>{
      'title': goal['title'],
      'deadline': goal['deadline'],
      'category': goal['category'],
      'cbt_metadata': null,
      'action_plan': null,
    };
  }

  Future<void> _publishFromExistingBoard() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publishing templates is not supported on web yet.')),
      );
      return;
    }

    final token = await DvAuthService.getDvToken();
    if (token == null) throw Exception('Not authenticated.');

    final prefs = await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final eligible = boards
        .where((b) => b.layoutType == VisionBoardInfo.layoutGoalCanvas || b.layoutType == VisionBoardInfo.layoutGrid)
        .toList();
    if (!mounted) return;
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No eligible boards found.')));
      return;
    }

    final board = await _pickBoard(eligible);
    if (!mounted) return;
    if (board == null) return;

    final name = await showTextInputDialog(
      context,
      title: 'Template name',
      initialText: board.title,
    );
    if (!mounted) return;
    final templateName = (name ?? '').trim();
    if (templateName.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String kind;
      Map<String, dynamic> templateJson;
      String? previewImageId;

      if (board.layoutType == VisionBoardInfo.layoutGoalCanvas) {
        kind = 'goal_canvas';
        final comps = await VisionBoardComponentsStorageService.loadComponents(board.id, prefs: prefs);
        final sanitized = <Map<String, dynamic>>[];

        for (final c in comps) {
          final m = Map<String, dynamic>.from(c.toJson());
          m['habits'] = [];
          m['tasks'] = [];

          if (m['type'] == 'image' && m['imagePath'] is String) {
            final p = (m['imagePath'] as String).trim();
            if (!p.toLowerCase().startsWith('http://') &&
                !p.toLowerCase().startsWith('https://') &&
                p.isNotEmpty) {
              final url = await TemplatesService.adminUploadTemplateImageFile(p, dvToken: token);
              m['imagePath'] = url;
              // Parse id from /template-images/<id>
              final seg = Uri.parse(url).pathSegments;
              if (previewImageId == null && seg.length >= 2 && seg[0] == 'template-images') {
                previewImageId = seg[1];
              }
            }
          }

          if (m['goal'] is Map<String, dynamic>) {
            m['goal'] = _sanitizeGoalMetadata(m['goal'] as Map<String, dynamic>);
          }

          sanitized.add(m);
        }

        templateJson = {'components': sanitized};
      } else {
        kind = 'grid';
        final templateId = board.templateId;
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
        final sanitized = <Map<String, dynamic>>[];

        for (final t in tiles) {
          final m = Map<String, dynamic>.from(t.toJson());
          m['habits'] = [];
          m['tasks'] = [];

          if (m['goal'] is Map<String, dynamic>) {
            m['goal'] = _sanitizeGoalMetadata(m['goal'] as Map<String, dynamic>);
          }

          if ((m['type'] as String?) == 'image' && m['content'] is String) {
            final p = (m['content'] as String).trim();
            if (!p.toLowerCase().startsWith('http://') &&
                !p.toLowerCase().startsWith('https://') &&
                p.isNotEmpty) {
              final url = await TemplatesService.adminUploadTemplateImageFile(p, dvToken: token);
              m['content'] = url;
              final seg = Uri.parse(url).pathSegments;
              if (previewImageId == null && seg.length >= 2 && seg[0] == 'template-images') {
                previewImageId = seg[1];
              }
            }
          }

          sanitized.add(m);
        }

        templateJson = {
          'templateId': templateId,
          'tiles': sanitized,
        };
      }

      await TemplatesService.adminCreateTemplate(
        dvToken: token,
        name: templateName,
        kind: kind,
        templateJson: templateJson,
        previewImageId: previewImageId,
      );

      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template published.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTemplate(String id) async {
    final token = await DvAuthService.getDvToken();
    if (token == null) throw Exception('Not authenticated.');
    setState(() => _loading = true);
    try {
      await TemplatesService.adminDeleteTemplate(id, dvToken: token);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncWizardDefaults({required bool reset}) async {
    if (!_isAdmin) return;
    if (_wizardSyncing) return;
    final token = await DvAuthService.getDvToken();
    if (token == null) throw Exception('Not authenticated.');

    setState(() => _wizardSyncing = true);
    try {
      // Start async job to avoid mobile/Render timeouts.
      final start = await TemplatesService.adminStartWizardSync(dvToken: token, reset: reset);
      final jobId = (start['jobId'] as String?)?.trim();
      if (jobId == null || jobId.isEmpty) throw Exception('Missing jobId from sync start.');
      debugPrint('Wizard sync started: jobId=$jobId reset=$reset startResponse=$start');
      if (!mounted) return;
      setState(() {
        _wizardSyncJobId = jobId;
        _wizardSyncStatusText = 'Started…';
        _wizardSyncLastLoggedFailed = 0;
      });

      // Poll status until finished.
      _wizardSyncPoll?.cancel();
      _wizardSyncPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final status = await TemplatesService.adminWizardSyncStatus(dvToken: token, jobId: jobId);
          final job = status['job'] as Map<String, dynamic>?;
          if (job == null) return;
          final running = (job['running'] as bool?) ?? false;
          final total = (job['total'] as num?)?.toInt() ?? 0;
          final succ = (job['succeeded'] as num?)?.toInt() ?? 0;
          final skip = (job['skipped'] as num?)?.toInt() ?? 0;
          final fail = (job['failed'] as num?)?.toInt() ?? 0;
          // Keep logs lightweight while polling.
          debugPrint('Wizard sync poll: jobId=$jobId running=$running ok=$succ skipped=$skip failed=$fail total=$total');
          final sampleErrors = job['sampleErrors'];
          if (fail > _wizardSyncLastLoggedFailed && sampleErrors != null) {
            _wizardSyncLastLoggedFailed = fail;
            debugPrint('Wizard sync sampleErrors (jobId=$jobId): $sampleErrors');
          }
          if (!mounted) return;
          setState(() {
            _wizardSyncStatusText = running
                ? 'Running: $succ ok • $skip skipped • $fail failed • $total total'
                : 'Done: $succ ok • $skip skipped • $fail failed • $total total';
          });
          if (!running) {
            _wizardSyncPoll?.cancel();
            if (!mounted) return;
            final resetEcho = (job['reset'] as bool?) ?? reset;
            if (fail > 0) {
              debugPrint('Wizard sync finished with failures: jobId=$jobId sampleErrors=$sampleErrors fullJob=$job');
            } else {
              debugPrint('Wizard sync finished: jobId=$jobId fullJob=$job');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  resetEcho
                      ? 'Wizard sync finished (reset). ok=$succ, skipped=$skip, failed=$fail'
                      : 'Wizard sync finished. ok=$succ, skipped=$skip, failed=$fail',
                ),
              ),
            );
            setState(() => _wizardSyncing = false);
          }
        } catch (e) {
          // Ignore intermittent errors while polling, but log for debugging.
          debugPrint('Wizard sync poll error: jobId=$jobId error=$e');
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Wizard sync failed (start): reset=$reset error=$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wizard sync failed: ${e.toString()}')),
      );
    } finally {
      // Don't clear _wizardSyncing here; polling will end it.
      if (mounted && _wizardSyncPoll == null) setState(() => _wizardSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Templates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Backend account'),
                      subtitle: Text(
                        (_canvaUserId ?? '').trim().isEmpty
                            ? 'Not connected'
                            : 'Connected as ${_canvaUserId!}',
                      ),
                      trailing: FilledButton(
                        onPressed: _loading ? null : _connectCanvaOAuth,
                        child: const Text('Connect Canva'),
                      ),
                    ),
                  ),
                  if (!_isAdmin)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Admin access required'),
                        subtitle: Text(
                          _isLocalBackend
                              ? 'Local backend detected. To enable admin actions locally, set DV_ALLOW_DEV_ADMIN=true on the backend.'
                              : 'Ask an admin to add your user id to DV_ADMIN_USER_IDS.',
                        ),
                      ),
                    ),
                  if ((_error ?? '').trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (_isAdmin && !_loading) ? _publishFromExistingBoard : null,
                    icon: const Icon(Icons.publish_outlined),
                    label: const Text('Publish from existing board'),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sync_outlined),
                      title: const Text('Sync wizard defaults + recommendations'),
                      subtitle: Text(
                        (_wizardSyncing && (_wizardSyncStatusText ?? '').isNotEmpty)
                            ? _wizardSyncStatusText!
                            : 'Seeds 3 goals per default category using Gemini.',
                      ),
                      trailing: _wizardSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PopupMenuButton<String>(
                              enabled: (_isAdmin || _isLocalBackend) && !_loading,
                              onSelected: (v) async {
                                if (v == 'seed') {
                                  await _syncWizardDefaults(reset: false);
                                } else if (v == 'reset') {
                                  final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Reset wizard recommendations?'),
                                          content: const Text(
                                            'This will regenerate recommendations for all default categories '
                                            'using Gemini. Continue?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(ctx).pop(true),
                                              child: const Text('Reset'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                  if (!ok) return;
                                  await _syncWizardDefaults(reset: true);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'seed', child: Text('Seed missing')),
                                PopupMenuItem(value: 'reset', child: Text('Reset + reseed')),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('Import from Canva (current page)'),
                      subtitle: const Text(
                        'Use the Canva “Digital Vision Board” panel to run import. '
                        'It will auto-crop layers and publish a template.',
                      ),
                      onTap: () async {
                        final base = DvAuthService.backendBaseUrl();
                        final msg = jsonEncode({
                          'steps': [
                            'Open Canva editor',
                            'Open Digital Vision Board panel',
                            'Connect to backend',
                            'Click “Import current page as template”',
                          ],
                          'backendBaseUrl': base,
                        });
                        if (!mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Import from Canva'),
                            content: SelectableText(msg),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Published templates', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_templates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No templates found.'),
                    ),
                  for (final t in _templates)
                    Card(
                      margin: const EdgeInsets.only(top: 10),
                      child: ListTile(
                        title: Text(t.name),
                        subtitle: Text(t.kind == 'grid' ? 'Grid' : 'Goal Canvas'),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _loading ? null : () => _deleteTemplate(t.id),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

