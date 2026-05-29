import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final double sellingPrice;
  final double costPrice;
  final double stock;
  final String? unit;
  final String? categoryId;
  final String? warehouseId;
  final bool isActive;
  final bool isDirty; // true = has unsynced local changes

  const ProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.sellingPrice,
    required this.costPrice,
    required this.stock,
    this.unit,
    this.categoryId,
    this.warehouseId,
    this.isActive = true,
    this.isDirty = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
        costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String?,
        categoryId: json['category_id']?.toString(),
        warehouseId: json['warehouse_id']?.toString(),
        isActive: json['is_active'] as bool? ?? true,
        isDirty: json['_is_dirty'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'stock': stock,
        'unit': unit,
        'category_id': categoryId,
        'warehouse_id': warehouseId,
        'is_active': isActive,
      };

  @override
  List<Object?> get props => [id, name, sellingPrice, stock, isDirty];
}
