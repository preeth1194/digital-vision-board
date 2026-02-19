import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/grid_template.dart';
import '../../services/wizard_board_builder.dart';
import '../grid_editor.dart';

/// Immediately creates a board with a default template and opens the grid editor.
class CreateBoardWizardScreen extends StatefulWidget {
  const CreateBoardWizardScreen({super.key});

  @override
  State<CreateBoardWizardScreen> createState() => _CreateBoardWizardScreenState();
}

class _CreateBoardWizardScreenState extends State<CreateBoardWizardScreen> {
  bool _launched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_launched) {
      _launched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _createAndOpen());
    }
  }

  Future<void> _createAndOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final createdId = 'board_${DateTime.now().millisecondsSinceEpoch}';
      final result = WizardBoardBuilderService.buildEmpty(boardId: createdId);
      await WizardBoardBuilderService.persist(result: result, prefs: prefs);
      if (!mounted) return;
      final template = GridTemplates.byId(result.board.templateId);
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => GridEditorScreen(
            boardId: createdId,
            title: result.board.title,
            initialIsEditing: true,
            template: template,
            isNewBoard: true,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(done == true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create board: ${e.toString()}')),
      );
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
