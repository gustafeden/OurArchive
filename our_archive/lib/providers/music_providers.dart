import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/item.dart';
import '../data/models/track.dart';
import '../data/services/track_service.dart';
import '../data/services/music_preview_player.dart';
import 'providers.dart';

/// State for music-specific filters in CoverFlow
class MusicFilterState {
  final Set<String> selectedFormats; // vinyl, cd, cassette, digital
  final String? selectedGenre;
  final MusicSortOption sortOption;

  const MusicFilterState({
    this.selectedFormats = const {'vinyl', 'cd', 'cassette', 'digital'},
    this.selectedGenre,
    this.sortOption = MusicSortOption.artist,
  });

  MusicFilterState copyWith({
    Set<String>? selectedFormats,
    String? selectedGenre,
    bool clearGenre = false,
    MusicSortOption? sortOption,
  }) {
    return MusicFilterState(
      selectedFormats: selectedFormats ?? this.selectedFormats,
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

enum MusicSortOption {
  artist,
  album,
  year,
  recentlyAdded,
}

// Track Service provider
final trackServiceProvider = Provider((ref) {
  final itemRepository = ref.watch(itemRepositoryProvider);
  return TrackService(itemRepository);
});

// Music filter state provider
final musicFilterStateProvider = StateProvider<MusicFilterState>(
  (ref) => const MusicFilterState(),
);

// All music items across all user households
final allMusicItemsProvider = StreamProvider<List<Item>>((ref) async* {
  final userHouseholdsAsync = ref.watch(userHouseholdsProvider);
  final households = userHouseholdsAsync.value ?? [];

  if (households.isEmpty) {
    yield [];
    return;
  }

  final itemRepo = ref.watch(itemRepositoryProvider);

  // For simplicity, we'll just listen to the first household's stream
  // and periodically fetch from all households
  // A production app would want proper stream merging, but this works for MVP
  if (households.length == 1) {
    // Single household - use stream directly
    await for (final items in itemRepo.getItems(households[0].id)) {
      final musicItems = items
          .where((item) => item.type == 'vinyl' && !item.archived)
          .toList();
      yield musicItems;
    }
  } else {
    // Multiple households - fetch all items periodically
    // Note: This is a simple approach; in production you'd want to properly merge streams
    await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
      final allMusicItems = <Item>[];

      for (final household in households) {
        try {
          final items = await itemRepo.getItems(household.id).first;
          final musicItems = items.where(
            (item) => item.type == 'vinyl' && !item.archived,
          );
          allMusicItems.addAll(musicItems);
        } catch (e) {
          // Skip household if fetch fails
          continue;
        }
      }

      yield allMusicItems;
    }
  }
});

// Music items for a specific household
final householdMusicItemsProvider =
    StreamProvider.family<List<Item>, String>((ref, householdId) {
  if (householdId.isEmpty) {
    return Stream.value([]);
  }

  final itemRepo = ref.watch(itemRepositoryProvider);
  return itemRepo.getItems(householdId).map((items) {
    return items
        .where((item) => item.type == 'vinyl' && !item.archived)
        .toList();
  });
});

// Filtered music items (applies format, genre, and sort filters)
final filteredMusicItemsProvider =
    Provider.family<List<Item>, String?>((ref, householdId) {
  // Get music items (all or specific household)
  final musicItems = householdId == null
      ? (ref.watch(allMusicItemsProvider).value ?? [])
      : (ref.watch(householdMusicItemsProvider(householdId)).value ?? []);

  final filterState = ref.watch(musicFilterStateProvider);

  // Apply filters
  var filtered = musicItems.where((item) {
    // Format filter
    if (filterState.selectedFormats.isNotEmpty) {
      final itemFormat = _getMusicFormat(item);
      if (!filterState.selectedFormats.contains(itemFormat)) {
        return false;
      }
    }

    // Genre filter
    if (filterState.selectedGenre != null) {
      if (item.genre == null ||
          !item.genre!
              .toLowerCase()
              .contains(filterState.selectedGenre!.toLowerCase())) {
        return false;
      }
    }

    return true;
  }).toList();

  // Apply sorting
  switch (filterState.sortOption) {
    case MusicSortOption.artist:
      filtered.sort((a, b) {
        final artistA = a.artist ?? '';
        final artistB = b.artist ?? '';
        if (artistA == artistB) {
          return (a.title).compareTo(b.title);
        }
        return artistA.compareTo(artistB);
      });
      break;

    case MusicSortOption.album:
      filtered.sort((a, b) => a.title.compareTo(b.title));
      break;

    case MusicSortOption.year:
      filtered.sort((a, b) {
        final yearA = int.tryParse(a.releaseYear ?? '0') ?? 0;
        final yearB = int.tryParse(b.releaseYear ?? '0') ?? 0;
        if (yearA == yearB) {
          return (a.artist ?? '').compareTo(b.artist ?? '');
        }
        return yearB.compareTo(yearA); // Newest first
      });
      break;

    case MusicSortOption.recentlyAdded:
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
  }

  return filtered;
});

// Helper function to determine music format from item
String _getMusicFormat(Item item) {
  if (item.format == null || item.format!.isEmpty) {
    return 'other';
  }

  final formatStr = item.format!.join(' ').toLowerCase();

  if (formatStr.contains('cd')) return 'cd';
  if (formatStr.contains('vinyl') || formatStr.contains('lp')) return 'vinyl';
  if (formatStr.contains('cassette')) return 'cassette';
  if (formatStr.contains('digital') || formatStr.contains('file')) {
    return 'digital';
  }

  return 'other';
}

// Provider for all unique genres in the music collection
final musicGenresProvider = Provider.family<List<String>, String?>((ref, householdId) {
  final musicItems = householdId == null
      ? (ref.watch(allMusicItemsProvider).value ?? [])
      : (ref.watch(householdMusicItemsProvider(householdId)).value ?? []);

  final genres = musicItems
      .where((item) => item.genre != null && item.genre!.isNotEmpty)
      .map((item) => item.genre!)
      .toSet()
      .toList();

  genres.sort();
  return genres;
});

// Music Preview Player - single instance for the entire app
final musicPreviewPlayerProvider = Provider<MusicPreviewPlayer>((ref) {
  final player = MusicPreviewPlayer();

  // Dispose player when provider is disposed
  ref.onDispose(() {
    player.dispose();
  });

  return player;
});

// Currently playing track state
final currentlyPlayingTrackProvider = StateProvider<Track?>((ref) => null);

// Playback state notifier
class PlaybackState {
  final bool isPlaying;
  final Track? currentTrack;
  final Duration position;
  final Duration? duration;

  const PlaybackState({
    this.isPlaying = false,
    this.currentTrack,
    this.position = Duration.zero,
    this.duration,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    Track? currentTrack,
    bool clearTrack = false,
    Duration? position,
    Duration? duration,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

final playbackStateProvider = StateNotifierProvider<PlaybackStateNotifier, PlaybackState>((ref) {
  return PlaybackStateNotifier(ref);
});

class PlaybackStateNotifier extends StateNotifier<PlaybackState> {
  final Ref _ref;

  PlaybackStateNotifier(this._ref) : super(const PlaybackState()) {
    _initPlayer();
  }

  void _initPlayer() {
    final player = _ref.read(musicPreviewPlayerProvider);

    // Listen to player state changes
    player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        currentTrack: player.currentTrack,
      );
    });

    // Listen to position changes
    player.positionStream.listen((position) {
      state = state.copyWith(
        position: position,
        duration: player.duration,
      );
    });
  }

  Future<void> playTrack(Track track) async {
    final player = _ref.read(musicPreviewPlayerProvider);
    await player.playTrack(track);
    state = state.copyWith(
      currentTrack: track,
      isPlaying: true,
    );
  }

  Future<void> pause() async {
    final player = _ref.read(musicPreviewPlayerProvider);
    await player.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> play() async {
    final player = _ref.read(musicPreviewPlayerProvider);
    await player.play();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stop() async {
    final player = _ref.read(musicPreviewPlayerProvider);
    await player.stop();
    state = state.copyWith(
      isPlaying: false,
      clearTrack: true,
    );
  }

  Future<void> togglePlayPause(Track track) async {
    final player = _ref.read(musicPreviewPlayerProvider);

    if (player.isTrackLoaded(track)) {
      if (player.isPlaying) {
        await pause();
      } else {
        await play();
      }
    } else {
      await playTrack(track);
    }
  }

  /// Fetch preview URL for a track and play it
  /// This is called from the UI when user taps a track
  Future<Track> fetchAndPlayTrack(Track track, Item item) async {
    final trackService = _ref.read(trackServiceProvider);

    // Fetch the preview URL (if not already present)
    final enrichedTrack = await trackService.fetchPreviewForTrack(track, item);

    // Try to play the track (even if no preview found - player will handle gracefully)
    await playTrack(enrichedTrack);

    return enrichedTrack;
  }
}
