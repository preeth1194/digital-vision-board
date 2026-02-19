import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wizard/wizard_state.dart';
import '../../services/wizard_board_builder.dart';
import 'wizard_step1_board_setup.dart';
import '../grid_editor.dart';
import '../../models/grid_template.dart';

/// Wizard shell that hosts the multi-step create-board flow.
///
/// Steps: 0 = combined setup + goals, 1 = grid editor, 2 = done.
class CreateBoardWizardScreen extends StatefulWidget {
  const CreateBoardWizardScreen({super.key});

  @override
  State<CreateBoardWizardScreen> createState() => _CreateBoardWizardScreenState();
}

class _CreateBoardWizardScreenState extends State<CreateBoardWizardScreen> {
  int _stepIndex = 0;
  CreateBoardWizardState _state = CreateBoardWizardState.initial();
  bool _openingEditor = false;

  int get _totalSteps => 3;

  void _showCongratsSnack({required String message}) {
    final remaining = (_totalSteps - 1 - _stepIndex).clamp(0, _totalSteps);
    final text = remaining <= 0
        ? message
        : '$message  Only $remaining step${remaining == 1 ? '' : 's'} left.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: _AnimatedSnackText(text: text),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _nextFromCombinedStep(CreateBoardWizardState next) async {
    setState(() {
      _state = next;
      _stepIndex = 1;
    });
    _showCongratsSnack(message: 'Amazing — your goals are taking shape.');
    await _createAndOpenEditorFor(next);
  }

  Future<void> _createAndOpenEditorFor(CreateBoardWizardState next) async {
    if (_openingEditor) return;
    setState(() => _openingEditor = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final createdId = 'board_${DateTime.now().millisecondsSinceEpoch}';
      final result = WizardBoardBuilderService.build(boardId: createdId, state: next);
      await WizardBoardBuilderService.persist(result: result, prefs: prefs);
      if (!mounted) return;
      final template = GridTemplates.byId(result.board.templateId);
      final pressed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => GridEditorScreen(
            boardId: createdId,
            title: result.board.title,
            initialIsEditing: true,
            template: template,
            wizardShowNext: true,
            wizardNextLabel: 'Continue',
          ),
        ),
      );
      if (!mounted) return;
      if (pressed == true) {
        setState(() => _stepIndex = 2);
        _showCongratsSnack(message: 'Boom — your vision board is ready!');
      } else {
        setState(() => _stepIndex = 0);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open grid editor: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _openingEditor = false);
    }
  }

  void _handleBackNavigation() {
    if (_stepIndex == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      if (_stepIndex == 1) {
        _stepIndex = 0;
      } else if (_stepIndex == 2) {
        _stepIndex = 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ((_stepIndex + 1) / _totalSteps).clamp(0.0, 1.0);

    return PopScope(
      canPop: _stepIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _stepIndex > 0) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create your vision board'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('Step ${_stepIndex + 1} of $_totalSteps'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_stepIndex) {
                0 => WizardStep1BoardSetup(
                    initial: _state,
                    onNext: _nextFromCombinedStep,
                  ),
                1 => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_openingEditor) const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            _openingEditor ? 'Opening your grid editor…' : 'Opening editor…',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can change images, text, and layout inside the grid.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                _ => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.celebration_outlined, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'Congratulations!\nYou created your dream vision board.',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Back to dashboard'),
                        ),
                      ],
                    ),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedSnackText extends StatefulWidget {
  final String text;
  const _AnimatedSnackText({required this.text});

  @override
  State<_AnimatedSnackText> createState() => _AnimatedSnackTextState();
}

class _AnimatedSnackTextState extends State<_AnimatedSnackText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Text(widget.text),
      ),
    );
  }
}
