import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spotify_playlist.dart';
import '../services/music_provider_service.dart';

/// Screen for selecting Spotify playlists or songs for rhythmic timers
class SpotifySelectionScreen extends StatefulWidget {
  final String? selectedPlaylistId;
  final List<String>? selectedTrackIds;
  final bool allowMultipleTracks;

  const SpotifySelectionScreen({
    super.key,
    this.selectedPlaylistId,
    this.selectedTrackIds,
    this.allowMultipleTracks = true,
  });

  @override
  State<SpotifySelectionScreen> createState() => _SpotifySelectionScreenState();
}

class _SpotifySelectionScreenState extends State<SpotifySelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final SpotifyProvider _spotifyProvider = SpotifyProvider();

  List<SpotifyPlaylist> _playlists = [];
  List<SpotifyTrack> _searchResults = [];
  List<SpotifyTrack> _playlistTracks = [];
  bool _isLoadingPlaylists = false;
  bool _isSearching = false;
  bool _isLoadingTracks = false;
  String? _selectedPlaylistId;
  String? _selectedPlaylistName;
  Set<String> _selectedTrackIds = {};
  String? _viewingPlaylistId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedPlaylistId = widget.selectedPlaylistId;
    _selectedTrackIds = Set.from(widget.selectedTrackIds ?? []);
    _loadPlaylists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    if (!await _spotifyProvider.isAvailable()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spotify is not available. Please install Spotify app.'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoadingPlaylists = true);
    try {
      final playlists = await _spotifyProvider.getPlaylists(limit: 50);
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoadingPlaylists = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPlaylists = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load playlists: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _searchTracks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _spotifyProvider.searchTracks(query, limit: 30);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _loadPlaylistTracks(String playlistId) async {
    setState(() {
      _isLoadingTracks = true;
      _viewingPlaylistId = playlistId;
    });
    try {
      final tracks = await _spotifyProvider.getPlaylistTracks(playlistId, limit: 100);
      if (mounted) {
        setState(() {
          _playlistTracks = tracks;
          _isLoadingTracks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTracks = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load playlist tracks: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _toggleTrackSelection(String trackId) {
    setState(() {
      if (_selectedTrackIds.contains(trackId)) {
        _selectedTrackIds.remove(trackId);
      } else {
        if (widget.allowMultipleTracks) {
          _selectedTrackIds.add(trackId);
        } else {
          _selectedTrackIds = {trackId};
        }
      }
    });
  }

  void _selectPlaylist(String playlistId) {
    // Find playlist name
    final playlist = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => SpotifyPlaylist(id: playlistId, name: 'Playlist'),
    );
    setState(() {
      _selectedPlaylistId = playlistId;
      _selectedPlaylistName = playlist.name;
      _selectedTrackIds.clear(); // Clear individual track selection when playlist is selected
    });
  }

  void _confirmSelection() {
    Navigator.of(context).pop({
      'playlistId': _selectedPlaylistId,
      'playlistName': _selectedPlaylistName,
      'trackIds': _selectedTrackIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Music'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.playlist_play), text: 'Playlists'),
            Tab(icon: Icon(Icons.music_note), text: 'Songs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar (only shown in Songs tab)
          if (_tabController.index == 1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchTracks('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
                onChanged: (value) {
                  setState(() {});
                  _searchTracks(value);
                },
              ),
            ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlaylistsTab(),
                _buildSongsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedPlaylistId != null
                      ? 'Playlist selected'
                      : _selectedTrackIds.isEmpty
                          ? 'No selection'
                          : '${_selectedTrackIds.length} song${_selectedTrackIds.length == 1 ? '' : 's'} selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: (_selectedPlaylistId != null || _selectedTrackIds.isNotEmpty)
                    ? _confirmSelection
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    if (_isLoadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No playlists found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure Spotify is connected and you have playlists',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadPlaylists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          final isSelected = _selectedPlaylistId == playlist.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isSelected ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => _selectPlaylist(playlist.id),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Playlist artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: playlist.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: playlist.imageUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 64,
                                height: 64,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 64,
                                height: 64,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.playlist_play),
                              ),
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.playlist_play, size: 32),
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Playlist info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (playlist.ownerName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              playlist.ownerName!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          if (playlist.trackCount != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${playlist.trackCount} tracks',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Selection indicator
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _loadPlaylistTracks(playlist.id),
                        tooltip: 'View tracks',
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongsTab() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewingPlaylistId != null) {
      return _buildPlaylistTracksView();
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for songs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Enter a song name, artist, or album to find tracks',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        final isSelected = _selectedTrackIds.contains(track.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => _toggleTrackSelection(track.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Track artwork
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 56,
                              height: 56,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.music_note),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 56,
                              height: 56,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.music_note),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.music_note),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.displayTitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (track.displaySubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            track.displaySubtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Selection indicator
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistTracksView() {
    if (_isLoadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _viewingPlaylistId = null;
                    _playlistTracks = [];
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Select tracks from playlist',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        // Tracks list
        Expanded(
          child: _playlistTracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tracks in this playlist',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _playlistTracks.length,
                  itemBuilder: (context, index) {
                    final track = _playlistTracks[index];
                    final isSelected = _selectedTrackIds.contains(track.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: () => _toggleTrackSelection(track.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: track.imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: track.imageUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 56,
                                          height: 56,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(Icons.music_note),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 56,
                                          height: 56,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(Icons.music_note),
                                        ),
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.music_note),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.displayTitle,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (track.displaySubtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        track.displaySubtitle,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              else
                                Icon(
                                  Icons.radio_button_unchecked,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
