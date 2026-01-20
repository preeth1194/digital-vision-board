# Spotify Integration - Complete Implementation

## Overview

Full Spotify integration has been implemented using system APIs that work without requiring the Spotify SDK or OAuth authentication. This approach:

- **Android**: Uses `MediaSessionManager` and `MediaController` to detect currently playing tracks
- **iOS**: Uses `MPNowPlayingInfoCenter` to detect currently playing tracks from any music app including Spotify

## How It Works

### Android Implementation

1. **MediaSession API**: Detects active media sessions from any music app
2. **Polling Fallback**: If direct session access requires permissions, falls back to polling
3. **Track Detection**: Automatically detects when tracks change and notifies Flutter

### iOS Implementation

1. **MPNowPlayingInfoCenter**: System API that provides currently playing track info
2. **MPMusicPlayerController**: For Apple Music specifically
3. **Real-time Updates**: Listens to system notifications for track changes

## Features

✅ **No Authentication Required**: Works automatically when Spotify app is installed  
✅ **Real-time Tracking**: Detects song changes as they happen  
✅ **Cross-platform**: Works on both Android and iOS  
✅ **Fallback Support**: Falls back to local audio if no music provider is active  
✅ **Event Channel**: Real-time updates via Flutter event channels  

## Setup

### Android

1. **Dependencies**: Already added to `build.gradle.kts`
   ```kotlin
   implementation("com.spotify.android:auth:2.0.2")
   ```

2. **Permissions**: No special permissions needed (uses system APIs)

3. **Manifest**: OAuth callback handler already configured (for future SDK use)

### iOS

1. **No SDK Required**: Uses system `MPNowPlayingInfoCenter` API

2. **Info.plist**: Already configured with Apple Music permission

## Usage

1. **Install Spotify App**: User needs Spotify app installed on their device

2. **Select Provider**: Go to Settings → Music Provider Settings → Select Spotify

3. **Start Timer**: When creating a habit with song-based timer, Spotify will automatically be used if selected

4. **Track Songs**: The app will automatically detect and count songs as they play

## Technical Details

### Method Channels

- **Method Channel**: `dvb/music_provider`
  - `isSpotifyAvailable`: Checks if Spotify app is installed
  - `authenticateSpotify`: Returns true (no auth needed with system APIs)
  - `getCurrentTrack`: Returns current playing track info
  - `startListening`: Starts listening for track changes
  - `stopListening`: Stops listening

- **Event Channel**: `dvb/music_provider_events`
  - Emits track information when songs change

### Track Information Format

```dart
{
  "title": "Song Title",
  "artist": "Artist Name",
  "album": "Album Name",
  "trackId": "unique-track-id"
}
```

## Limitations

1. **Read-Only**: Can only detect what's playing, cannot control playback
2. **Android Permissions**: On Android M+, direct session access may require notification listener permission (polling fallback works)
3. **Background**: Works best when app is in foreground (polling continues in background)

## Future Enhancements

If you want full Spotify SDK integration for playback control:

1. Register app at https://developer.spotify.com/dashboard
2. Get Client ID and configure OAuth
3. Add Spotify iOS SDK via CocoaPods
4. Implement authentication flow in native handlers
5. Use Spotify Remote SDK for playback control

The current implementation provides song tracking without requiring SDK setup, which is sufficient for the rhythmic timer feature.

## Testing

1. Install Spotify app on device
2. Play music in Spotify
3. Open app → Settings → Music Provider Settings
4. Select Spotify
5. Create a habit with song-based timer
6. Start the timer - it should detect songs as they play
