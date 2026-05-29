import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/offline/offline_first_repository.dart';
import '../../data/models/product_model.dart';

/// Offline support is automatic — no offline code here.
/// [OfflineInterceptor] handles caching and queuing transparently.
class ProductRepository extends OfflineFirstRepository<ProductModel> {
  ProductRepository(super.apiClient);

  @override
  ProductModel fromJson(Map<String, dynamic> json) => ProductModel.fromJson(json);

  Future<Either<Failure, List<ProductModel>>> getAll({int page = 1, String? search, String? categoryId}) =>
      getList('/inventory/products', params: {
        'page': page,
        if (search != null) 'search': search,
        if (categoryId != null) 'category_id': categoryId,
      });

  Future<Either<Failure, ProductModel>> getById(String id) => getOne('/inventory/products/$id');

  Future<Either<Failure, ProductModel>> save(ProductModel p) => p.id.isEmpty
      ? post('/inventory/products', p.toJson())
      : put('/inventory/products/${p.id}', p.toJson());

  Future<Either<Failure, void>> remove(String id) => destroy('/inventory/products/$id');
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.read(apiClientProvider)),
);
