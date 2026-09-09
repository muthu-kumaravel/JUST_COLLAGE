# Build a Minimal, Open-Source Photo Collage App — Flutter iOS + Android + Web

## 1. Product Vision

Build a very simple, polished, open-source photo collage application using **Flutter**, targeting:

* iOS
* Android
* Web

The mobile and web applications **must be developed together from a shared Flutter codebase and shared core layout/rendering logic**. Do not build three separate implementations of the collage engine.

The product should prioritize:

1. Excellent collage quality
2. Extremely simple UX
3. Fast interaction
4. Strong privacy
5. High-resolution export
6. Consistent behavior across iOS, Android and Web
7. Minimal configuration and visual clutter

This is deliberately **not** a feature-heavy collage editor. Do not add unnecessary features such as templates, stickers, text, filters, AI effects, login, cloud storage, social feeds, or accounts.

The app should feel like a carefully designed native-quality utility rather than a complicated editing suite.

---

# 2. Core Privacy Model

The application must be local-first.

There must be:

* No login
* No account creation
* No backend
* No cloud storage
* No image uploads
* No analytics
* No tracking
* No advertising
* No telemetry
* No third-party image-processing API
* No server-side rendering

Photos should **not be permanently imported or copied into an application-controlled media library**.

The application may create temporary in-memory representations and temporary cache files where technically necessary for preview/rendering/export, but these must not become a permanent user-managed copy of the original photos.

The final architecture should make it possible to truthfully document the app as privacy-preserving and, subject to the final dependency set, declare that no user data is collected.

---

# 3. Platform Architecture

Use **one Flutter project/codebase** for:

* iOS
* Android
* Web

Do not duplicate the layout engine, collage calculations, or rendering logic separately for each platform.

Use a layered architecture:

```text
UI Layer
    ↓
Collage State / User Settings
    ↓
Shared Layout Engine
    ↓
Platform-specific Asset/Image Access
    ↓
Shared Preview / Export Model
    ↓
Platform-specific Output / Save / Share
```

The following should be shared as much as practical:

* photo metadata model
* layout algorithms
* canvas calculations
* frame calculations
* crop transforms
* shuffle/randomization logic
* spacing calculations
* layout validation
* rendering model
* export parameters

Platform-specific code should mainly handle:

* photo selection
* image decoding where required
* file access
* save-to-photo-library behavior
* share sheets
* web file download/browser behavior
* platform-specific permissions

Inspect the existing repository first and adapt the implementation to its current Flutter structure rather than blindly replacing the project architecture.

---

# 4. Photo Selection

## iOS

Use the modern native Photos picker behavior, ideally through the appropriate Flutter/native integration rather than copying photos into an app-managed directory.

The implementation must support selecting multiple photos directly from the user's photo library.

## Android

Use the Android System Photo Picker or the appropriate modern native equivalent.

Avoid an implementation that unnecessarily imports/copies all selected photos into persistent app storage.

## Web

Use the browser's native file/photo selection mechanism.

The browser implementation should process selected images locally in the browser and should not upload them to a server.

## Important distinction

"Import photos" in the product should mean:

> The user temporarily grants/selects photos for creating the current collage.

It must **not** mean:

> The application permanently imports and duplicates the photos into its own library.

---

# 5. Photo Count

Minimum:

**2 photos**

There must be **no application-defined maximum photo count**.

The app should attempt to handle as many selected photos as the platform/device/browser can reasonably support.

Do not implement an arbitrary rule such as:

* maximum 20
* maximum 30
* maximum 50

However, handle resource limitations gracefully.

If the browser, operating system, GPU, or available memory imposes a practical limit, degrade gracefully rather than crashing.

For large selections:

* downsample preview images
* avoid decoding every source image at full resolution simultaneously
* avoid unnecessary image duplication
* use memory-conscious rendering
* preserve the ability to export at high quality where feasible

---

# 6. Initial Workflow

The ideal workflow should be:

```text
Open App
   ↓
Select Photos
   ↓
Immediately Generate Collage
   ↓
Choose Layout
   ↓
Adjust Settings
   ↓
Shuffle
   ↓
Export
```

The user should not have to understand a complicated editing workflow.

The original selection order should be preserved initially.

Users should be able to:

* add photos
* remove photos
* regenerate the layout

Do not introduce manual drag-and-drop layout editing or manual photo swapping in V1.

---

# 7. Overall UI / UX

The UI should strongly follow **iOS-style design principles**, while still behaving naturally on Android and Web.

Prioritize:

* clean hierarchy
* large visual preview
* minimal controls
* intuitive icons
* obvious primary actions
* generous touch targets
* smooth interactions
* minimal unnecessary menus

Do not expose engineering concepts to the user.

For example, use human-friendly labels such as:

* Natural
* Uniform
* Scattered

rather than:

* Layout Engine 1
* Layout Engine 2
* Layout Engine 3

The design should feel closer to a modern Apple utility than to a traditional photo-editing suite.

---

# 8. Canvas Aspect Ratio

The **overall collage canvas aspect ratio is separate from the aspect ratio of the photos/frames inside it**.

Provide a simple canvas aspect-ratio selector with sensible options such as:

* Square — 1:1
* Portrait — 4:5
* Story — 9:16
* Landscape — 16:9
* Automatic / source-appropriate

The architecture should allow additional aspect ratios later.

The selected canvas ratio is the target composition area into which the layout engine must fit all images.

---

# 9. Three Layout Engines

Implement exactly three primary layout modes.

## Layout 1 — Natural / Justified

Goal:

Preserve the natural aspect ratio of every photo while filling the canvas elegantly.

Requirements:

* Never distort image geometry
* Maintain each source photo's aspect ratio
* No crop by default
* No overlap
* Equal visual spacing
* Equal outer margins
* Images should be distributed naturally rather than placed into a rigid conventional grid

Use a **justified-row / masonry-style composition algorithm**, similar conceptually to the image arrangements seen in Google Photos, Flickr and editorial photo walls.

### Critical balancing requirement

The layout must avoid:

* large empty spaces
* one extremely large image next to several tiny images
* one photo occupying dramatically more area than another unless dictated by the selected canvas/photo aspect ratios
* awkward unused corners
* visually unbalanced rows

The algorithm should attempt to minimize the variance in the **average area occupied by each photo**.

In other words:

> Photos should feel approximately equally distributed across the available canvas area.

The objective is not mathematical equality at any cost, but visually balanced area allocation.

Prefer:

* balanced rows
* balanced image areas
* consistent gutters
* efficient canvas utilization

over rigid adherence to one particular number of rows or columns.

### Crop trade-off

For this layout, prioritize preserving the full image.

However, if perfectly filling the canvas would otherwise produce significant empty space or extremely unbalanced image sizes, the algorithm may introduce **very minimal cropping** where appropriate.

Cropping must be:

* small
* controlled
* visually sensible
* subject-aware where possible

Do not perform aggressive crops simply to make the geometry fit.

The end result should look intentionally designed rather than algorithmically packed.

---

# 10. Layout 2 — Uniform Frames

Goal:

Every photo should appear inside a **uniform frame**, while the frame geometry itself is determined by:

1. The selected canvas aspect ratio
2. The number of selected images

The frame ratio should **not simply be a globally fixed ratio such as 1:1**.

Instead, the layout engine should calculate a set of sensible frame aspect-ratio candidates that allow the selected number of images to fit the chosen canvas efficiently.

For example, depending on:

* canvas ratio
* number of images
* composition geometry

the engine might determine several viable frame ratios.

The user should be able to choose between those valid frame-ratio options.

### Required behavior

The system should:

1. Determine the selected canvas geometry.
2. Determine the number of images.
3. Generate sensible candidate uniform frame aspect ratios/layout configurations.
4. Select a visually appropriate default.
5. Let the user switch between the available frame aspect ratios/configurations.

The default should be chosen automatically so the collage looks balanced.

The user must still have control over the frame aspect ratio.

### Frame requirements

All frames should have:

* identical dimensions
* identical aspect ratio
* equal spacing
* equal outer margins
* clean alignment

Photos should be placed into frames using **aspect-fill**.

Because aspect-fill can crop the source image, provide crop adjustment.

### Crop interaction

The user should be able to tap a photo/frame and enter an adjustment state.

Support:

* drag/pan
* pinch to zoom
* sensible crop positioning

The underlying source photo must remain unchanged.

Crop transforms should be stored as collage state rather than destructively modifying the original asset.

The app should choose a sensible initial crop that minimizes important subject cutoff.

---

# 11. Layout 3 — Random / Scattered

Goal:

Create a natural, editorial-style scattered photo collage.

Each photo can have:

* different position
* different scale
* different rotation
* different z-order

### Rotation

Rotation must be strictly constrained to:

**-15° to +15°**

Do not exceed that range.

### Aspect ratio

The **original aspect ratio of every image must always be maintained**.

Do not stretch or distort images.

### Area distribution

Unlike Layout 1 and Layout 2, a somewhat greater difference in photo area is acceptable here because the scattered composition is intentionally organic.

However, avoid:

* one image becoming overwhelmingly dominant
* extremely tiny images
* excessive clustering
* large unusable dead zones
* photos extending excessively outside the canvas
* accidental near-total occlusion

The variance in occupied area may be **slightly higher than Layout 1**, but it should still remain visually controlled.

### Controlled randomness

Do not simply generate fully random coordinates and rotations.

Use constrained placement.

The layout engine should:

1. Define valid regions within the canvas.
2. Generate candidate positions/scales.
3. Apply limited random jitter.
4. Validate the composition.
5. Reject/retry poor candidates.
6. Ensure every photo remains sufficiently visible.
7. Avoid excessive clustering.
8. Preserve intentional but controlled overlap.

The result should feel like a human-designed scattered collage rather than noise.

### Shuffle

Shuffle should generate a **natural new composition**.

A shuffle should vary composition characteristics such as:

* positions
* small scale differences
* rotation
* overlap relationships
* z-order

but remain within the same design rules.

Do not allow shuffle to produce absurd or clearly inferior compositions.

A random seed should be used so the resulting composition is deterministic for that seed and can be regenerated.

---

# 12. Pinch-to-Zoom — Common Feature

**Pinch-to-zoom must be supported as a common interaction across the app.**

This should be available wherever the user is directly interacting with the collage/image preview and should behave consistently across layouts and platforms.

At minimum, users should be able to use:

* pinch to zoom
* pan where appropriate

Do not make each layout implement completely different gesture semantics unless required by the layout.

The interaction should feel natural and predictable.

The app must distinguish between:

* zooming the preview/editor viewport
* changing an individual photo's crop/scale inside its frame

These should not accidentally interfere with one another.

Use an appropriate interaction model, such as an editor/crop overlay, when the user needs to adjust an individual image.

---

# 13. Shuffle

Provide a prominent **Shuffle** action near the bottom of the UI.

Shuffle should regenerate the composition without unexpectedly changing:

* selected photos
* canvas aspect ratio
* background
* spacing
* chosen layout mode
* frame aspect ratio selection
* crop settings where applicable

Shuffle should change the composition itself.

For:

* Natural → generate a different valid justified arrangement
* Uniform → generate a different valid arrangement of the available uniform frame configuration where meaningful
* Scattered → generate a new natural randomized arrangement

The result should always pass the relevant layout constraints.

---

# 14. Background

Provide two background modes:

### Background Color

Allow the user to select a background color.

### Background Image

Allow selection of one background image.

The background image should optionally support blur.

The background image selection must not become another permanent imported asset.

Use the same privacy principles as photo selection.

Provide sensible defaults, such as a neutral light background.

The UI for selecting background should be significantly simpler than the photo-selection workflow.

---

# 15. Spacing vs Border

For **Natural / Justified** and **Uniform** layouts:

Spacing must represent **physical empty space between images**.

Do not implement spacing by adding a white/light border around every image independently.

Instead:

1. Determine the desired outer margin.
2. Determine the desired gutter/spacing.
3. Calculate all image rectangles.
4. Place images inside those rectangles.
5. Render the empty space once between adjacent images.

This prevents the internal spacing from becoming visually double-thick.

### Scattered layout

Scattered layout does **not** use normal inter-image spacing.

Images may overlap.

Instead, provide a subtle image border/stroke if appropriate.

The implementation should ensure the border does not create unexpected visual thickness when photos overlap.

---

# 16. Image Quality and Orientation

Image quality is a core product requirement.

Support common modern image formats as practical, including:

* JPEG
* PNG
* HEIC/HEIF
* WebP where supported

Correctly handle:

* EXIF orientation
* rotation metadata
* image dimensions
* aspect ratio
* high-resolution source images

Do not accidentally rotate photos because of missing EXIF handling.

Avoid repeated JPEG encoding.

Do not unnecessarily decode full-resolution originals for the on-screen preview.

Be aware that some source photographs may use wide-gamut color profiles such as Display P3.

Do not introduce obvious color shifts unnecessarily.

---

# 17. Preview Rendering vs Export Rendering

Implement a **dual-resolution rendering pipeline**.

## Preview

The preview should use appropriately downsampled images based on:

* screen size
* tile size
* available memory
* current display scale

The preview must remain responsive.

## Export

Export should use higher-resolution source data and should not simply screenshot the UI.

The final collage should be independently rendered from the layout model.

A practical V1 target is approximately:

**3000–4000 px on the longest edge**

while dynamically adapting to device/browser memory and rendering capability.

Do not require 300 DPI.

DPI is not necessary for normal digital image export; pixel dimensions and image quality are what matter here.

The architecture should make it possible to increase export resolution later.

---

# 18. Export

Provide:

* Save to Photos / device
* Native share sheet where available
* Web download on browser

Default to high-quality JPEG.

A target JPEG quality around:

**92–95**

is reasonable for V1.

PNG does not need to be the default because the collage always has a background and JPEG provides much smaller files.

However, structure the export layer so additional output formats can be added later.

The exported image must match the visible collage composition.

---

# 19. Rendering Architecture

Use a clean internal representation such as:

```text
PhotoAsset
    ↓
CollageSettings
    ↓
LayoutEngine
    ↓
LayoutResult
    ↓
PreviewRenderer
    ↓
ExportRenderer
```

A `LayoutResult` should contain enough information to reproduce the composition deterministically.

For example:

```text
photoId
frame
cropTransform
rotation
scale
zIndex
```

plus any additional metadata necessary for the relevant layout.

The preview renderer and export renderer should both consume the same `LayoutResult`.

Do not independently recalculate layout for preview and export.

This is important so the exported collage is pixel-consistent with what the user sees.

---

# 20. Performance / Memory

The app must be designed for real-world high-resolution photographs, including modern smartphone photographs in the 12–48MP range.

Avoid:

```text
decode 30 × 48MP photos
→ hold every bitmap in RAM
→ compose everything at once
```

Instead:

* use downsampled preview representations
* load only what is necessary
* dispose resources aggressively
* decode/export sequentially where appropriate
* avoid unnecessary bitmap duplication
* keep layout calculations independent of source bitmap memory
* use background/isolate/native processing where beneficial

Large photo counts must degrade gracefully.

Do not crash because a user selected many large images.

---

# 21. Add / Remove Photos After Initial Selection

The architecture must support adding and removing photos after the collage has already been generated.

When the photo set changes:

* invalidate the relevant layout
* regenerate the layout
* preserve compatible settings
* preserve the selected canvas ratio
* preserve background settings
* preserve user preferences where reasonable

Do not silently lose unrelated settings.

---

# 22. Edge Cases

Explicitly test:

* 2 photos
* 3 photos
* 4 photos
* 5–10 photos
* high photo counts
* extreme portrait photos
* extreme landscape photos
* mixed portrait/landscape
* very high-resolution images
* HEIC/HEIF
* photos with EXIF rotation
* unusual aspect ratios
* adding/removing photos
* switching layouts repeatedly
* repeated shuffle
* export after multiple crop adjustments

For every case the application should remain stable and produce a visually valid composition.

---

# 23. Accessibility

Support platform accessibility expectations, including:

* VoiceOver
* TalkBack
* keyboard navigation on Web where appropriate
* accessible labels
* sufficiently large touch targets
* logical focus order
* usable text scaling

Do not sacrifice usability for decorative UI.

---

# 24. Cross-Platform Consistency

The same collage state should conceptually produce the same composition rules across:

* iOS
* Android
* Web

Do not allow the web implementation to use an entirely separate layout algorithm.

Randomization should be seed-based so the same seed can reproduce the same logical composition.

Platform-specific rendering differences are acceptable where unavoidable, but the layout model must remain shared.

---

# 25. Open Source

The project must be open source.

Unless the existing repository specifies another license, use a permissive license such as:

**MIT**

Include:

* LICENSE
* README
* architecture documentation where useful
* dependency/license review

Do not introduce dependencies whose licenses conflict with the project's chosen open-source license.

---

# 26. Privacy Documentation

Document clearly in the README/privacy documentation:

* photos remain local
* no image uploads
* no account required
* no cloud processing
* no tracking
* no analytics
* no advertising

Do not claim "no data collected" unless the final dependency and platform implementation genuinely support that claim.

---

# 27. Testing

Create tests for the shared layout engine.

At minimum:

### Natural Layout

Test that:

* aspect ratios are preserved
* no unintended overlap occurs
* spacing is consistent
* empty space is minimized
* image area variance is kept low
* no image becomes disproportionately large/small without necessity
* crop remains minimal where required

### Uniform Layout

Test that:

* frame dimensions are equal
* frame aspect ratio is consistent
* candidate frame ratios are valid for the canvas/photo count
* all photos remain correctly clipped
* crop transforms behave correctly

### Scattered Layout

Test that:

* rotation remains between -15° and +15°
* image aspect ratios remain unchanged
* all photos remain sufficiently visible
* overlap stays controlled
* positions remain within acceptable bounds
* shuffle produces valid compositions

### Rendering

Test that:

* preview and export consume the same layout result
* EXIF orientation is respected
* crop transforms are preserved
* exported dimensions are correct
* high-resolution images do not crash the renderer

---

# 28. Implementation Phases

Work incrementally.

## Phase 1 — Repository Inspection

First inspect the existing repository.

Understand:

* Flutter version
* existing dependencies
* current folder structure
* iOS configuration
* Android configuration
* Web configuration
* current state of the app

Do not immediately replace the existing architecture.

## Phase 2 — Core Architecture

Implement:

* shared collage state
* photo asset abstraction
* canvas settings
* layout engine abstraction
* layout result model

## Phase 3 — Photo Selection

Implement native/local photo selection for:

* iOS
* Android
* Web

while maintaining the privacy model.

## Phase 4 — Layout Engines

Implement and test:

1. Natural / Justified
2. Uniform Frames
3. Random / Scattered

Prioritize mathematical validity and visual quality over rushing to UI polish.

## Phase 5 — Preview

Build the responsive collage preview and common pinch-to-zoom interaction.

## Phase 6 — Editing Controls

Implement:

* layout switching
* canvas ratio
* frame ratio selection where applicable
* background color
* background image
* blur
* spacing
* crop interaction
* shuffle

## Phase 7 — Export

Build high-resolution rendering independently from the preview.

Support:

* iOS Photos
* Android storage/photo library behavior as appropriate
* Web download
* native sharing where appropriate

## Phase 8 — Polish

Improve:

* animations
* accessibility
* error states
* loading states
* empty states
* responsive Web layout
* platform-specific UX conventions

## Phase 9 — Testing

Test on:

* iOS
* Android
* Web

and with both small and very large photo selections.

---

# 29. Important Engineering Principles

Do not:

* over-engineer the UI
* introduce unnecessary dependencies
* create separate collage engines for iOS, Android and Web
* permanently copy photos
* use arbitrary maximum photo counts
* distort photographs
* randomly produce unusable compositions
* use screenshot-based export
* duplicate expensive full-resolution bitmaps unnecessarily
* expose unnecessary layout complexity to users

Do:

* share the core engine across all platforms
* prioritize visual balance
* preserve image aspect ratios
* use deterministic seeded randomness
* separate layout from rendering
* separate preview from export
* optimize for high-resolution photos
* keep the UI extremely simple
* make excellent defaults so most users do not need to change settings

---

# 30. Definition of Done

The project is complete when:

* iOS works
* Android works
* Web works
* all three use the same shared collage/layout architecture
* users can select 2+ photos locally
* there is no application-defined maximum photo count
* no photo is uploaded
* no account is required
* Natural layout produces balanced justified compositions
* Natural layout preserves aspect ratios and minimizes area variance
* Uniform layout dynamically proposes suitable frame aspect ratios based on canvas + photo count
* users can choose the frame aspect ratio
* Uniform layout supports crop adjustment
* Scattered layout preserves aspect ratio
* Scattered rotation never exceeds -15°/+15°
* Scattered shuffle produces natural, controlled compositions
* pinch-to-zoom is available as a common interaction
* background color works
* background image works
* background blur works
* spacing is implemented correctly
* preview is responsive
* export is high quality
* EXIF orientation is correct
* large images are handled without unnecessary memory explosions
* save/share/download works appropriately on each platform
* accessibility basics are implemented
* tests cover the core layout engines
* README/license/privacy documentation are present

Most importantly, the resulting application should feel **extremely simple for the user while being technically robust underneath**.

Do not stop at an architecture proposal. **Inspect the existing repository first, then implement the application incrementally, starting with the shared architecture and core layout engine.**