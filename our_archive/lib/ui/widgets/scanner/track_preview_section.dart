import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../data/models/track.dart';
import '../../../data/models/item.dart';
import '../../../providers/music_providers.dart';

/// A reusable widget for displaying track listings in scanner preview dialogs
/// Supports expandable/collapsible states, live preview playback, and handles loading/empty states
class TrackPreviewSection extends ConsumerStatefulWidget {
  final List<Track>? tracks;
  final bool isLoading;
  final VoidCallback? onLoadTracks;
  final Item? item; // Required for iTunes preview lookup

  const TrackPreviewSection({
    super.key,
    this.tracks,
    this.isLoading = false,
    this.onLoadTracks,
    this.item,
  });

  @override
  ConsumerState<TrackPreviewSection> createState() => _TrackPreviewSectionState();
}

class _TrackPreviewSectionState extends ConsumerState<TrackPreviewSection> {
  bool _isExpanded = false;
  String? _loadingTrackId; // Track which track is loading a preview
  final Map<String, Track> _enrichedTracks = {}; // Cache enriched tracks

  String _getTrackId(Track track) => '${track.position}_${track.title}';

  @override
  Widget build(BuildContext context) {
    // If loading, show loading state
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    // If no tracks and not loading, don't show anything
    if (widget.tracks == null || widget.tracks!.isEmpty) {
      return _buildEmptyState();
    }

    // Show expandable track section
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 12),
        _buildHeader(),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          _buildTrackList(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final trackCount = widget.tracks?.length ?? 0;

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              Ionicons.musical_notes_outline,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tracklist ($trackCount)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
              ),
            ),
            Icon(
              _isExpanded
                  ? Ionicons.chevron_up_outline
                  : Ionicons.chevron_down_outline,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading tracks...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Ionicons.musical_note_outline,
              size: 16,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Text(
              'No tracks available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTrackList() {
    if (widget.tracks == null || widget.tracks!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group tracks by side for vinyl
    final tracksBySide = <String, List<Track>>{};
    for (final track in widget.tracks!) {
      final side = track.side ?? 'All';
      tracksBySide.putIfAbsent(side, () => []).add(track);
    }

    final sides = tracksBySide.keys.toList()..sort();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sides.map((side) {
            final tracks = tracksBySide[side]!;
            return _buildSideSection(side, tracks, sides.length > 1);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSideSection(String side, List<Track> tracks, bool showSideHeader) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Side header (only show if there are multiple sides)
        if (showSideHeader) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Text(
              'Side $side',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
            ),
          ),
        ],
        // Track list
        ...tracks.map((track) => _buildTrackRow(track)),
      ],
    );
  }

  Widget _buildTrackRow(Track track) {
    final playbackState = ref.watch(playbackStateProvider);
    final trackId = _getTrackId(track);
    final displayTrack = _enrichedTracks[trackId] ?? track;

    final isCurrentTrack = playbackState.currentTrack?.position == displayTrack.position &&
        playbackState.currentTrack?.title == displayTrack.title;
    final isPlaying = isCurrentTrack && playbackState.isPlaying;
    final hasPreview = displayTrack.previewUrl != null && displayTrack.previewUrl!.isNotEmpty;
    final isLoadingPreview = _loadingTrackId == trackId;

    return InkWell(
      onTap: widget.item == null
          ? null
          : () async {
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
                    .fetchAndPlayTrack(displayTrack, widget.item!);

                // Cache the enriched track
                if (mounted) {
                  setState(() {
                    _enrichedTracks[trackId] = enrichedTrack;
                    _loadingTrackId = null;
                  });
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _loadingTrackId = null;
                  });
                }
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Position
            SizedBox(
              width: 50,
              child: Text(
                track.position,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isCurrentTrack
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600],
                      fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.w500,
                    ),
              ),
            ),
            // Play/pause/loading button
            if (widget.item != null)
              SizedBox(
                width: 32,
                height: 32,
                child: isLoadingPreview
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        hasPreview
                            ? (isPlaying ? Ionicons.pause_circle : Ionicons.play_circle)
                            : Ionicons.play_circle_outline,
                        size: 28,
                        color: hasPreview
                            ? (isCurrentTrack
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[700])
                            : Colors.grey[400],
                      ),
              ),
            if (widget.item != null) const SizedBox(width: 12),
            // Title and artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isCurrentTrack ? Theme.of(context).colorScheme.primary : null,
                          fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.w500,
                          fontSize: 15,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (track.artist != null && track.artist!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.artist!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Show "tap to preview" hint for tracks without preview
                  if (widget.item != null && !hasPreview && !isLoadingPreview)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tap to preview',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Duration
            if (track.duration != null && track.duration!.isNotEmpty)
              Text(
                track.duration!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
