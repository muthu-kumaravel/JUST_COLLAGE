/// Supported canvas orientations.
enum CanvasOrientation {
  portrait,
  landscape;

  bool get isPortrait => this == CanvasOrientation.portrait;
  bool get isLandscape => this == CanvasOrientation.landscape;

  CanvasOrientation toggle() =>
      this == CanvasOrientation.portrait ? CanvasOrientation.landscape : CanvasOrientation.portrait;
}

/// Represents the target aspect ratio of the collage canvas.
class CanvasAspectRatio {
  final String id;
  final String label;
  final double baseRatio; // Standard portrait ratio (< 1.0 except square)
  final CanvasOrientation orientation;
  final bool isAuto;

  const CanvasAspectRatio({
    required this.id,
    required this.label,
    required this.baseRatio,
    this.orientation = CanvasOrientation.portrait,
    this.isAuto = false,
  });

  /// Effective ratio (width / height) taking orientation into account.
  double get ratio {
    if (id == '1:1' || isAuto) return 1.0;
    final double portraitRatio = baseRatio <= 1.0 ? baseRatio : 1.0 / baseRatio;
    return orientation == CanvasOrientation.portrait
        ? portraitRatio
        : (1.0 / portraitRatio);
  }

  CanvasAspectRatio withOrientation(CanvasOrientation newOrientation) {
    if (id == '1:1') return this;
    return CanvasAspectRatio(
      id: id,
      label: label,
      baseRatio: baseRatio,
      orientation: newOrientation,
      isAuto: isAuto,
    );
  }

  CanvasAspectRatio toggleOrientation() => withOrientation(orientation.toggle());

  String get displayLabel {
    if (id == '1:1') return '1:1 Square';
    if (id == 'wallpaper') {
      return orientation == CanvasOrientation.portrait ? '9:19.5 Wallpaper' : '19.5:9 Wallpaper';
    }
    if (id == '9:16') {
      return orientation == CanvasOrientation.portrait ? '9:16' : '16:9';
    }
    if (id == '4:5') {
      return orientation == CanvasOrientation.portrait ? '4:5' : '5:4';
    }
    if (id == '1.91:1' || id == '1080:566') {
      return orientation == CanvasOrientation.landscape ? '1.91:1 (1080×566)' : '566:1080';
    }
    if (id == '5:7') {
      return orientation == CanvasOrientation.portrait ? '5:7' : '7:5';
    }
    if (id == '3:4') {
      return orientation == CanvasOrientation.portrait ? '3:4' : '4:3';
    }
    if (id == '3:5') {
      return orientation == CanvasOrientation.portrait ? '3:5' : '5:3';
    }
    if (id == '2:3') {
      return orientation == CanvasOrientation.portrait ? '2:3' : '3:2';
    }
    return label;
  }

  /// Formatted ratio text respecting current orientation (e.g. 9:16 in portrait, 16:9 in landscape).
  String get activeRatioLabel {
    if (id == '1:1') return '1:1';
    if (id == 'wallpaper') {
      return orientation == CanvasOrientation.portrait ? '9:19.5' : '19.5:9';
    }
    if (id == '9:16') {
      return orientation == CanvasOrientation.portrait ? '9:16' : '16:9';
    }
    if (id == '4:5') {
      return orientation == CanvasOrientation.portrait ? '4:5' : '5:4';
    }
    if (id == '1.91:1' || id == '1080:566') {
      return orientation == CanvasOrientation.landscape ? '1.91:1' : '566:1080';
    }
    if (id == '5:7') {
      return orientation == CanvasOrientation.portrait ? '5:7' : '7:5';
    }
    if (id == '3:4') {
      return orientation == CanvasOrientation.portrait ? '3:4' : '4:3';
    }
    if (id == '3:5') {
      return orientation == CanvasOrientation.portrait ? '3:5' : '5:3';
    }
    if (id == '2:3') {
      return orientation == CanvasOrientation.portrait ? '2:3' : '3:2';
    }
    return label;
  }

  /// Whether this canvas preset represents a standard Instagram format for the active orientation.
  bool get isInstagram {
    if (orientation == CanvasOrientation.portrait) {
      return id == '4:5' || id == '9:16';
    } else {
      return id == '1.91:1' || id == '1080:566';
    }
  }

  /// Context tag for Instagram format (e.g. 'IG Post', 'IG Story')
  String? get instagramTag {
    if (orientation == CanvasOrientation.portrait) {
      if (id == '4:5') return 'IG Post';
      if (id == '9:16') return 'IG Story';
    } else {
      if (id == '1.91:1' || id == '1080:566') return 'IG Post';
    }
    return null;
  }

  static const CanvasAspectRatio square1x1 = CanvasAspectRatio(
    id: '1:1',
    label: 'Square',
    baseRatio: 1.0,
  );

  static const CanvasAspectRatio wallpaper = CanvasAspectRatio(
    id: 'wallpaper',
    label: 'Wallpaper',
    baseRatio: 9.0 / 19.5,
  );

  static const CanvasAspectRatio ratio9x16 = CanvasAspectRatio(
    id: '9:16',
    label: '9:16',
    baseRatio: 9.0 / 16.0,
  );

  static const CanvasAspectRatio ratio4x5 = CanvasAspectRatio(
    id: '4:5',
    label: '4:5',
    baseRatio: 4.0 / 5.0,
  );

  static const CanvasAspectRatio ratio1080x566 = CanvasAspectRatio(
    id: '1.91:1',
    label: '1.91:1',
    baseRatio: 566.0 / 1080.0,
  );

  static const CanvasAspectRatio ratio5x7 = CanvasAspectRatio(
    id: '5:7',
    label: '5:7',
    baseRatio: 5.0 / 7.0,
  );

  static const CanvasAspectRatio ratio3x4 = CanvasAspectRatio(
    id: '3:4',
    label: '3:4',
    baseRatio: 3.0 / 4.0,
  );

  static const CanvasAspectRatio ratio3x5 = CanvasAspectRatio(
    id: '3:5',
    label: '3:5',
    baseRatio: 3.0 / 5.0,
  );

  static const CanvasAspectRatio ratio2x3 = CanvasAspectRatio(
    id: '2:3',
    label: '2:3',
    baseRatio: 2.0 / 3.0,
  );

  static const List<CanvasAspectRatio> presets = [
    square1x1,
    wallpaper,
    ratio9x16,
    ratio4x5,
    ratio1080x566,
    ratio5x7,
    ratio3x4,
    ratio3x5,
    ratio2x3,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasAspectRatio &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orientation == other.orientation;

  @override
  int get hashCode => Object.hash(id, orientation);

  @override
  String toString() => 'CanvasAspectRatio($id, $displayLabel, $ratio, $orientation)';
}
