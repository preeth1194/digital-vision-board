import 'package:flutter/material.dart';

import '../../models/wizard/wizard_state.dart';
import 'wizard_step1_board_setup.dart';
import 'wizard_step_goals_for_core_value.dart';
import 'wizard_step3_generate_grid_preview.dart';
import 'wizard_step4_customize_grid.dart';

/// Wizard shell that hosts the multi-step create-board flow.
///
/// This is intentionally additive (new route) so existing flows keep working.
class CreateBoardWizardScreen extends StatefulWidget {
  const CreateBoardWizardScreen({super.key});

  @override
  State<CreateBoardWizardScreen> createState() => _CreateBoardWizardScreenState();
}

class _CreateBoardWizardScreenState extends State<CreateBoardWizardScreen> {
  int _stepIndex = 0;
  CreateBoardWizardState _state = CreateBoardWizardState.initial();
  int _coreValueGoalsIndex = 0;

  int get _totalSteps => 5; // step1 + goals + preview + customize + done (goals step expands internally)

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

  void _nextFromStep1(CreateBoardWizardState next) {
    setState(() {
      _state = next;
      _stepIndex = 1;
      _coreValueGoalsIndex = 0;
    });
    _showCongratsSnack(message: 'Nice! Your board has a clear focus.');
  }

  void _nextGoalsStep(CreateBoardWizardState next) {
    final total = _state.coreValues.length.clamp(1, 9999);
    final nextIndex = (_coreValueGoalsIndex + 1).clamp(0, total);
    if (nextIndex >= total) {
      // Step 3 preview (next)
      setState(() {
        _state = next;
        _stepIndex = 2;
      });
      _showCongratsSnack(message: 'Amazing — your goals are taking shape.');
      return;
    }
    setState(() {
      _state = next;
      _stepIndex = 1;
      _coreValueGoalsIndex = nextIndex;
    });
    _showCongratsSnack(message: 'Great progress!');
  }

  void _nextFromPreview() {
    setState(() => _stepIndex = 3);
    _showCongratsSnack(message: 'Awesome — now add images to bring it to life.');
  }

  @override
  Widget build(BuildContext context) {
    final progress = ((_stepIndex + 1) / _totalSteps).clamp(0.0, 1.0);

    return Scaffold(
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
                  onNext: _nextFromStep1,
                ),
              1 => WizardStepGoalsForCoreValue(
                  state: _state,
                  coreValueIndex: _coreValueGoalsIndex,
                  onNext: _nextGoalsStep,
                ),
              2 => WizardStep3GenerateGridPreview(
                  state: _state,
                  onBack: () => setState(() => _stepIndex = 1),
                  onNext: _nextFromPreview,
                ),
              3 => WizardStep4CustomizeGrid(
                  state: _state,
                  onBack: () => setState(() => _stepIndex = 2),
                  onCreated: () {
                    setState(() => _stepIndex = 4);
                    _showCongratsSnack(message: 'Boom — your vision board is ready!');
                  },
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

