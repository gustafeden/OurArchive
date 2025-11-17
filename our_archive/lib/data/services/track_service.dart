import '../../services/discogs_service.dart';
import '../models/item.dart';
import '../models/track.dart';
import '../repositories/item_repository.dart';
import 'itunes_search_service.dart';

/// Service for managing track listings for music albums
class TrackService {
  final ItemRepository _itemRepository;

  TrackService(this._itemRepository);

  /// Get tracks for an item, fetching from Discogs if needed
  /// Returns cached tracks if available, otherwise fetches from Discogs API
  Future<List<Track>> getTracksForItem(Item item, String householdId) async {
    // Return cached tracks if available
    if (item.tracks != null && item.tracks!.isNotEmpty) {
      return item.tracks!;
    }

    // No tracks cached, try to fetch from Discogs
    if (item.discogsId == null || item.discogsId!.isEmpty) {
      return []; // Cannot fetch without Discogs ID
    }

    try {
      final tracks = await fetchTracksFromDiscogs(item.discogsId!);

      // Cache the tracks back to the item in Firestore
      if (tracks.isNotEmpty) {
        await cacheTracksToItem(householdId, item.id, tracks);
      }

      return tracks;
    } catch (e) {
      // Log error but don't throw - gracefully return empty list
      print('Error fetching tracks for item ${item.id}: $e');
      return [];
    }
  }

  /// Fetch track listing from Discogs API
  Future<List<Track>> fetchTracksFromDiscogs(String discogsId) async {
    try {
      final releaseDetails = await DiscogsService.getReleaseDetails(discogsId);

      if (releaseDetails == null) {
        return [];
      }

      final tracklist = releaseDetails['tracklist'] as List<dynamic>?;
      if (tracklist == null || tracklist.isEmpty) {
        return [];
      }

      return tracklist.map((trackData) {
        final trackMap = trackData as Map<String, dynamic>;

        // Determine side from position (e.g., "A1" -> "A", "B3" -> "B")
        final position = trackMap['position'] as String? ?? '';
        String? side;
        if (position.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(position)) {
          side = position[0]; // First character is the side
        }

        return Track(
          position: position,
          title: trackMap['title'] as String? ?? '',
          duration: trackMap['duration'] as String?,
          side: side,
          // Discogs can have artists per track for compilations
          artist: (trackMap['artists'] as List<dynamic>?)
              ?.map((a) => (a as Map<String, dynamic>)['name'] as String)
              .join(', '),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Cache tracks to the item in Firestore
  Future<void> cacheTracksToItem(String householdId, String itemId, List<Track> tracks) async {
    try {
      // Use the item repository to update the item with tracks
      await _itemRepository.updateItemTracks(
        householdId: householdId,
        itemId: itemId,
        tracks: tracks,
      );
    } catch (e) {
      // Don't throw - caching failure shouldn't break the UI
    }
  }

  /// Fetch preview URL for a specific track on-demand
  /// Returns the track with preview URL if found, otherwise returns original track
  Future<Track> fetchPreviewForTrack(Track track, Item item) async {
    // If track already has a preview URL, return it
    if (track.previewUrl != null && track.previewUrl!.isNotEmpty) {
      return track;
    }

    try {
      // Search iTunes for preview URLs for the entire album
      final previewMap = await ITunesSearchService.searchAlbumPreviews(
        albumName: item.title,
        artistName: item.artist,
      );

      // Match this specific track
      final enrichedTrack = ITunesSearchService.matchTracksWithPreviews(
        [track],
        previewMap,
      ).first;

      return enrichedTrack;
    } catch (e) {
      print('[TrackService] Error fetching preview: $e');
      return track; // Return original track on error
    }
  }
}
