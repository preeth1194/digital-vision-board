# Digital Vision Board (Flutter)

A digital vision board app with **freeform canvas** and **grid** board templates, plus **habit tracking** and **insights**.

## Features

### Vision boards (Dashboard)
- **Create multiple boards** with a title, icon, tile color, and template:
  - **Freeform canvas**
  - **Grid layout**
- **Edit or view** a board from the dashboard
- **Delete boards** (also deletes that board’s stored data)

### Freeform canvas board
- **Edit / View modes**
  - Edit mode: build and arrange your board
  - View mode: browse board + open habit tracking for components
- **Background**
  - Set a **solid background color**
  - **Upload a background image** (native platforms)
  - **Clear background image**
- **Add content**
  - **Text components** with live preview + formatting controls
    - Font size, weight, alignment, and color
  - **Image components** from device gallery (native platforms)
- **Manipulate components**
  - Drag/move, resize (handles), rotate, scale
  - **Layer management**: reorder layers and update z-index
- **Legacy hotspot migration**
  - Converts older “hotspot” records into zone components when loading a board image

### Grid layout board
- **Staggered grid** layout
- **Add tiles**
  - Text tiles (create + edit)
  - Image tiles (pick + crop)
- **Resize mode** to adjust tile width/height (within constraints)
- **Delete tiles**
- Tiles are **stored and restored** per board

### Habits
- **Habits per component** (each zone/text/image component maintains its own habit list)
- **Habit Tracker bottom sheet**
  - Add/delete habits
  - Toggle completion for today
  - Calendar view (monthly markers)
  - “Last 7 days” bar chart
- **Habits tab**
  - If a board is selected: shows habits for that board
  - Otherwise: shows an aggregated “all boards habits” view

### Insights
- **Insights tab**
  - If a board is selected: insights for that board
  - Otherwise: overall insights across all boards
- Global insights include:
  - Today’s completion rate
  - Last 7 days activity chart
  - Summary stats (zones, habits, longest streak)

## Data & persistence
- Uses **SharedPreferences** to persist:
  - Board list + active board selection
  - Freeform components + background color
  - Background image path (native platforms)
  - Grid tiles per board

## Platform notes
- **Web**: image pick/crop flows are currently limited in this app (cropping + some file-path based flows are not supported).

