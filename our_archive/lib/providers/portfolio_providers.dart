import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/portfolio_repository.dart';
import '../data/models/portfolio_collection.dart';
import '../data/models/portfolio_photo.dart';

// Portfolio admin UID
const String portfolioAdminUid = '7gKizGf14jbphpxTftSlIbK6D3f2';

// Repository
final portfolioRepositoryProvider = Provider((ref) => PortfolioRepository());

// Collections stream
final portfolioCollectionsProvider =
    StreamProvider<List<PortfolioCollection>>((ref) {
  final repository = ref.watch(portfolioRepositoryProvider);
  return repository.getCollections();
});

// Photos in a specific collection
final portfolioPhotosProvider =
    StreamProvider.family<List<PortfolioPhoto>, String>((ref, collectionId) {
  final repository = ref.watch(portfolioRepositoryProvider);
  return repository.getPhotos(collectionId);
});

// Currently selected collection for navigation
final selectedPortfolioCollectionProvider =
    StateProvider<PortfolioCollection?>((ref) => null);

// Upload progress state
final portfolioUploadProgressProvider = StateProvider<double?>((ref) => null);
