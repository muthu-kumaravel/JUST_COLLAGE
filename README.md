# Just Collage 📸

A minimal, open-source photo collage application built with **Flutter**, targeting **iOS**, **Android**, and **Web** from a single shared codebase and layout/rendering engine.

---

## 🔒 Core Privacy Model

Just Collage is strictly **local-first**:

* **No accounts or login**
* **No cloud storage or backend**
* **No image uploads or external network requests**
* **No tracking, telemetry, or analytics**
* **No advertising or monetization SDKs**
* **Zero photo duplication**: Photos are never copied permanently into an application-owned media library. Photos remain in temporary memory only for composition and export.

---

## ✨ Features

### 1. Three Core Layout Engines
* **Natural / Justified**:
  * Edge-to-edge partitioning preserving the natural aspect ratio of photos with minimal adaptation ($\le 12-14\%$).
  * Zero canvas bleed across all canvas ratios (Square, Wallpaper, 9:16, 4:5, etc.).
  * Deterministic multi-layout shuffle cycling through optimal geometric row/column variations.
  * Equal visual spacing (gutters) and margins.
* **Uniform Frames**:
  * "Best Fit" grid calculation touching all 4 canvas edges without blank space.
  * Frames have identical dimensions, aspect ratios, and clean grid alignment.
  * Orientation toggle (Portrait $\leftrightarrow$ Landscape) for uniform frame aspect ratios.
  * Aspect-fill placement with interactive pan & pinch-to-zoom crop adjustment.
* **Random / Scattered**:
  * Organic, editorial-style scattered collage.
  * Preserves aspect ratio for every photo without distortion.
  * Strict rotated bounding-box clamping ensuring zero bleed outside canvas edges.
  * Realistic pile scale hierarchy ($0.85\times - 1.35\times$) for hero vs supporting photos.

### 2. Apple Photos Studio UI & Canvas Controls
* **Apple Photos Design System**: Obsidian studio aesthetic (`#000000`), frosted glass chrome, gold `#FFD60A` accents, integrated inspector shelf, and bottom dock.
* **Desktop & Mobile Precision Sliders**: Non-blocking, smooth drag interaction with live numeric indicator badges.
* **Standard Canvas Ratios**: Square (1:1), Wallpaper (9:19.5), 9:16, 4:5, 5:7, 3:4, 3:5, 2:3, plus Auto.
* **Orientation Toggle**: Instant Portrait $\leftrightarrow$ Landscape switching for all aspect ratios.
* **Image Border System**: Border width slider ($0 - 32\text{px}$), color swatches, and custom border texture image upload rendered across all 3 layouts.
* **iPhone-Grade Crop Viewfinder**: Illuminated crop viewfinder with corner brackets, rule-of-thirds grid, 70% dark vignette surround, and zero-overflow layout.
* **Backgrounds**: Curated solid colors, gradients, and custom background photo with adjustable Gaussian blur.
* **Add & Remove Photos**: Dynamically add, reorder, or delete photos with live composition updates.

### 3. Dual-Resolution Rendering Pipeline
* **Responsive Preview**: Decodes downsampled images based on display size and device capabilities to maintain smooth 60fps/120fps UI and avoid memory spikes.
* **High-Resolution Export**: Decodes photos and border textures independently to optimal high-resolution tiles, composing a crisp ~4096px longest-edge collage rendered directly to JPEG (95 quality).
* **Export Options**:
  * **Save to Photos** (iOS / Android / macOS via native Photos library)
  * **Native Share Sheet** (`share_plus`)
  * **Web Download** (Native browser download)

---

## 🏗 Architecture

```text
Apple Photos UI (Obsidian Studio, Frosted Glass, Gold Accents)
    ↓
Collage State / Settings (CollageSettings, PhotoAsset, CanvasAspectRatio, BorderSettings)
    ↓
Shared Layout Engine (NaturalLayoutEngine, UniformLayoutEngine, ScatteredLayoutEngine)
    ↓
Deterministic Layout Result (LayoutResult, CollageItemPlacement)
    ↓
Rendering Pipeline
    ├── Preview Renderer (CollagePainter, downsampled ui.Image, border shaders)
    └── Export Renderer (ExportRenderer, high-res tile decoding to JPEG)
    ↓
Platform Output (Gal, SharePlus, Web download)
```

### Directory Structure

```
lib/
├── main.dart                          # App entry point, obsidian theme & gold accents
├── models/
│   ├── photo_asset.dart               # In-memory photo model with preview decoding
│   ├── collage_settings.dart          # Mode, spacing, borders, background, seed
│   ├── canvas_aspect_ratio.dart       # Aspect ratios (Square, Wallpaper, 9:16, 4:5, etc.) & orientation
│   ├── crop_transform.dart            # Pan and zoom crop coordinates
│   └── layout_result.dart             # Canonical placement model
├── layout/
│   ├── layout_engine.dart             # Base class and canvas size resolution
│   ├── natural_layout_engine.dart     # Edge-to-edge partitioning algorithm (zero bleed)
│   ├── uniform_layout_engine.dart     # Best-fit 4-edge grid algorithm & orientation flip
│   └── scattered_layout_engine.dart   # Strict half-extent clamped scattered engine
├── rendering/
│   ├── collage_painter.dart           # CustomPainter for preview and export with borders
│   └── export_renderer.dart           # High-res off-screen JPEG rendering pipeline
├── services/
│   ├── photo_picker_service.dart      # Multi-photo selection
│   ├── export_service.dart            # Save to gallery, native share sheet
│   └── web_download.dart              # Browser download handling
└── ui/
    ├── collage_screen.dart            # Central studio screen
    ├── collage_preview.dart           # InteractiveViewer hero canvas preview
    ├── apple_photos_crop_viewfinder.dart # Illuminated crop tool with brackets & grid
    ├── apple_photos_slider.dart       # Precision gold slider with live numeric badge
    ├── apple_photos_top_bar.dart      # Frosted glass navigation with gold Export pill
    ├── apple_photos_dock.dart         # Bottom 3-tier dock with tool modes & shuffle
    ├── apple_photos_shelf.dart        # Contextual inspector shelf (Layout, Canvas, Borders...)
    ├── empty_state_view.dart          # Obsidian dark studio empty state
    └── export_dialog.dart             # High-res export progress and actions
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.24.0 or newer)
* Dart SDK (3.5.0 or newer)
* Xcode (for iOS / macOS builds)
* Android Studio / SDK (for Android builds)
* Google Chrome (for Web testing)

### Run Locally

```bash
# Clone the repository
git clone https://github.com/muthu-kumaravel/JUST_COLLAGE.git
cd JUST_COLLAGE

# Install dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Run on iOS Simulator
flutter run -d ios

# Run on Android Emulator
flutter run -d android

# Run on macOS Desktop
flutter run -d macos
```

### Run Tests

```bash
flutter test
```

### Build for Production

```bash
# Build Web
flutter build web

# Build iOS
flutter build ipa

# Build Android App Bundle
flutter build appbundle
```

---

## 📄 License

This project is open source and available under the [Apache 2.0 License](LICENSE).