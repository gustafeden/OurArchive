class Track {
  final String position;    // Track position/number (e.g., "A1", "1", "B3")
  final String title;        // Song/track title
  final String? duration;    // Track duration in format "3:45"
  final String? side;        // Vinyl side ("A", "B") - null for CDs/digital
  final String? artist;      // Track artist if different from album artist
  final String? previewUrl;  // Apple Music/iTunes preview URL (30-90 seconds)

  const Track({
    required this.position,
    required this.title,
    this.duration,
    this.side,
    this.artist,
    this.previewUrl,
  });

  /// Create Track from JSON/Firestore map
  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      position: json['position'] as String? ?? '',
      title: json['title'] as String? ?? '',
      duration: json['duration'] as String?,
      side: json['side'] as String?,
      artist: json['artist'] as String?,
      previewUrl: json['previewUrl'] as String?,
    );
  }

  /// Convert Track to JSON/Firestore map
  Map<String, dynamic> toJson() => {
        'position': position,
        'title': title,
        if (duration != null) 'duration': duration,
        if (side != null) 'side': side,
        if (artist != null) 'artist': artist,
        if (previewUrl != null) 'previewUrl': previewUrl,
      };

  /// Create a copy of this Track with optional field updates
  Track copyWith({
    String? position,
    String? title,
    String? duration,
    String? side,
    String? artist,
    String? previewUrl,
  }) {
    return Track(
      position: position ?? this.position,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      side: side ?? this.side,
      artist: artist ?? this.artist,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }

  @override
  String toString() {
    return 'Track(position: $position, title: $title, duration: $duration, side: $side, artist: $artist, previewUrl: $previewUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Track &&
        other.position == position &&
        other.title == title &&
        other.duration == duration &&
        other.side == side &&
        other.artist == artist &&
        other.previewUrl == previewUrl;
  }

  @override
  int get hashCode {
    return position.hashCode ^
        title.hashCode ^
        (duration?.hashCode ?? 0) ^
        (side?.hashCode ?? 0) ^
        (artist?.hashCode ?? 0) ^
        (previewUrl?.hashCode ?? 0);
  }
}
