import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/offline/local_database.dart';
import '../../../../core/offline/offline_first_repository.dart';
import '../../../../core/offline/sync_manager.dart';
import '../models/product_model.dart';

class ProductRepository extends OfflineFirstRepository<ProductModel> {
  ProductRepository({
    required super.db,
    required super.syncManager,
    required super.apiClient,
    required super.connectivity,
  }) : super(entity: 'product');

  @override
  ProductModel fromJson(Map<String, dynamic> json) => ProductModel.fromJson(json);

  @override
  Map<String, dynamic> toJson(ProductModel p) => p.toJson();

  Future<Either<Failure, List<ProductModel>>> getAll({
    int page = 1,
    String? search,
    String? categoryId,
  }) =>
      fetchList(
        endpoint: ApiEndpoints.products,
        queryParams: {
          'page': page,
          if (search != null) 'search': search,
          if (categoryId != null) 'category_id': categoryId,
        },
        cacheKey: 'list:p$page:s${search ?? ''}:c${categoryId ?? ''}',
        cacheTtl: const Duration(hours: 2),
      );

  Future<Either<Failure, ProductModel>> getById(String id) =>
      fetchOne(endpoint: '${ApiEndpoints.products}/$id', id: id);

  Future<Either<Failure, ProductModel>> createProduct(ProductModel product) =>
      create(endpoint: ApiEndpoints.products, data: product, priority: 5);

  Future<Either<Failure, ProductModel>> updateProduct(String id, ProductModel product) =>
      update(endpoint: '${ApiEndpoints.products}/$id', id: id, data: product, priority: 5);

  Future<Either<Failure, void>> deleteProduct(String id) =>
      delete(endpoint: '${ApiEndpoints.products}/$id', id: id, priority: 3);
}

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    db: LocalDatabase.instance,
    syncManager: ref.read(syncManagerProvider),
    apiClient: ref.read(apiClientProvider),
    connectivity: ref.read(connectivityServiceProvider),
  );
});
