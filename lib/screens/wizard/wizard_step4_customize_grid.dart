import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/core_value.dart';
import '../../models/grid_template.dart';
import '../../models/grid_tile_model.dart';
import '../../models/wizard/wizard_state.dart';
import '../../services/wizard_board_builder.dart';
import '../../services/category_images_service.dart';
import '../../services/stock_images_service.dart';
import '../../models/core_value.dart';
import '../board/grid_editor.dart';

class WizardStep4CustomizeGrid extends StatefulWidget {
  final CreateBoardWizardState state;
  final VoidCallback onBack;
  final VoidCallback onCreated;

  const WizardStep4CustomizeGrid({
    super.key,
    required this.state,
    required this.onBack,
    required this.onCreated,
  });

  @override
  State<WizardStep4CustomizeGrid> createState() => _WizardStep4CustomizeGridState();
}

class _WizardStep4CustomizeGridState extends State<WizardStep4CustomizeGrid> {
  bool _creating = false;
  String? _boardId;
  String? _boardTitle;
  String? _templateId;
  bool _ackReviewed = false;

  @override
  void didUpdateWidget(covariant WizardStep4CustomizeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      // If earlier steps changed, discard any previously created board.
      _creating = false;
      _boardId = null;
      _boardTitle = null;
      _templateId = null;
      _ackReviewed = false;
    }
  }

  List<GridTileModel> _previewTiles() {
    final result = WizardBoardBuilderService.build(
      boardId: 'preview',
      state: widget.state,
    );
    return result.tiles;
  }

  Future<void> _createAndOpenEditor() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((_boardId ?? '').trim().isEmpty || (_boardTitle ?? '').trim().isEmpty) {
        final createdId = 'board_${DateTime.now().millisecondsSinceEpoch}';
        final result = WizardBoardBuilderService.build(boardId: createdId, state: widget.state);
        await WizardBoardBuilderService.persist(result: result, prefs: prefs);
        final createdTitle = result.board.title;
        final createdTemplateId = result.board.templateId;
        if (!mounted) return;
        setState(() {
          _boardId = createdId;
          _boardTitle = createdTitle;
          _templateId = createdTemplateId;
        });
      }

      // Prefill images for predefined categories (best effort).
      final boardIdPrefill = _boardId;
      if (boardIdPrefill != null && boardIdPrefill.trim().isNotEmpty) {
        try {
          final tiles = await GridTilesStorageService.loadTiles(boardIdPrefill, prefs: prefs);
          final needs = tiles.where((t) => t.type == 'image' && ((t.content ?? '').trim().isEmpty)).toList();
          if (needs.isNotEmpty) {
            final cats = needs
                .map((t) => (t.goal?.category ?? '').trim())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList();
            final coreValueId = widget.state.majorCoreValueId.trim();
            final coreLabel = CoreValues.byId(coreValueId).label;
            final byCat = <String, List<String>>{};
            for (final c in cats) {
              final urls = await CategoryImagesService.getCategoryImageUrls(
                coreValueId: coreValueId,
                category: c,
                limit: 10,
              );
              if (urls.isNotEmpty) {
                byCat[c] = urls;
              } else {
                // Fallback: hit Pexels directly with a more “minimalist vision board” query.
                final q = '$c $coreLabel minimal simple clean aesthetic';
                final pexels = await StockImagesService.searchPexelsUrls(query: q, perPage: 8);
                if (pexels.isNotEmpty) byCat[c] = pexels;
              }
            }

            if (byCat.isNotEmpty) {
              final idxByCat = <String, int>{for (final k in byCat.keys) k: 0};
              final updated = tiles.map((t) {
                if (t.type != 'image') return t;
                if ((t.content ?? '').trim().isNotEmpty) return t;
                final cat = (t.goal?.category ?? '').trim();
                final list = byCat[cat];
                if (list == null || list.isEmpty) return t;
                final i = idxByCat[cat] ?? 0;
                final url = list[i % list.length];
                idxByCat[cat] = i + 1;
                return t.copyWith(content: url);
              }).toList();
              await GridTilesStorageService.saveTiles(boardIdPrefill, updated, prefs: prefs);
            }
          }
        } catch (_) {
          // non-fatal
        }
      }

      if (!mounted) return;
      final boardId = _boardId;
      final boardTitle = _boardTitle;
      final templateId = _templateId;
      if (boardId == null || boardId.trim().isEmpty || boardTitle == null || boardTitle.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open editor (missing board info).')),
        );
        return;
      }

      final template = GridTemplates.byId(templateId);
      final nextPressed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => GridEditorScreen(
            boardId: boardId,
            title: boardTitle,
            initialIsEditing: true,
            template: template,
            wizardShowNext: true,
            wizardNextLabel: 'Continue',
          ),
        ),
      );
      if (!mounted) return;
      if (nextPressed == true) {
        widget.onCreated();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open grid editor: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final major = CoreValues.byId(widget.state.majorCoreValueId);
    final tiles = _previewTiles();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(major.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Customize your grid',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Add images to each tile, and adjust tile sizes if needed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _ackReviewed,
            onChanged: (v) => setState(() => _ackReviewed = v == true),
            contentPadding: EdgeInsets.zero,
            title: const Text('I reviewed this screen'),
            subtitle: const Text('Required to open the editor and continue.'),
          ),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StaggeredGrid.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final t in tiles)
                      StaggeredGridTile.count(
                        crossAxisCellCount: t.crossAxisCellCount,
                        mainAxisCellCount: t.mainAxisCellCount,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black12.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _creating ? null : widget.onBack,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_creating || tiles.isEmpty || !_ackReviewed) ? null : _createAndOpenEditor,
                child: Text(_creating ? 'Opening…' : 'Open grid editor'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

