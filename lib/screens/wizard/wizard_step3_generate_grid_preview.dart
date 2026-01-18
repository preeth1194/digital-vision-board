import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/core_value.dart';
import '../../models/grid_tile_model.dart';
import '../../models/wizard/wizard_state.dart';
import '../../services/wizard_board_builder.dart';

class WizardStep3GenerateGridPreview extends StatefulWidget {
  final CreateBoardWizardState state;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const WizardStep3GenerateGridPreview({
    super.key,
    required this.state,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<WizardStep3GenerateGridPreview> createState() => _WizardStep3GenerateGridPreviewState();
}

class _WizardStep3GenerateGridPreviewState extends State<WizardStep3GenerateGridPreview> {
  List<GridTileModel> _previewTiles() {
    final result = WizardBoardBuilderService.build(
      boardId: 'preview',
      state: widget.state,
    );
    return result.tiles;
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _previewTiles();
    final major = CoreValues.byId(widget.state.majorCoreValueId);

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
                  'Preview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'We grouped your goals by category. Next you’ll add images to each tile.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
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
                        child: _TilePreview(tile: t),
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
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: tiles.isEmpty ? null : widget.onNext,
                child: const Text('Next: Customize grid'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TilePreview extends StatelessWidget {
  final GridTileModel tile;
  const _TilePreview({required this.tile});

  @override
  Widget build(BuildContext context) {
    final title = (tile.goal?.title ?? '').trim();
    final category = (tile.goal?.category ?? '').trim();
    final cv = (tile.goal?.cbt?.coreValue ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black12.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cv.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Text(
                cv,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          if (category.isNotEmpty)
            Text(
              category,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            title.isEmpty ? tile.id : title,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

