import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

  bool _spotifyAvailable = false;
  bool _spotifyAuthenticated = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    _spotifyAvailable = await _spotifyProvider.isAvailable();

    if (_spotifyAvailable) {
      _spotifyAuthenticated = await _checkSpotifyConnection();
    }

    setState(() => _loading = false);
  }

  Future<bool> _checkSpotifyConnection() async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) return false;

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

      final returnTo = 'dvb://spotify-oauth';
      final authUrl = Uri.parse('${DvAuthService.backendBaseUrl()}/auth/spotify/start')
          .replace(queryParameters: {
        'returnTo': returnTo,
        'origin': 'dvb',
        'dvToken': dvToken,
      });

      final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not open Spotify OAuth URL');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete Spotify connection in the browser, then return to the app. Pull down to refresh connection status.'),
            duration: Duration(seconds: 6),
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 2));
      
      final isConnected = await _checkSpotifyConnection();
      setState(() {
        _spotifyAuthenticated = isConnected;
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

  Future<void> _disconnectSpotify() async {
    setState(() {
      _spotifyAuthenticated = false;
    });
    await _savePreference(null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spotify disconnected'),
        ),
      );
    }
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
        appBar: AppBar(title: const Text('Spotify Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Settings'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Spotify Connection',
                style: AppTypography.heading2(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your Spotify account to use song-based rhythmic timers',
                style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.music_note, color: Colors.green, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spotify',
                                  style: AppTypography.body(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (!_spotifyAvailable)
                                  Text(
                                    'Spotify app not installed',
                                    style: AppTypography.caption(context).copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                else if (!_spotifyAuthenticated)
                                  Text(
                                    'Not connected',
                                    style: AppTypography.caption(context).copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Connected',
                                        style: AppTypography.caption(context).copyWith(
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _spotifyAuthenticated
                            ? OutlinedButton(
                                onPressed: _disconnectSpotify,
                                child: const Text('Disconnect'),
                              )
                            : FilledButton.icon(
                                onPressed: _spotifyAvailable ? _authenticateSpotify : null,
                                icon: const Icon(Icons.link),
                                label: const Text('Connect Spotify'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Card(
                color: colorScheme.surfaceContainerHighest,
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
                        'When you create a habit with a song-based timer, the app will track songs from Spotify. Each song that plays counts toward your goal.',
                        style: AppTypography.bodySmall(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The app can detect currently playing songs automatically when the Spotify app is installed. To access your playlists and search for songs, connect your Spotify account above.',
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
