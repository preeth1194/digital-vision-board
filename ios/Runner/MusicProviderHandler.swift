import Flutter
import Foundation
import MediaPlayer
import AVFoundation

/// Handler for music provider integration (Spotify/Apple Music).
///
/// Uses MPMusicPlayerController for Apple Music and NowPlayingInfoCenter for Spotify detection.
class MusicProviderHandler: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "dvb/music_provider", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "dvb/music_provider_events", binaryMessenger: registrar.messenger())
        let instance = MusicProviderHandler()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    private var eventSink: FlutterEventSink?
    private var notificationObserver: NSObjectProtocol?
    private var nowPlayingObserver: NSObjectProtocol?
    private var pollingTimer: Timer?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSpotifyAvailable":
            // Check if Spotify app is installed
            let spotifyInstalled = UIApplication.shared.canOpenURL(URL(string: "spotify:")!)
            result(spotifyInstalled)
        case "isAppleMusicAvailable":
            // Check Apple Music authorization
            let status = MPMediaLibrary.authorizationStatus()
            result(status == .authorized)
        case "requestAppleMusicPermission":
            requestAppleMusicPermission(result: result)
        case "authenticateSpotify":
            authenticateSpotify(result: result)
        case "getCurrentTrack":
            getCurrentTrack(result: result)
        case "startListening":
            startListening(result: result)
        case "stopListening":
            stopListening(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestAppleMusicPermission(result: @escaping FlutterResult) {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                result(status == .authorized)
            }
        }
    }

    private func authenticateSpotify(result: @escaping FlutterResult) {
        // For NowPlayingInfoCenter approach, no authentication needed
        // Spotify tracks are detected via system NowPlayingInfoCenter
        // If using Spotify SDK for control, implement OAuth here
        result(true)
    }

    private func getCurrentTrack(result: @escaping FlutterResult) {
        // Try Apple Music first
        let player = MPMusicPlayerController.systemMusicPlayer
        if let nowPlaying = player.nowPlayingItem {
            let title = nowPlaying.title ?? "Unknown"
            let artist = nowPlaying.artist
            result([
                "title": title,
                "artist": artist ?? NSNull(),
                "album": nowPlaying.albumTitle ?? NSNull(),
                "trackId": nowPlaying.persistentID.description,
            ])
            return
        }
        
        // Fallback to NowPlayingInfoCenter (works with Spotify and other apps)
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            let title = nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "Unknown"
            let artist = nowPlayingInfo[MPMediaItemPropertyArtist] as? String
            let album = nowPlayingInfo[MPMediaItemPropertyAlbumTitle] as? String
            let trackId = nowPlayingInfo[MPMediaItemPropertyPersistentID] as? NSNumber
            
            result([
                "title": title,
                "artist": artist ?? NSNull(),
                "album": album ?? NSNull(),
                "trackId": trackId?.stringValue ?? title,
            ])
            return
        }
        
        result(nil)
    }

    private func startListening(result: @escaping FlutterResult) {
        // Set up MPMusicPlayerController notifications for Apple Music
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: MPMusicPlayerController.systemMusicPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.handleNowPlayingItemChanged()
        }
        MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()
        
        // Set up polling for NowPlayingInfoCenter (Spotify and other apps)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkNowPlayingInfo()
        }
        
        // Get initial track
        DispatchQueue.main.async { [weak self] in
            self?.handleNowPlayingItemChanged()
        }
        
        result(true)
    }

    private func stopListening(result: @escaping FlutterResult) {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
        result(true)
    }

    @objc private func handleNowPlayingItemChanged() {
        checkNowPlayingInfo()
    }
    
    private var lastTrackId: String?
    
    private func checkNowPlayingInfo() {
        // Try Apple Music first
        let player = MPMusicPlayerController.systemMusicPlayer
        if let nowPlaying = player.nowPlayingItem {
            let trackId = nowPlaying.persistentID.description
            if trackId != lastTrackId {
                lastTrackId = trackId
                let trackInfo: [String: Any] = [
                    "title": nowPlaying.title ?? "Unknown",
                    "artist": nowPlaying.artist ?? NSNull(),
                    "album": nowPlaying.albumTitle ?? NSNull(),
                    "trackId": trackId
                ]
                eventSink?.success(trackInfo)
            }
            return
        }
        
        // Fallback to NowPlayingInfoCenter (Spotify)
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            let title = nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "Unknown"
            let artist = nowPlayingInfo[MPMediaItemPropertyArtist] as? String
            let album = nowPlayingInfo[MPMediaItemPropertyAlbumTitle] as? String
            let trackId = (nowPlayingInfo[MPMediaItemPropertyPersistentID] as? NSNumber)?.stringValue ?? title
            
            if trackId != lastTrackId {
                lastTrackId = trackId
                let trackInfo: [String: Any] = [
                    "title": title,
                    "artist": artist ?? NSNull(),
                    "album": album ?? NSNull(),
                    "trackId": trackId
                ]
                eventSink?.success(trackInfo)
            }
        }
    }
}

// MARK: - FlutterStreamHandler
extension MusicProviderHandler: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
}
