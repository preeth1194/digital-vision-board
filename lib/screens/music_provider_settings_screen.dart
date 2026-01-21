import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/music_provider_service.dart';
import '../services/dv_auth_service.dart';
import '../utils/app_typography.dart';
import 'local_file_selection_screen.dart';

class MusicProviderSettingsScreen extends StatefulWidget {
  const MusicProviderSettingsScreen({super.key});

  @override
  State<MusicProviderSettingsScreen> createState() => _MusicProviderSettingsScreenState();
}

class _MusicProviderSettingsScreenState extends State<MusicProviderSettingsScreen> {
  final SpotifyProvider _spotifyProvider = SpotifyProvider();
  final AppleMusicProvider _appleMusicProvider = AppleMusicProvider();
  final YouTubeMusicProvider _youtubeMusicProvider = YouTubeMusicProvider();
  final LocalFileProvider _localFileProvider = LocalFileProvider();

  bool _spotifyAvailable = false;
  bool _spotifyAuthenticated = false;
  bool _appleMusicAvailable = false;
  bool _appleMusicHasPermission = false;
  bool _youtubeMusicAvailable = false;
  bool _youtubeMusicAuthenticated = false;
  bool _localFilesAvailable = false;
  bool _loading = true;

  String? _selectedProvider; // 'spotify' | 'apple_music' | 'youtube_music' | 'local_files' | 'fallback'

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
    _youtubeMusicAvailable = await _youtubeMusicProvider.isAvailable();
    _localFilesAvailable = await _localFileProvider.isAvailable();

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    _selectedProvider = prefs.getString('music_provider_preference');

    // Check authentication status
    // For Spotify: Check if OAuth tokens are stored (needed for playlists/search)
    // System APIs can detect playing songs without OAuth, but playlists require OAuth
    if (_spotifyAvailable) {
      _spotifyAuthenticated = await _checkSpotifyConnection();
    }
    if (_appleMusicAvailable) {
      _appleMusicHasPermission = _appleMusicProvider.hasPermission;
    }
    if (_youtubeMusicAvailable) {
      _youtubeMusicAuthenticated = await _checkYouTubeMusicConnection();
    }

    setState(() => _loading = false);
  }

  /// Check if Spotify is actually connected via OAuth by making a test API call
  Future<bool> _checkSpotifyConnection() async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) return false;

      // Try to fetch playlists with limit=1 to test connection
      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/spotify/playlists')
          .replace(queryParameters: {
        'limit': '1',
        'offset': '0',
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      // 200-299 means connected, 401 means not connected
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Check if YouTube Music is actually connected via OAuth by making a test API call
  Future<bool> _checkYouTubeMusicConnection() async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) return false;

      // Try to fetch playlists with limit=1 to test connection
      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/youtube-music/playlists')
          .replace(queryParameters: {
        'limit': '1',
        'offset': '0',
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      // 200-299 means connected, 401 means not connected
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
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
            content: Text('Complete Spotify connection in the browser, then return to the app. Pull down to refresh connection status.'),
            duration: Duration(seconds: 6),
          ),
        );
      }

      // Wait a moment for OAuth to complete, then check connection status
      await Future.delayed(const Duration(seconds: 2));
      
      // Verify the connection was successful
      final isConnected = await _checkSpotifyConnection();
      setState(() {
        _spotifyAuthenticated = isConnected;
        if (isConnected) {
          _selectedProvider = 'spotify';
        }
      });
      
      if (isConnected) {
        await _savePreference('spotify');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spotify connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spotify connection not detected. Please complete the OAuth flow in the browser and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
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

  Future<void> _authenticateYouTubeMusic() async {
    setState(() => _loading = true);
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in first to connect YouTube Music'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }

      // Build OAuth URL with returnTo deep link
      final returnTo = 'dvb://youtube-music-oauth';
      final authUrl = Uri.parse('${DvAuthService.backendBaseUrl()}/auth/youtube-music/start')
          .replace(queryParameters: {
        'returnTo': returnTo,
        'origin': 'dvb',
        'dvToken': dvToken,
      });

      // Launch OAuth URL
      final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not open YouTube Music OAuth URL');
      }

      // Show message that user should complete OAuth in browser
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete YouTube Music connection in the browser, then return to the app. Pull down to refresh connection status.'),
            duration: Duration(seconds: 6),
          ),
        );
      }

      // Wait a moment for OAuth to complete, then check connection status
      await Future.delayed(const Duration(seconds: 2));
      
      // Verify the connection was successful
      final isConnected = await _checkYouTubeMusicConnection();
      setState(() {
        _youtubeMusicAuthenticated = isConnected;
        if (isConnected) {
          _selectedProvider = 'youtube_music';
        }
      });
      
      if (isConnected) {
        await _savePreference('youtube_music');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('YouTube Music connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('YouTube Music connection not detected. Please complete the OAuth flow in the browser and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting YouTube Music: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectLocalFiles() async {
    // Navigate to local file selection screen
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const LocalFileSelectionScreen(),
      ),
    );

    if (result != null && result['selected'] == true) {
      setState(() {
        _selectedProvider = 'local_files';
        _localFilesAvailable = true;
      });
      await _savePreference('local_files');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local files selected'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadSettings();
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

    if (provider == 'youtube_music' && !_youtubeMusicAuthenticated) {
      await _authenticateYouTubeMusic();
      return;
    }

    if (provider == 'local_files') {
      await _selectLocalFiles();
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
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        child: SingleChildScrollView(
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
                            else if (!_spotifyAuthenticated)
                              Text(
                                'Tap to connect Spotify account',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.primary,
                                ),
                              )
                            else
                              Text(
                                'Connected - can access playlists',
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
                      : !_spotifyAuthenticated
                          ? TextButton(
                              onPressed: _authenticateSpotify,
                              child: const Text('Connect'),
                            )
                          : const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),

            const SizedBox(height: 12),

            // YouTube Music Option
            Card(
              child: RadioListTile<String>(
                value: 'youtube_music',
                groupValue: _selectedProvider,
                onChanged: _youtubeMusicAvailable
                    ? (value) => _selectProvider(value)
                    : null,
                title: Row(
                  children: [
                    Icon(Icons.music_video, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YouTube Music',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                            if (!_youtubeMusicAvailable)
                              Text(
                                'YouTube Music app not installed',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            else if (!_youtubeMusicAuthenticated)
                              Text(
                                'Tap to connect YouTube Music account',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.primary,
                                ),
                              )
                            else
                              Text(
                                'Connected - can access playlists',
                                style: AppTypography.caption(context).copyWith(
                                  color: Colors.green,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
                  secondary: !_youtubeMusicAvailable
                      ? null
                      : !_youtubeMusicAuthenticated
                          ? TextButton(
                              onPressed: _authenticateYouTubeMusic,
                              child: const Text('Connect'),
                            )
                          : const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),

            const SizedBox(height: 12),

            // Local Files Option
            Card(
              child: RadioListTile<String>(
                value: 'local_files',
                groupValue: _selectedProvider,
                onChanged: (value) => _selectProvider(value),
                title: Row(
                  children: [
                    Icon(Icons.folder, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Files',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          FutureBuilder<int>(
                            future: _localFileProvider.getSelectedFiles().then((files) => files.length),
                            builder: (context, snapshot) {
                              final fileCount = snapshot.data ?? 0;
                              return Text(
                                fileCount > 0
                                    ? '$fileCount file(s) selected'
                                    : 'Tap to select audio files from device',
                                style: AppTypography.caption(context).copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                secondary: _localFilesAvailable
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
                      'Spotify: The app can detect currently playing songs automatically when the Spotify app is installed. However, to access your playlists and search for songs, you need to connect your Spotify account via OAuth.',
                      style: AppTypography.bodySmall(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'YouTube Music: The app can detect currently playing songs automatically when the YouTube Music app is installed. However, to access your playlists and search for songs, you need to connect your YouTube Music account via OAuth.',
                      style: AppTypography.bodySmall(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Local Files: Select audio files from your device storage. These files will be used for song-based timers.',
                      style: AppTypography.bodySmall(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
