import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/music_provider_service.dart';
import '../services/dv_auth_service.dart';
import '../utils/app_typography.dart';

class MusicProviderSettingsScreen extends StatefulWidget {
  const MusicProviderSettingsScreen({super.key});

  @override
  State<MusicProviderSettingsScreen> createState() => _MusicProviderSettingsScreenState();
}

class _MusicProviderSettingsScreenState extends State<MusicProviderSettingsScreen> {
  final SpotifyProvider _spotifyProvider = SpotifyProvider();
  final AppleMusicProvider _appleMusicProvider = AppleMusicProvider();

  bool _spotifyAvailable = false;
  bool _spotifyAuthenticated = false;
  bool _appleMusicAvailable = false;
  bool _appleMusicHasPermission = false;
  bool _loading = true;

  String? _selectedProvider; // 'spotify' | 'apple_music' | 'fallback'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    // Check availability
    _spotifyAvailable = await _spotifyProvider.isAvailable();
    _appleMusicAvailable = await _appleMusicProvider.isAvailable();

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    _selectedProvider = prefs.getString('music_provider_preference');

    // Check authentication status
    // With system API approach, Spotify is "authenticated" if app is installed
    if (_spotifyAvailable) {
      _spotifyAuthenticated = true; // Works via system APIs
    }
    if (_appleMusicAvailable) {
      _appleMusicHasPermission = _appleMusicProvider.hasPermission;
    }

    setState(() => _loading = false);
  }

  Future<void> _authenticateSpotify() async {
    setState(() => _loading = true);
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in first to connect Spotify'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }

      // Build OAuth URL with returnTo deep link
      final returnTo = 'dvb://spotify-oauth';
      final authUrl = Uri.parse('${DvAuthService.backendBaseUrl()}/auth/spotify/start')
          .replace(queryParameters: {
        'returnTo': returnTo,
        'origin': 'dvb',
        'dvToken': dvToken,
      });

      // Launch OAuth URL
      final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not open Spotify OAuth URL');
      }

      // Show message that user should complete OAuth in browser
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete Spotify connection in the browser, then return to the app'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // For now, mark as authenticated after a delay (in production, use deep link callback)
      // The actual connection will be verified when trying to use Spotify features
      setState(() {
        _spotifyAuthenticated = true;
        _selectedProvider = 'spotify';
      });
      await _savePreference('spotify');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting Spotify: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestAppleMusicPermission() async {
    setState(() => _loading = true);
    try {
      final success = await _appleMusicProvider.requestPermission();
      if (success) {
        setState(() {
          _appleMusicHasPermission = true;
          _selectedProvider = 'apple_music';
        });
        await _savePreference('apple_music');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apple Music permission granted')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apple Music permission denied. Please enable it in Settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectProvider(String? provider) async {
    if (provider == null) return;

    if (provider == 'spotify' && !_spotifyAuthenticated) {
      await _authenticateSpotify();
      return;
    }

    if (provider == 'apple_music' && !_appleMusicHasPermission) {
      await _requestAppleMusicPermission();
      return;
    }

    setState(() => _selectedProvider = provider);
    await _savePreference(provider);
  }

  Future<void> _savePreference(String? provider) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider != null) {
      await prefs.setString('music_provider_preference', provider);
    } else {
      await prefs.remove('music_provider_preference');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Music Provider Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Provider Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Music Provider',
              style: AppTypography.heading2(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred music service for song-based rhythmic timers',
              style: AppTypography.bodySmall(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Spotify Option
            Card(
              child: RadioListTile<String>(
                value: 'spotify',
                groupValue: _selectedProvider,
                onChanged: _spotifyAvailable
                    ? (value) => _selectProvider(value)
                    : null,
                title: Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spotify',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                            if (!_spotifyAvailable)
                              Text(
                                'Spotify app not installed',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            else
                              Text(
                                'Ready - tracks songs automatically',
                                style: AppTypography.caption(context).copyWith(
                                  color: Colors.green,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
                  secondary: !_spotifyAvailable
                      ? null
                      : _spotifyAvailable
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
              ),
            ),

            const SizedBox(height: 12),

            // Apple Music Option (iOS only)
            if (Platform.isIOS)
              Card(
                child: RadioListTile<String>(
                  value: 'apple_music',
                  groupValue: _selectedProvider,
                  onChanged: (_appleMusicAvailable && _appleMusicHasPermission) || !_appleMusicAvailable
                      ? (value) => _selectProvider(value)
                      : null,
                  title: Row(
                    children: [
                      Icon(Icons.music_note, color: Colors.pink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apple Music',
                              style: AppTypography.body(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_appleMusicAvailable)
                              Text(
                                'Not available',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            else if (!_appleMusicHasPermission)
                              Text(
                                'Tap to grant permission',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.primary,
                                ),
                              )
                            else
                              Text(
                                'Permission granted',
                                style: AppTypography.caption(context).copyWith(
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  secondary: !_appleMusicAvailable
                      ? null
                      : !_appleMusicHasPermission
                          ? TextButton(
                              onPressed: _requestAppleMusicPermission,
                              child: const Text('Grant Permission'),
                            )
                          : const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),

            const SizedBox(height: 12),

            // Fallback Option
            Card(
              child: RadioListTile<String>(
                value: 'fallback',
                groupValue: _selectedProvider,
                onChanged: (value) => _selectProvider(value),
                title: Row(
                  children: [
                    Icon(Icons.audiotrack, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Audio (Fallback)',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Use built-in audio files',
                            style: AppTypography.caption(context).copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Info Card
            Card(
              color: colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: AppTypography.heading3(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'When you create a habit with a song-based timer, the app will track songs from your selected music provider. Each song that plays counts toward your goal.',
                      style: AppTypography.bodySmall(context),
                    ),
                    const SizedBox(height: 8),
                    if (Platform.isIOS)
                      Text(
                        'Apple Music requires permission to access your music library. You can grant this permission when you select Apple Music.',
                        style: AppTypography.bodySmall(context),
                      ),
                    Text(
                      'Spotify works automatically when the Spotify app is installed. The app detects currently playing songs from Spotify using system APIs. No authentication required.',
                      style: AppTypography.bodySmall(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
