/// Migration script to update all items with type='vinyl' to type='music'
///
/// This script must be run using Flutter since it requires Firebase packages:
///   flutter run --release -d macos -t scripts/migrate_vinyl_to_music.dart [--dry-run]
///
/// Or run it from within the app as a one-time migration.
///
/// For now, this is a reference implementation. To actually run the migration:
/// 1. Add a temporary button in the app's debug/settings screen
/// 2. Call the migration function from there
/// 3. Remove the button after migration is complete
///
/// OR use Firebase Console to manually update the documents.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Migrates all items with type='vinyl' to type='music'
///
/// This should be called from within the running app (not as a standalone script)
/// due to Firebase initialization requirements.
Future<void> migrateVinylToMusic({
  required FirebaseFirestore firestore,
  required String userId,
  bool dryRun = false,
  Function(String)? onProgress,
}) async {
  final log = onProgress ?? print;

  log('========================================');
  log('Vinyl → Music Type Migration');
  log('========================================');
  if (dryRun) {
    log('MODE: DRY RUN (no changes will be made)');
  } else {
    log('MODE: LIVE (items will be updated)');
  }
  log('User ID: $userId');
  log('========================================\n');

  try {
    // Step 1: Get user's households only
    log('Step 1: Fetching your households...');
    log('DEBUG: User ID = $userId');
    log('DEBUG: Constructing query: households.where("members.$userId", whereIn: ["owner", "member", "viewer"])');

    QuerySnapshot householdsSnapshot;
    try {
      householdsSnapshot = await firestore
          .collection('households')
          .where('members.$userId', whereIn: ['owner', 'member', 'viewer'])
          .get();
      log('DEBUG: Query executed successfully');
      log('DEBUG: Number of documents returned: ${householdsSnapshot.docs.length}');
    } catch (queryError, queryStack) {
      log('❌ ERROR executing households query:');
      log('   Error: $queryError');
      log('   Stack: $queryStack');
      rethrow;
    }

    log('✅ Found ${householdsSnapshot.docs.length} household(s) you have access to\n');

    if (householdsSnapshot.docs.isEmpty) {
      log('⚠️  No households found. Migration complete.');
      log('DEBUG: This could mean:');
      log('  - You are not a member of any households');
      log('  - The members field structure is different than expected');
      log('  - There is a permissions issue');
      return;
    }

    // Step 2: Process each household
    var totalItemsFound = 0;
    var totalItemsUpdated = 0;
    var totalErrors = 0;

    for (var i = 0; i < householdsSnapshot.docs.length; i++) {
      final household = householdsSnapshot.docs[i];
      final householdId = household.id;
      final householdData = household.data() as Map<String, dynamic>;
      final householdName = householdData['name'] ?? 'Unnamed';

      log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      log('Processing household ${i + 1}/${householdsSnapshot.docs.length}');
      log('ID: $householdId');
      log('Name: $householdName');
      log('DEBUG: Household members: ${householdData['members']}');
      log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Query items with type='vinyl' in this household
      log('DEBUG: Querying for vinyl items in household $householdId...');
      QuerySnapshot musicItemsSnapshot;
      try {
        musicItemsSnapshot = await firestore
            .collection('households')
            .doc(householdId)
            .collection('items')
            .where('type', isEqualTo: 'vinyl')
            .get();
        log('DEBUG: Vinyl items query successful. Found ${musicItemsSnapshot.docs.length} items');
      } catch (itemQueryError) {
        log('❌ ERROR querying vinyl items: $itemQueryError');
        continue;
      }

      final itemCount = musicItemsSnapshot.docs.length;
      totalItemsFound += itemCount;

      if (itemCount == 0) {
        log('  No vinyl items found in this household\n');
        continue;
      }

      log('  Found $itemCount vinyl item(s)');

      // Update each item
      var householdUpdated = 0;
      var householdErrors = 0;

      for (var j = 0; j < musicItemsSnapshot.docs.length; j++) {
        final item = musicItemsSnapshot.docs[j];
        final itemId = item.id;
        final itemData = item.data() as Map<String, dynamic>;
        final itemTitle = itemData['title'] ?? 'Untitled';

        try {
          if (dryRun) {
            log('  [DRY RUN] Would update: $itemTitle (ID: $itemId)');
            householdUpdated++;
          } else {
            log('  Updating: $itemTitle (ID: $itemId)...');
            log('  DEBUG: Path = households/$householdId/items/$itemId');

            await firestore
                .collection('households')
                .doc(householdId)
                .collection('items')
                .doc(itemId)
                .update({
              'type': 'music',
              'lastModified': FieldValue.serverTimestamp(),
            });

            householdUpdated++;
            log('    ✅ Updated successfully');
          }
        } catch (e, stack) {
          log('    ❌ Error updating item: $e');
          log('    Stack: $stack');
          householdErrors++;
        }
      }

      totalItemsUpdated += householdUpdated;
      totalErrors += householdErrors;

      log('  Household summary: $householdUpdated updated, $householdErrors errors\n');
    }

    // Step 3: Final summary
    log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    log('MIGRATION SUMMARY');
    log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    log('Total households processed: ${householdsSnapshot.docs.length}');
    log('Total vinyl items found: $totalItemsFound');

    if (dryRun) {
      log('Total items that would be updated: $totalItemsUpdated');
    } else {
      log('Total items updated: $totalItemsUpdated');
    }

    log('Total errors: $totalErrors');
    log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    if (dryRun) {
      log('✅ Dry run complete. No changes were made.');
      log('   Call with dryRun: false to perform the migration.');
    } else if (totalErrors > 0) {
      log('⚠️  Migration complete with errors. Please review the output above.');
    } else {
      log('✅ Migration complete successfully!');
    }
  } catch (e, stackTrace) {
    log('\n❌ Fatal error during migration:');
    log('Error: $e');
    log('Stack trace: $stackTrace');
    rethrow;
  }
}
