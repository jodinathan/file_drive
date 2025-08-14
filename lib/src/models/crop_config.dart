/// Configuration class for crop operations
class CropConfig {
  /// Aspect ratio for cropping (width/height)
  final double? aspectRatio;

  /// Minimum aspect ratio allowed
  final double? minRatio;

  /// Maximum aspect ratio allowed
  final double? maxRatio;

  /// Minimum width for the cropped image in pixels
  final int? minWidth;

  /// Minimum height for the cropped image in pixels
  final int? minHeight;

  /// Maximum width for the cropped image in pixels
  final int? maxWidth;

  /// Maximum height for the cropped image in pixels
  final int? maxHeight;

  /// Whether to enforce the aspect ratio strictly
  final bool enforceAspectRatio;

  /// Whether to allow free-form cropping
  final bool allowFreeForm;

  const CropConfig({
    this.aspectRatio,
    this.minRatio,
    this.maxRatio,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    this.enforceAspectRatio = false,
    this.allowFreeForm = true,
  }) : assert(aspectRatio == null || aspectRatio > 0, 'Aspect ratio must be positive'),
       assert(minRatio == null || minRatio > 0, 'Min ratio must be positive'),
       assert(maxRatio == null || maxRatio > 0, 'Max ratio must be positive'),
       assert(minWidth == null || minWidth > 0, 'Min width must be positive'),
       assert(minHeight == null || minHeight > 0, 'Min height must be positive'),
       assert(maxWidth == null || maxWidth > 0, 'Max width must be positive'),
       assert(maxHeight == null || maxHeight > 0, 'Max height must be positive'),
       assert(minRatio == null || maxRatio == null || minRatio <= maxRatio, 'Min ratio must be <= max ratio');

  /// Creates a crop config for square images (1:1 aspect ratio)
  factory CropConfig.square({
    int? minSize,
    int? maxSize,
  }) {
    return CropConfig(
      aspectRatio: 1.0,
      enforceAspectRatio: true,
      allowFreeForm: false,
      minWidth: minSize,
      minHeight: minSize,
      maxWidth: maxSize,
      maxHeight: maxSize,
    );
  }

  /// Creates a crop config for landscape images (16:9 aspect ratio)
  factory CropConfig.landscape({
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
  }) {
    return CropConfig(
      aspectRatio: 16.0 / 9.0,
      enforceAspectRatio: true,
      allowFreeForm: false,
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Creates a crop config for portrait images (9:16 aspect ratio)
  factory CropConfig.portrait({
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
  }) {
    return CropConfig(
      aspectRatio: 9.0 / 16.0,
      enforceAspectRatio: true,
      allowFreeForm: false,
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Creates a crop config for custom aspect ratio
  factory CropConfig.custom({
    required double aspectRatio,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    bool enforceAspectRatio = true,
  }) {
    return CropConfig(
      aspectRatio: aspectRatio,
      enforceAspectRatio: enforceAspectRatio,
      allowFreeForm: !enforceAspectRatio,
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Creates a crop config for free-form cropping
  factory CropConfig.freeForm({
    double? minRatio,
    double? maxRatio,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
  }) {
    return CropConfig(
      minRatio: minRatio,
      maxRatio: maxRatio,
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      enforceAspectRatio: false,
      allowFreeForm: true,
    );
  }

  /// Gets the effective aspect ratio to use for cropping
  double? get effectiveAspectRatio {
    if (enforceAspectRatio && aspectRatio != null) {
      return aspectRatio;
    }
    return null;
  }

  /// Gets the effective minimum ratio
  double? get effectiveMinRatio {
    if (enforceAspectRatio && aspectRatio != null) {
      return aspectRatio;
    }
    return minRatio;
  }

  /// Gets the effective maximum ratio
  double? get effectiveMaxRatio {
    if (enforceAspectRatio && aspectRatio != null) {
      return aspectRatio;
    }
    return maxRatio;
  }

  /// Validates if a crop rectangle meets the configuration requirements
  bool isValidCrop(int cropWidth, int cropHeight) {
    // Check minimum dimensions
    if (minWidth != null && cropWidth < minWidth!) return false;
    if (minHeight != null && cropHeight < minHeight!) return false;

    // Check maximum dimensions
    if (maxWidth != null && cropWidth > maxWidth!) return false;
    if (maxHeight != null && cropHeight > maxHeight!) return false;

    // Check aspect ratio constraints
    if (cropWidth > 0 && cropHeight > 0) {
      final cropRatio = cropWidth / cropHeight;
      
      if (enforceAspectRatio && aspectRatio != null) {
        const tolerance = 0.01; // Allow small tolerance for floating point comparison
        return (cropRatio - aspectRatio!).abs() <= tolerance;
      }
      
      if (minRatio != null && cropRatio < minRatio!) return false;
      if (maxRatio != null && cropRatio > maxRatio!) return false;
    }

    return true;
  }

  /// Gets a descriptive string for this crop configuration
  String get description {
    if (enforceAspectRatio && aspectRatio != null) {
      final ratio = aspectRatio!;
      if (ratio == 1.0) return 'Square (1:1)';
      if ((ratio - 16.0/9.0).abs() < 0.01) return 'Landscape (16:9)';
      if ((ratio - 9.0/16.0).abs() < 0.01) return 'Portrait (9:16)';
      return 'Custom (${ratio.toStringAsFixed(2)}:1)';
    }
    
    if (allowFreeForm) {
      return 'Free-form';
    }
    
    return 'Custom crop';
  }

  @override
  String toString() {
    return 'CropConfig($description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is CropConfig &&
        other.aspectRatio == aspectRatio &&
        other.minRatio == minRatio &&
        other.maxRatio == maxRatio &&
        other.minWidth == minWidth &&
        other.minHeight == minHeight &&
        other.maxWidth == maxWidth &&
        other.maxHeight == maxHeight &&
        other.enforceAspectRatio == enforceAspectRatio &&
        other.allowFreeForm == allowFreeForm;
  }

  @override
  int get hashCode {
    return Object.hash(
      aspectRatio,
      minRatio,
      maxRatio,
      minWidth,
      minHeight,
      maxWidth,
      maxHeight,
      enforceAspectRatio,
      allowFreeForm,
    );
  }
}