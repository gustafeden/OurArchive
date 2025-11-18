import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Test script to check what iTunes has for an artist/album
/// Usage: dart scripts/test_itunes_search.dart "Artist Name" "Album Name"
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart scripts/test_itunes_search.dart "Artist Name" ["Album Name"]');
    print('Examples:');
    print('  dart scripts/test_itunes_search.dart "Leonard Cohen"');
    print('  dart scripts/test_itunes_search.dart "Leonard Cohen" "I\'m Your Man"');
    exit(1);
  }

  final artistName = args[0];
  final albumName = args.length > 1 ? args[1] : null;

  print('========================================');
  print('iTunes Search Test');
  print('========================================');
  print('Artist: $artistName');
  if (albumName != null) {
    print('Album: $albumName');
  }
  print('========================================\n');

  try {
    final results = await searchItunes(artistName, albumName);
    displayResults(results, artistName, albumName);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<Map<String, dynamic>> searchItunes(String artist, String? album) async {
  final searchTerms = <String>[artist];
  if (album != null) {
    searchTerms.add(album);
  }

  final queryParams = {
    'term': searchTerms.join(' '),
    'entity': 'song',
    'limit': '200',
  };

  final uri = Uri.parse('https://itunes.apple.com/search')
      .replace(queryParameters: queryParams);

  print('Querying iTunes API...');
  print('URL: $uri\n');

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  return json.decode(response.body) as Map<String, dynamic>;
}

void displayResults(Map<String, dynamic> data, String artist, String? album) {
  final results = data['results'] as List<dynamic>?;

  if (results == null || results.isEmpty) {
    print('❌ No results found!');
    print('\nThis means iTunes has no tracks for this search.');
    return;
  }

  print('✅ Found ${results.length} results\n');

  // Group by collection (album)
  final byCollection = <String, List<Map<String, dynamic>>>{};

  for (final result in results) {
    final trackMap = result as Map<String, dynamic>;
    final collectionName = trackMap['collectionName'] as String? ?? 'Unknown Album';
    byCollection.putIfAbsent(collectionName, () => []);
    byCollection[collectionName]!.add(trackMap);
  }

  print('Found ${byCollection.length} different albums/collections:\n');

  // Display each collection
  var collectionNum = 1;
  for (final entry in byCollection.entries) {
    final collectionName = entry.key;
    final tracks = entry.value;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('$collectionNum. $collectionName');
    print('   Tracks: ${tracks.length}');

    if (tracks.isNotEmpty) {
      final firstTrack = tracks.first;
      print('   Artist: ${firstTrack['artistName']}');
      print('   Release: ${firstTrack['releaseDate']?.toString().substring(0, 4) ?? 'Unknown'}');
      print('   Collection ID: ${firstTrack['collectionId']}');
    }

    final tracksWithPreviews = tracks.where((t) =>
      t['previewUrl'] != null && (t['previewUrl'] as String).isNotEmpty
    ).length;

    print('   Previews: $tracksWithPreviews/${tracks.length}');

    if (tracksWithPreviews > 0) {
      print('   ✅ HAS PREVIEWS');
    } else {
      print('   ❌ NO PREVIEWS');
    }

    print('');
    print('   Track List:');
    for (var i = 0; i < tracks.length && i < 10; i++) {
      final track = tracks[i];
      final trackName = track['trackName'] ?? 'Unknown';
      final hasPreview = track['previewUrl'] != null &&
                        (track['previewUrl'] as String).isNotEmpty;
      final icon = hasPreview ? '✅' : '❌';
      final trackNum = track['trackNumber'] ?? '?';

      print('      $icon ${trackNum.toString().padLeft(2)}. $trackName');
    }

    if (tracks.length > 10) {
      print('      ... and ${tracks.length - 10} more tracks');
    }

    print('');
    collectionNum++;
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Summary
  final totalTracks = results.length;
  final tracksWithPreviews = results.where((r) {
    final track = r as Map<String, dynamic>;
    return track['previewUrl'] != null &&
           (track['previewUrl'] as String).isNotEmpty;
  }).length;

  print('SUMMARY:');
  print('========================================');
  print('Total tracks found: $totalTracks');
  print('Tracks with previews: $tracksWithPreviews (${ (tracksWithPreviews / totalTracks * 100).toStringAsFixed(1)}%)');
  print('Tracks without previews: ${totalTracks - tracksWithPreviews}');

  if (tracksWithPreviews == 0) {
    print('\n⚠️  iTunes has NO previews available for this artist/album');
    print('This is likely a licensing/regional restriction.');
  } else if (tracksWithPreviews < totalTracks / 2) {
    print('\n⚠️  iTunes has limited preview availability');
  } else {
    print('\n✅ Good preview availability!');
  }
}
