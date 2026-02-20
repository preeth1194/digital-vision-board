import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/board_template.dart';
import '../../utils/app_typography.dart';
import '../../models/core_value.dart';
import '../../models/grid_template.dart';
import '../../models/grid_tile_model.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/boards_storage_service.dart';
import '../../services/dv_auth_service.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/templates_service.dart';
import '../../services/vision_board_components_storage_service.dart';
import '../../widgets/dialogs/new_board_dialog.dart';
import '../goal_canvas_editor_screen.dart';
import '../grid_editor.dart';

class TemplateGalleryScreen extends StatefulWidget {
  const TemplateGalleryScreen({super.key});

  @override
  State<TemplateGalleryScreen> createState() => _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends State<TemplateGalleryScreen> {
  bool _loading = true;
  String? _error;
  List<BoardTemplateSummary> _templates = const [];

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
      final token = await DvAuthService.getDvToken();
      if (token == null) throw Exception('Not authenticated. Please continue as guest or log in.');
      final list = await TemplatesService.listTemplates(dvToken: token);
      if (!mounted) return;
      setState(() => _templates = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useTemplate(BoardTemplateSummary summary) async {
    final token = await DvAuthService.getDvToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated.')),
      );
      return;
    }

    final config = await showNewBoardDialog(context);
    if (!mounted) return;
    if (config == null || config.title.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tpl = await TemplatesService.getTemplate(summary.id, dvToken: token);
      final prefs = await SharedPreferences.getInstance();

      final boardId = 'board_${DateTime.now().millisecondsSinceEpoch}';
      final kind = tpl.kind;
      final core = CoreValues.byId(config.coreValueId);

      if (kind == 'goal_canvas') {
        final raw = tpl.templateJson['components'];
        final compsRaw =
            (raw is List) ? raw.whereType<Map<String, dynamic>>().toList() : const <Map<String, dynamic>>[];

        // Optional template canvas size (pixel space).
        final cs = tpl.templateJson['canvasSize'];
        // If missing (older templates), default to your standard Canva page size.
        final canvasW = ((cs is Map) ? (cs['w'] as num?)?.toDouble() : null) ?? 1080.0;
        final canvasH = ((cs is Map) ? (cs['h'] as num?)?.toDouble() : null) ?? 1920.0;

        final components = <VisionComponent>[];
        for (final c in compsRaw) {
          // Absolutize template-served images (Image.network expects http(s)).
          if (c['type'] == 'image' && c['imagePath'] is String) {
            final p = c['imagePath'] as String;
            if (p.startsWith('/')) {
              c['imagePath'] = TemplatesService.absolutizeMaybe(p);
            }
          }
          components.add(visionComponentFromJson(c));
        }

        final board = VisionBoardInfo(
          id: boardId,
          title: config.title,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          coreValueId: core.id,
          iconCodePoint: core.icon.codePoint,
          tileColorValue: core.tileColor.toARGB32(),
          layoutType: VisionBoardInfo.layoutGoalCanvas,
          templateId: null,
        );

        final boards = await BoardsStorageService.loadBoards(prefs: prefs);
        await BoardsStorageService.saveBoards([board, ...boards], prefs: prefs);
        await BoardsStorageService.setActiveBoardId(boardId, prefs: prefs);
        await VisionBoardComponentsStorageService.saveComponents(boardId, components, prefs: prefs);
        if (canvasW > 0 && canvasH > 0) {
          await prefs.setDouble(BoardsStorageService.boardCanvasWidthKey(boardId), canvasW);
          await prefs.setDouble(BoardsStorageService.boardCanvasHeightKey(boardId), canvasH);
        }

        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoalCanvasEditorScreen(boardId: boardId, title: board.title),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      if (kind == 'grid') {
        final templateId = tpl.templateJson['templateId'] as String?;
        final tilesRaw = tpl.templateJson['tiles'];
        final list = (tilesRaw is List)
            ? tilesRaw.whereType<Map<String, dynamic>>().toList()
            : const <Map<String, dynamic>>[];

        final tiles = <GridTileModel>[];
        for (final t in list) {
          if ((t['type'] as String?) == 'image' && t['content'] is String) {
            final p = t['content'] as String;
            if (p.startsWith('/')) t['content'] = TemplatesService.absolutizeMaybe(p);
          }
          tiles.add(GridTileModel.fromJson(t));
        }

        final board = VisionBoardInfo(
          id: boardId,
          title: config.title,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          coreValueId: core.id,
          iconCodePoint: core.icon.codePoint,
          tileColorValue: core.tileColor.toARGB32(),
          layoutType: VisionBoardInfo.layoutGrid,
          templateId: templateId,
        );

        final boards = await BoardsStorageService.loadBoards(prefs: prefs);
        await BoardsStorageService.saveBoards([board, ...boards], prefs: prefs);
        await BoardsStorageService.setActiveBoardId(boardId, prefs: prefs);

        // Persist tiles first so editor can load immediately.
        await GridTilesStorageService.saveTiles(boardId, tiles, prefs: prefs);

        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GridEditorScreen(
              boardId: boardId,
              title: board.title,
              initialIsEditing: true,
              template: GridTemplates.byId(templateId),
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      throw Exception('Unsupported template kind: $kind');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if ((_error ?? '').trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: AppTypography.body(context).copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  if (_templates.isEmpty && (_error ?? '').trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: Text('No templates yet.')),
                    ),
                  for (final t in _templates)
                    Card(
                      margin: const EdgeInsets.only(top: 10),
                      child: ListTile(
                        leading: (t.previewImageUrl ?? '').isEmpty
                            ? const Icon(Icons.auto_awesome_outlined)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  TemplatesService.absolutizeMaybe(t.previewImageUrl!),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                        title: Text(t.name),
                        subtitle: Text(t.kind == 'grid' ? 'Grid' : 'Goal Canvas'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _loading ? null : () => _useTemplate(t),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

