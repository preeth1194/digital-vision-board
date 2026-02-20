import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/affirmation.dart';
import '../../screens/affirmation_management_screen.dart';
import '../../services/affirmation_service.dart';
import '../../utils/app_typography.dart';
import '../affirmation_card.dart';
import 'glass_card.dart';

class AffirmationSummaryCard extends StatefulWidget {
  const AffirmationSummaryCard({super.key});

  @override
  State<AffirmationSummaryCard> createState() =>
      _AffirmationSummaryCardState();
}

class _AffirmationSummaryCardState extends State<AffirmationSummaryCard>
    with WidgetsBindingObserver {
  List<Affirmation> _affirmations = [];
  int _currentIndex = 0;
  bool _loaded = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final all = await AffirmationService.getAllAffirmations(prefs: prefs);

    all.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    final savedIndex = prefs.getInt('dv_affirmation_rotation_all') ?? 0;
    final index =
        (savedIndex >= 0 && savedIndex < all.length) ? savedIndex : 0;

    if (mounted) {
      setState(() {
        _affirmations = all;
        _currentIndex = index;
        _loaded = true;
      });
    }
  }

  void _onFlip() {
    if (_affirmations.isEmpty) return;

    final current = _affirmations[_currentIndex];
    if (current.isPinned) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % _affirmations.length;
      _saveRotationState();
    });
  }

  void _saveRotationState() {
    _prefs?.setInt('dv_affirmation_rotation_all', _currentIndex);
  }

  Affirmation? get _currentAffirmation {
    if (_affirmations.isEmpty) return null;
    return _affirmations[_currentIndex];
  }

  Affirmation? get _nextAffirmation {
    if (_affirmations.isEmpty) return null;
    final current = _affirmations[_currentIndex];
    if (current.isPinned) return current;
    final nextIndex = (_currentIndex + 1) % _affirmations.length;
    return _affirmations[nextIndex];
  }

  void _openManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AffirmationManagementScreen(),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_loaded) {
      return SizedBox(
        height: 180,
        child: GlassCard(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_affirmations.isEmpty) {
      return GlassCard(
        onTap: _openManagement,
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Add your first affirmation',
                  style: AppTypography.body(context).copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _openManagement,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
    }

    return AffirmationCard(
      frontAffirmation: _currentAffirmation,
      backAffirmation: _nextAffirmation,
      onFlip: _onFlip,
      onSettings: _openManagement,
      cardColor: colorScheme.surface,
      showPinIndicator: true,
      showCategory: false,
      useGlass: true,
    );
  }
}
