import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../data/models/item.dart';
import '../../../data/models/track.dart';
import '../../../providers/music_providers.dart';

/// Floating panel that displays track listing over the centered album
class TrackOverlayPanel extends ConsumerStatefulWidget {
  final Item item;
  final List<Track>? tracks;
  final bool isLoading;
  final double width;
  final double height;
  final VoidCallback? onClose;

  const TrackOverlayPanel({
    super.key,
    required this.item,
    this.tracks,
    this.isLoading = false,
    required this.width,
    required this.height,
    this.onClose,
  });

  @override
  ConsumerState<TrackOverlayPanel> createState() => _TrackOverlayPanelState();
}

class _TrackOverlayPanelState extends ConsumerState<TrackOverlayPanel> {
  // Track which track is currently loading a preview
  String? _loadingTrackId;

  // Local cache of enriched tracks
  final Map<String, Track> _enrichedTracks = {};

  // Whether we've already enriched the tracks
  bool _hasEnrichedTracks = false;

  String _getTrackId(Track track) => '${track.position}_${track.title}';

  @override
  void initState() {
    super.initState();
    // Enrich tracks on first load
    _enrichAllTracksInBackground();
  }

  @override
  void didUpdateWidget(TrackOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If tracks changed, re-enrich
    if (widget.tracks != oldWidget.tracks && widget.tracks != null) {
      _hasEnrichedTracks = false;
      _enrichAllTracksInBackground();
    }
  }

  /// Enrich all tracks in the background with preview URLs
  Future<void> _enrichAllTracksInBackground() async {
    if (_hasEnrichedTracks || widget.tracks == null || widget.tracks!.isEmpty) {
      return;
    }

    _hasEnrichedTracks = true;

    try {
      final trackService = ref.read(trackServiceProvider);
      final enrichedTracks = await trackService.fetchPreviewsForAllTracks(
        widget.tracks!,
        widget.item,
      );

      // Update local cache with enriched tracks
      if (mounted) {
        setState(() {
          for (final track in enrichedTracks) {
            final trackId = _getTrackId(track);
            _enrichedTracks[trackId] = track;
          }
        });
      }
    } catch (e) {
      print('[TrackOverlay] Error enriching tracks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackStateProvider);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),

            // Track list or loading indicator
            Expanded(
              child: widget.isLoading
                  ? _buildLoadingState()
                  : (widget.tracks == null || widget.tracks!.isEmpty)
                      ? _buildNoTracksState(context)
                      : _buildTrackList(context, playbackState),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the header with album info
  Widget _buildHeader(BuildContext context) {
    final coverUrl = widget.item.coverUrl ?? widget.item.photoThumbPath;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini cover thumbnail
          if (coverUrl != null && coverUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[800],
                  child: const Icon(Ionicons.disc_outline, size: 24),
                ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Ionicons.disc_outline, size: 24),
            ),

          const SizedBox(width: 12),

          // Album info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artist
                if (widget.item.artist != null && widget.item.artist!.isNotEmpty)
                  Text(
                    widget.item.artist!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 4),

                // Album title
                Text(
                  widget.item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Year & Label
                if (widget.item.releaseYear != null || widget.item.label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (widget.item.releaseYear != null) widget.item.releaseYear!,
                        if (widget.item.label != null) widget.item.label!,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Close button
          IconButton(
            icon: const Icon(Ionicons.close, size: 20),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text('Loading tracks...'),
        ],
      ),
    );
  }

  /// Build no tracks state
  Widget _buildNoTracksState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Ionicons.musical_notes_outline,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No track listing available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build track list
  Widget _buildTrackList(BuildContext context, PlaybackState playbackState) {
    if (widget.tracks == null || widget.tracks!.isEmpty) {
      return _buildNoTracksState(context);
    }

    try {
      // Group tracks by side (for vinyl)
      final tracksBySide = <String, List<Track>>{};
      for (final track in widget.tracks!) {
        final side = track.side ?? 'Tracks';
        tracksBySide.putIfAbsent(side, () => []).add(track);
      }

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final entry in tracksBySide.entries) ...[
            // Side header (if applicable)
            if (tracksBySide.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Side ${entry.key}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

            // Tracks for this side
            ...entry.value.map((track) => _buildTrackRow(context, track, playbackState)),
          ],
        ],
      );
    } catch (e) {
      return _buildNoTracksState(context);
    }
  }

  /// Build a single track row
  Widget _buildTrackRow(BuildContext context, Track track, PlaybackState playbackState) {
    // Use enriched track from cache if available
    final trackId = _getTrackId(track);
    final displayTrack = _enrichedTracks[trackId] ?? track;

    final isCurrentTrack = playbackState.currentTrack?.position == displayTrack.position &&
        playbackState.currentTrack?.title == displayTrack.title;
    final isPlaying = isCurrentTrack && playbackState.isPlaying;
    final hasPreview = displayTrack.previewUrl != null && displayTrack.previewUrl!.isNotEmpty;
    final isLoadingPreview = _loadingTrackId == trackId;

    return InkWell(
      onTap: () async {
        // If currently playing, allow pause (even if still loading)
        if (isCurrentTrack && isPlaying) {
          await ref.read(playbackStateProvider.notifier).pause();
          return;
        }

        // If current track but paused, allow play
        if (isCurrentTrack && !isPlaying) {
          await ref.read(playbackStateProvider.notifier).play();
          return;
        }

        // If already has preview, just toggle play/pause
        if (hasPreview) {
          await ref.read(playbackStateProvider.notifier).togglePlayPause(displayTrack);
          return;
        }

        // If already loading, ignore tap
        if (isLoadingPreview) return;

        // Fetch preview and play
        setState(() {
          _loadingTrackId = trackId;
        });

        try {
          final enrichedTrack = await ref
              .read(playbackStateProvider.notifier)
              .fetchAndPlayTrack(displayTrack, widget.item);

          // Cache the enriched track
          if (mounted) {
            setState(() {
              _enrichedTracks[trackId] = enrichedTrack;
              _loadingTrackId = null;
            });
          }
        } catch (e) {
          print('[TrackOverlay] Error fetching preview: $e');
          if (mounted) {
            setState(() {
              _loadingTrackId = null;
            });
          }
        }
      },
      child: Container(
        // Highlight the playing track with a subtle background
        color: isCurrentTrack
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Track position
            SizedBox(
              width: 32,
              child: Text(
                displayTrack.position,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCurrentTrack ? Theme.of(context).colorScheme.primary : Colors.white54,
                    ),
              ),
            ),

            const SizedBox(width: 8),

            // Play/pause/loading icon
            SizedBox(
              width: 20,
              height: 20,
              child: (isLoadingPreview && !isPlaying)
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : Icon(
                      (hasPreview || isCurrentTrack)
                          ? (isPlaying ? Ionicons.pause_circle : Ionicons.play_circle)
                          : Ionicons.play_circle_outline,
                      size: 20,
                      color: (hasPreview || isCurrentTrack)
                          ? (isCurrentTrack
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withValues(alpha: 0.7))
                          : Colors.white.withValues(alpha: 0.3),
                    ),
            ),

            const SizedBox(width: 12),

            // Track title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTrack.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isCurrentTrack ? Theme.of(context).colorScheme.primary : null,
                          fontWeight: isCurrentTrack ? FontWeight.bold : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displayTrack.artist != null && displayTrack.artist != widget.item.artist)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        displayTrack.artist!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Show loading or "tap to load" hint
                  if (isLoadingPreview && !isPlaying)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Loading preview...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                              fontSize: 10,
                            ),
                      ),
                    )
                  else if (!hasPreview && !isCurrentTrack)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Tap to load preview',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white38,
                              fontStyle: FontStyle.italic,
                              fontSize: 10,
                            ),
                      ),
                    ),
                ],
              ),
            ),

            // Duration
            if (displayTrack.duration != null)
              Text(
                displayTrack.duration!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCurrentTrack
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white54,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
