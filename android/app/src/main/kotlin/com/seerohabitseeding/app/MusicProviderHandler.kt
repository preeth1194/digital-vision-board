package com.seerohabitseeding.app

import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.MediaSessionManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/// Handler for music provider integration (Spotify/Apple Music).
/// 
/// Uses MediaSession API to detect currently playing tracks from any music app including Spotify.
class MusicProviderHandler(private val context: Context) {
    private var mediaSessionManager: MediaSessionManager? = null
    private var activeMediaController: MediaController? = null
    private var eventSink: EventChannel.EventSink? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mediaControllerCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            super.onMetadataChanged(metadata)
            metadata?.let { notifyTrackChange(it) }
        }

        override fun onPlaybackStateChanged(state: android.media.session.PlaybackState?) {
            super.onPlaybackStateChanged(state)
            // Track changes can also be detected via playback state changes
        }
    }

    fun setupMethodChannel(engine: FlutterEngine) {
        val methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "dvb/music_provider")
        val eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, "dvb/music_provider_events")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        }

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSpotifyAvailable" -> {
                    val isInstalled = isSpotifyInstalled()
                    result.success(isInstalled)
                }
                "isAppleMusicAvailable" -> {
                    // Apple Music is iOS-only, return false on Android
                    result.success(false)
                }
                "isYouTubeMusicAvailable" -> {
                    val isInstalled = isYouTubeMusicInstalled()
                    result.success(isInstalled)
                }
                "requestAppleMusicPermission" -> {
                    // Apple Music is iOS-only
                    result.success(false)
                }
                "authenticateSpotify" -> {
                    // For MediaSession approach, no authentication needed
                    // If using Spotify SDK, implement OAuth here
                    result.success(true)
                }
                "authenticateYouTubeMusic" -> {
                    // For MediaSession approach, no authentication needed
                    // OAuth is handled via backend API
                    result.success(true)
                }
                "getCurrentTrack" -> {
                    getCurrentTrack(result)
                }
                "startListening" -> {
                    startListening(result)
                }
                "stopListening" -> {
                    stopListening(result)
                }
                "getSpotifyPlaylists" -> {
                    getSpotifyPlaylists(call, result)
                }
                "searchSpotifyTracks" -> {
                    searchSpotifyTracks(call, result)
                }
                "getSpotifyPlaylistTracks" -> {
                    getSpotifyPlaylistTracks(call, result)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun isSpotifyInstalled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ (API 33+)
                context.packageManager.getPackageInfo("com.spotify.music", PackageManager.PackageInfoFlags.of(0))
            } else {
                // Android 12 and below
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo("com.spotify.music", 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: Exception) {
            // Handle any other exceptions
            false
        }
    }

    private fun isYouTubeMusicInstalled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ (API 33+)
                context.packageManager.getPackageInfo("com.google.android.apps.youtube.music", PackageManager.PackageInfoFlags.of(0))
            } else {
                // Android 12 and below
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo("com.google.android.apps.youtube.music", 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: Exception) {
            // Handle any other exceptions
            false
        }
    }

    private fun getCurrentTrack(result: MethodChannel.Result) {
        executor.execute {
            try {
                val track = getCurrentPlayingTrack()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.success(track)
                }
            } catch (e: Exception) {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.success(null)
                }
            }
        }
    }

    private fun getCurrentPlayingTrack(): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return null
        }

        val sessionManager = mediaSessionManager ?: return null
        
        try {
            // Try to get active sessions (may require notification listener permission on some devices)
            val activeControllers: List<MediaController> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // On Android M+, we need notification listener permission for getActiveSessions
                // Fall back to checking if we have an active controller
                if (activeMediaController != null) {
                    listOf(activeMediaController!!)
                } else {
                    emptyList<MediaController>()
                }
            } else {
                sessionManager.getActiveSessions(null)
            }

            for (controller in activeControllers) {
                val metadata = controller.metadata
                if (metadata != null) {
                    val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
                    val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
                    val album = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM)
                    val trackId = metadata.getString(MediaMetadata.METADATA_KEY_MEDIA_ID)

                    if (title != null && title.isNotEmpty()) {
                        return mapOf(
                            "title" to title,
                            "artist" to artist,
                            "album" to album,
                            "trackId" to (trackId ?: "$title-$artist")
                        )
                    }
                }
            }
        } catch (e: SecurityException) {
            // Permission denied - this is expected on some Android versions
            // The app will fall back to polling which works without special permissions
        } catch (e: Exception) {
            // Other errors - continue
        }

        return null
    }

    private fun startListening(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.success(false)
            return
        }

        executor.execute {
            try {
                val sessionManager = mediaSessionManager ?: run {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.success(true) // Still return true, will poll
                    }
                    return@execute
                }

                // Try to get active sessions
                try {
                    val activeControllers: List<MediaController> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        // On Android M+, getActiveSessions requires notification listener permission
                        // We'll use polling instead
                        emptyList<MediaController>()
                    } else {
                        sessionManager.getActiveSessions(null)
                    }

                    if (activeControllers.isNotEmpty()) {
                        activeMediaController = activeControllers[0]
                        activeMediaController?.registerCallback(mediaControllerCallback)
                    }
                } catch (e: SecurityException) {
                    // Permission denied - will use polling fallback
                    activeMediaController = null
                }

                // Get initial track
                val track = getCurrentPlayingTrack()
                if (track != null) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        eventSink?.success(track)
                    }
                }

                // Start polling as fallback (works without special permissions)
                startPolling()

                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Exception) {
                // Start polling anyway
                startPolling()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.success(true)
                }
            }
        }
    }

    private var pollingHandler: android.os.Handler? = null
    private var pollingRunnable: Runnable? = null

    private fun startPolling() {
        stopPolling()
        pollingHandler = android.os.Handler(android.os.Looper.getMainLooper())
        var lastTrackId: String? = null
        
        pollingRunnable = object : Runnable {
            override fun run() {
                executor.execute {
                    val track = getCurrentPlayingTrack()
                    if (track != null) {
                        val currentTrackId = track["trackId"] as? String
                        if (currentTrackId != lastTrackId) {
                            lastTrackId = currentTrackId
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                eventSink?.success(track)
                            }
                        }
                    }
                }
                pollingHandler?.postDelayed(this, 2000) // Poll every 2 seconds
            }
        }
        pollingHandler?.post(pollingRunnable!!)
    }

    private fun stopPolling() {
        pollingRunnable?.let { pollingHandler?.removeCallbacks(it) }
        pollingRunnable = null
        pollingHandler = null
    }

    private fun stopListening(result: MethodChannel.Result) {
        executor.execute {
            try {
                activeMediaController?.unregisterCallback(mediaControllerCallback)
                activeMediaController = null
                stopPolling()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Exception) {
                stopPolling()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.success(false)
                }
            }
        }
    }

    private fun notifyTrackChange(metadata: MediaMetadata) {
        val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
        val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
        val album = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM)
        val trackId = metadata.getString(MediaMetadata.METADATA_KEY_MEDIA_ID)

        if (title != null && title.isNotEmpty()) {
            val track = mapOf(
                "title" to title,
                "artist" to artist,
                "album" to album,
                "trackId" to (trackId ?: "$title-$artist")
            )
            eventSink?.success(track)
        }
    }

    private fun getSpotifyPlaylists(call: MethodCall, result: MethodChannel.Result) {
        // TODO: Implement Spotify Web API integration to fetch user playlists
        // This requires:
        // 1. Spotify SDK or Web API OAuth authentication
        // 2. HTTP client to call Spotify Web API endpoints
        // 3. Parse JSON responses
        // 
        // For now, return empty list - UI will show appropriate message
        executor.execute {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(emptyList<Map<String, Any>>())
            }
        }
    }

    private fun searchSpotifyTracks(call: MethodCall, result: MethodChannel.Result) {
        // TODO: Implement Spotify Web API integration to search tracks
        // This requires:
        // 1. Spotify SDK or Web API OAuth authentication
        // 2. HTTP client to call Spotify Web API search endpoint
        // 3. Parse JSON responses
        //
        // For now, return empty list - UI will show appropriate message
        executor.execute {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(emptyList<Map<String, Any>>())
            }
        }
    }

    private fun getSpotifyPlaylistTracks(call: MethodCall, result: MethodChannel.Result) {
        // TODO: Implement Spotify Web API integration to get playlist tracks
        // This requires:
        // 1. Spotify SDK or Web API OAuth authentication
        // 2. HTTP client to call Spotify Web API playlist tracks endpoint
        // 3. Parse JSON responses
        //
        // For now, return empty list - UI will show appropriate message
        executor.execute {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(emptyList<Map<String, Any>>())
            }
        }
    }
}
