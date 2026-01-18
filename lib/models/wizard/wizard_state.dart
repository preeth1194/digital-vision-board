import '../core_value.dart';
import 'wizard_goal.dart';

final class WizardCoreValueSelection {
  final String coreValueId;
  /// Category labels for this core value (predefined + user-added).
  final List<String> categories;

  const WizardCoreValueSelection({
    required this.coreValueId,
    required this.categories,
  });

  WizardCoreValueSelection copyWith({
    String? coreValueId,
    List<String>? categories,
  }) {
    return WizardCoreValueSelection(
      coreValueId: coreValueId ?? this.coreValueId,
      categories: categories ?? this.categories,
    );
  }
}

final class CreateBoardWizardState {
  final String boardName;
  final String majorCoreValueId;
  /// All selected core values including the major one.
  final List<WizardCoreValueSelection> coreValues;
  final List<WizardGoalDraft> goals;

  const CreateBoardWizardState({
    required this.boardName,
    required this.majorCoreValueId,
    required this.coreValues,
    required this.goals,
  });

  factory CreateBoardWizardState.initial() => CreateBoardWizardState(
        boardName: '',
        majorCoreValueId: CoreValues.growthMindset,
        coreValues: const [
          WizardCoreValueSelection(
            coreValueId: CoreValues.growthMindset,
            categories: <String>[],
          ),
        ],
        goals: const [],
      );

  CreateBoardWizardState copyWith({
    String? boardName,
    String? majorCoreValueId,
    List<WizardCoreValueSelection>? coreValues,
    List<WizardGoalDraft>? goals,
  }) {
    return CreateBoardWizardState(
      boardName: boardName ?? this.boardName,
      majorCoreValueId: majorCoreValueId ?? this.majorCoreValueId,
      coreValues: coreValues ?? this.coreValues,
      goals: goals ?? this.goals,
    );
  }

  WizardCoreValueSelection? selectionFor(String coreValueId) {
    return coreValues.cast<WizardCoreValueSelection?>().firstWhere(
          (c) => c?.coreValueId == coreValueId,
          orElse: () => null,
        );
  }

  List<String> categoriesFor(String coreValueId) {
    final sel = selectionFor(coreValueId);
    if (sel == null) return const [];
    return sel.categories;
  }

  bool get step1Valid {
    if (boardName.trim().isEmpty) return false;
    if (CoreValues.byId(majorCoreValueId).id != majorCoreValueId) return false;
    // Ensure major is included.
    final ids = coreValues.map((c) => c.coreValueId).toSet();
    if (!ids.contains(majorCoreValueId)) return false;
    if (coreValues.isEmpty) return false;
    return true;
  }
}

