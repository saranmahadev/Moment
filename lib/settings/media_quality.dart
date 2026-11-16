/// How much of a photo is kept when it is added. Videos are never
/// re-encoded, whatever this says: they are kept as recorded.
enum MediaQuality {
  original('Original', 'Every pixel, as taken'),
  high('High', 'Photos up to 2560 px on the long edge', maxEdge: 2560),
  smaller('Smaller', 'Photos up to 1600 px on the long edge', maxEdge: 1600);

  const MediaQuality(this.label, this.description, {this.maxEdge});

  final String label;
  final String description;

  /// The longest side a stored photo may have, or null for no limit.
  final int? maxEdge;

  /// JPEG quality for the stored photo.
  int get jpegQuality => switch (this) {
    MediaQuality.original => 100,
    MediaQuality.high => 92,
    MediaQuality.smaller => 85,
  };
}
