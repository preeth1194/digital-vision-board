import React, { useEffect } from "react";
import "./App.css";

function App() {
  useEffect(() => {
    // Smooth scroll for anchor links
    const handleAnchorClick = (e: MouseEvent) => {
      const target = e.target as HTMLAnchorElement;
      if (target.hash) {
        e.preventDefault();
        const element = document.querySelector(target.hash);
        if (element) {
          element.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      }
    };

    document.addEventListener("click", handleAnchorClick);
    return () => document.removeEventListener("click", handleAnchorClick);
  }, []);

  return (
    <div className="app">
      {/* Navigation */}
      <nav className="nav">
        <div className="nav-content">
          <a href="#home" className="nav-title">Digital Vision Board</a>
          <ul className="nav-links">
            <li><a href="#features">Features</a></li>
            <li><a href="#board-types">Board Types</a></li>
            <li><a href="/privacy-policy" target="_blank" rel="noopener noreferrer">Privacy Policy</a></li>
          </ul>
        </div>
      </nav>

      {/* Hero Section */}
      <section id="home" className="hero">
        <div className="hero-content">
          <h1>Transform Your Goals Into Reality</h1>
          <p>
            A gamified digital vision board app that helps you visualize your dreams,
            track your habits, and achieve your goals with style and motivation.
          </p>
          <a href="#features" className="cta-button">Explore Features</a>
        </div>
      </section>

      {/* Features Overview */}
      <section id="features" className="section">
        <h2 className="section-title">Powerful Features</h2>
        <p className="section-subtitle">
          Everything you need to visualize, track, and achieve your goals
        </p>
        <div className="features-grid">
          <div className="feature-card">
            <div className="feature-icon">📊</div>
            <h3>Habit Tracking</h3>
            <p>
              Track daily and weekly habits with flexible scheduling. Monitor streaks,
              set timers, and get location-based reminders. Add completion feedback
              to reflect on your progress.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">✅</div>
            <h3>Task Management</h3>
            <p>
              Break down goals into actionable checklist items. Set due dates,
              track daily completions, and add notes for each task. Optional CBT
              fields for deeper reflection.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">📱</div>
            <h3>Home Screen Widgets</h3>
            <p>
              Quick access to your habits from your home screen. Android and iOS
              widgets let you track progress and complete habits without opening
              the app.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🎵</div>
            <h3>Rhythmic Timer</h3>
            <p>
              Time-based and song-based timers for your habits. Integrate with
              Spotify or Apple Music to track workouts, meditation, or any activity
              by songs played.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🧩</div>
            <h3>Puzzle Game</h3>
            <p>
              Turn your goal images into interactive 4x4 puzzles. Solve puzzles
              to stay engaged with your goals. Puzzles automatically rotate every
              4 hours for variety.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">📈</div>
            <h3>Progress Insights</h3>
            <p>
              View activity summaries, streak tracking, and progress charts across
              all your boards. Get insights into your completion patterns and
              celebrate your wins.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🗺️</div>
            <h3>Location-Based Tracking</h3>
            <p>
              Automatically track habits when you enter specific locations using
              geofencing. Perfect for gym visits, work habits, or location-specific
              routines.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🎨</div>
            <h3>Multiple Board Types</h3>
            <p>
              Choose from four different board styles: Freeform, Goal Canvas,
              Physical Board (scan your own), or Grid Board for organized goal
              visualization.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🌙</div>
            <h3>Dark Mode</h3>
            <p>
              Full dark theme support with Material Design 3. Beautiful UI that
              adapts to your preference and reduces eye strain during late-night
              goal planning.
            </p>
          </div>
        </div>
      </section>

      {/* Board Types Section */}
      <section id="board-types" className="section">
        <h2 className="section-title">Four Ways to Visualize Your Goals</h2>
        <p className="section-subtitle">
          Choose the board style that matches your creative vision
        </p>
        <div className="board-types">
          <div className="board-type-card">
            <h3>Freeform Vision Board</h3>
            <p>A Canva-like editor for creative freedom</p>
            <ul>
              <li>Drag and drop elements</li>
              <li>Free positioning of goals</li>
              <li>Custom images and text</li>
              <li>Layer-based editing</li>
            </ul>
            <div className="image-placeholder">Freeform Board Preview</div>
          </div>
          <div className="board-type-card">
            <h3>Goal Canvas</h3>
            <p>Layer-based canvas with customizable backgrounds</p>
            <ul>
              <li>Multiple layers support</li>
              <li>Custom backgrounds</li>
              <li>Goal overlays</li>
              <li>Layer management UI</li>
            </ul>
            <div className="image-placeholder">Goal Canvas Preview</div>
          </div>
          <div className="board-type-card">
            <h3>Physical Board</h3>
            <p>Scan or import photos of your physical vision board</p>
            <ul>
              <li>Photo import from camera</li>
              <li>Edge detection scanning</li>
              <li>Digital goal overlays</li>
              <li>Interactive hotspots</li>
            </ul>
            <div className="image-placeholder">Physical Board Preview</div>
          </div>
          <div className="board-type-card">
            <h3>Grid Board</h3>
            <p>Structured tile layout for organized goal management</p>
            <ul>
              <li>Tile-based organization</li>
              <li>Grid layout</li>
              <li>Quick navigation</li>
              <li>Template support</li>
            </ul>
            <div className="image-placeholder">Grid Board Preview</div>
          </div>
        </div>
      </section>

      {/* Privacy Policy Section */}
      <section id="privacy" className="section">
        <h2 className="section-title">Privacy Policy</h2>
        <div className="privacy-policy">
          <h3>Your Privacy Matters</h3>
          <p>
            Digital Vision Board is committed to protecting your privacy. This policy
            explains how we collect, use, and safeguard your personal information.
          </p>

          <h4>Data Collection</h4>
          <p>
            Digital Vision Board is a local-first application. Most of your data is
            stored directly on your device:
          </p>
          <ul>
            <li>
              <strong>Goals, Habits, and Tasks:</strong> All goal definitions, habit
              tracking data, task checklists, and completion feedback are stored
              locally on your device.
            </li>
            <li>
              <strong>Vision Board Content:</strong> Images, board layouts, and
              customizations are stored on your device. Images may be downloaded
              from external sources (like Pexels) but are cached locally.
            </li>
            <li>
              <strong>Progress Data:</strong> Completion dates, streaks, activity
              summaries, and insights are calculated and stored locally.
            </li>
          </ul>

          <h4>Optional Data Collection</h4>
          <p>
            Some features require additional permissions and data collection:
          </p>
          <ul>
            <li>
              <strong>Location Data:</strong> If you enable location-based habit
              tracking (geofencing), the app will access your device location to
              trigger habits when you enter specified areas. Location data is used
              only for geofencing and is not stored permanently.
            </li>
            <li>
              <strong>Music Provider Integration:</strong> If you connect Spotify
              or Apple Music for rhythmic timer features, OAuth tokens are stored
              to enable song tracking. We do not collect your listening history or
              playlist data beyond what's necessary for song detection.
            </li>
            <li>
              <strong>Camera and Storage:</strong> To scan physical boards or import
              images, the app requests camera and storage permissions. Images are
              stored locally on your device.
            </li>
          </ul>

          <h4>Authentication</h4>
          <p>
            Digital Vision Board supports multiple authentication methods:
          </p>
          <ul>
            <li>
              <strong>Google Sign-In:</strong> If you choose to sign in with Google,
              your Google account information is used for authentication only. We
              do not access your Google account data beyond authentication.
            </li>
            <li>
              <strong>Phone Authentication:</strong> Phone number authentication
              is handled securely through Firebase Authentication.
            </li>
            <li>
              <strong>Guest Mode:</strong> You can use the app without creating an
              account. All data remains local to your device.
            </li>
          </ul>

          <h4>Local-First Storage</h4>
          <p>
            By default, all your data is stored locally on your device using
            platform-specific storage (SharedPreferences on Android/iOS). This means:
          </p>
          <ul>
            <li>Your data is private to your device</li>
            <li>No data is sent to external servers unless you explicitly enable cloud sync</li>
            <li>You have full control over your data</li>
          </ul>

          <h4>Optional Cloud Sync</h4>
          <p>
            If you choose to enable Firebase Cloud Sync (optional feature):
          </p>
          <ul>
            <li>
              Your data will be synchronized to Firebase servers
            </li>
            <li>
              Data is encrypted in transit and at rest
            </li>
            <li>
              You can disable cloud sync at any time
            </li>
            <li>
              Cloud sync requires Firebase configuration files (google-services.json
              for Android, GoogleService-Info.plist for iOS)
            </li>
          </ul>

          <h4>Third-Party Services</h4>
          <p>
            Digital Vision Board may integrate with the following third-party services:
          </p>
          <ul>
            <li>
              <strong>Spotify:</strong> OAuth integration for music provider features.
              Spotify's privacy policy applies to data collected through their service.
            </li>
            <li>
              <strong>Apple Music:</strong> Uses system APIs (iOS only) for track
              detection. No data is shared with Apple beyond standard API usage.
            </li>
            <li>
              <strong>Pexels:</strong> Image search functionality may query Pexels
              API for stock images. Search terms are sent to Pexels; no user data
              is shared.
            </li>
            <li>
              <strong>Firebase:</strong> Optional cloud storage and authentication.
              Firebase's privacy policy applies when cloud sync is enabled.
            </li>
          </ul>

          <h4>Permissions</h4>
          <p>
            Digital Vision Board requests the following permissions:
          </p>
          <ul>
            <li>
              <strong>Location:</strong> For geofencing-based habit tracking
              (ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION, ACCESS_BACKGROUND_LOCATION)
            </li>
            <li>
              <strong>Storage/Media:</strong> For importing images, scanning boards,
              and accessing media files (READ_EXTERNAL_STORAGE, READ_MEDIA_AUDIO)
            </li>
            <li>
              <strong>Notifications:</strong> For habit reminders and progress updates
              (POST_NOTIFICATIONS)
            </li>
            <li>
              <strong>Camera:</strong> For scanning physical boards and taking photos
            </li>
          </ul>
          <p>
            All permissions are optional and only requested when relevant features
            are used. You can deny any permission and still use core app features.
          </p>

          <h4>Data Security</h4>
          <p>
            We take data security seriously:
          </p>
          <ul>
            <li>
              Local data is stored using platform-secured storage mechanisms
            </li>
            <li>
              Cloud data (if enabled) is encrypted in transit using TLS and at rest
              using Firebase encryption
            </li>
            <li>
              OAuth tokens are stored securely using platform keychains
            </li>
            <li>
              No data is shared with third parties except as described in this policy
            </li>
          </ul>

          <h4>Your Rights</h4>
          <p>
            You have the right to:
          </p>
          <ul>
            <li>
              <strong>Access Your Data:</strong> All data is stored locally and
              accessible through the app. If cloud sync is enabled, you can access
              data through Firebase.
            </li>
            <li>
              <strong>Delete Your Data:</strong> You can delete individual goals,
              habits, tasks, or entire boards at any time through the app interface.
            </li>
            <li>
              <strong>Export Your Data:</strong> Data is stored in JSON format and
              can be accessed through device file managers (advanced users).
            </li>
            <li>
              <strong>Disable Permissions:</strong> You can revoke any permission
              through your device settings. Some features may be limited if permissions
              are disabled.
            </li>
            <li>
              <strong>Delete Your Account:</strong> If you created an account, you
              can delete it through the app settings or by contacting support.
            </li>
          </ul>

          <h4>Children's Privacy</h4>
          <p>
            Digital Vision Board is not intended for children under 13 years of age.
            We do not knowingly collect personal information from children under 13.
            If you are a parent or guardian and believe your child has provided us
            with personal information, please contact us to have that information
            removed.
          </p>

          <h4>Changes to This Policy</h4>
          <p>
            We may update this Privacy Policy from time to time. We will notify you
            of any changes by posting the new Privacy Policy on this page and updating
            the "Last updated" date. You are advised to review this Privacy Policy
            periodically for any changes.
          </p>

          <h4>Contact Us</h4>
          <p>
            If you have any questions about this Privacy Policy or our data practices,
            please contact us through the app settings or visit our support page.
          </p>

          <p style={{ marginTop: "2rem", fontSize: "0.9rem", color: "var(--on-surface-variant)" }}>
            <strong>Last Updated:</strong> January 2025
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="footer-content">
          <h3>Digital Vision Board</h3>
          <p>Transform your goals into reality</p>
          <p style={{ fontSize: "0.9rem", opacity: 0.8 }}>
            A gamified goal tracking app built with Flutter
          </p>
          <ul className="footer-links">
            <li><a href="#features">Features</a></li>
            <li><a href="#board-types">Board Types</a></li>
            <li><a href="/privacy-policy" target="_blank" rel="noopener noreferrer">Privacy Policy</a></li>
          </ul>
          <p style={{ marginTop: "2rem", fontSize: "0.85rem", opacity: 0.7 }}>
            © 2025 Digital Vision Board. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}

export { App };
