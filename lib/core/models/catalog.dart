import 'package:equatable/equatable.dart';

enum ProductCategory { tops, pants, dresses, jackets }

extension ProductCategoryX on ProductCategory {
  String get key => switch (this) {
        ProductCategory.tops => 'cat_tops',
        ProductCategory.pants => 'cat_pants',
        ProductCategory.dresses => 'cat_dresses',
        ProductCategory.jackets => 'cat_jackets',
      };

  String get emoji => switch (this) {
        ProductCategory.tops => '👕',
        ProductCategory.pants => '👖',
        ProductCategory.dresses => '👗',
        ProductCategory.jackets => '🧥',
      };
}

class ProductColor extends Equatable {
  final String name;
  final int hex; // ARGB int
  final String image;

  const ProductColor({required this.name, required this.hex, required this.image});

  @override
  List<Object?> get props => [name, hex, image];
}

/// A single size option with its garment measurements (cm).
class ProductSize extends Equatable {
  final String label; // XS..XXL
  final int chest;
  final int waist;
  final int length;
  final bool available;

  const ProductSize({
    required this.label,
    required this.chest,
    required this.waist,
    required this.length,
    this.available = true,
  });

  @override
  List<Object?> get props => [label, chest, waist, length, available];
}

class Review extends Equatable {
  final String user;
  final double rating;
  final String text;
  final String date;
  final int helpful;

  const Review({
    required this.user,
    required this.rating,
    required this.text,
    required this.date,
    this.helpful = 0,
  });

  @override
  List<Object?> get props => [user, rating, text, date, helpful];
}

class Product extends Equatable {
  final String id;
  final String name;
  final String storeId;
  final String storeName;
  final double price;
  final double? oldPrice;
  final List<String> images;
  final List<ProductColor> colors;
  final List<ProductSize> sizes;
  final String material;
  final String description;
  final double rating;
  final int reviewCount;
  final ProductCategory category;
  final bool tryOnAvailable;
  final List<Review> reviews;
  final int soldCount;
  final bool isNew;
  final double deliveryFee;

  const Product({
    required this.id,
    required this.name,
    required this.storeId,
    required this.storeName,
    required this.price,
    this.oldPrice,
    required this.images,
    required this.colors,
    required this.sizes,
    required this.material,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.category,
    required this.tryOnAvailable,
    this.reviews = const [],
    this.soldCount = 0,
    this.isNew = false,
    this.deliveryFee = 40,
  });

  bool get isDiscounted => oldPrice != null && oldPrice! > price;

  @override
  List<Object?> get props => [id];
}

class Store extends Equatable {
  final String id;
  final String name;
  final String logo;
  final int productCount;
  final double rating;

  const Store({
    required this.id,
    required this.name,
    required this.logo,
    required this.productCount,
    required this.rating,
  });

  @override
  List<Object?> get props => [id];
}

class AppBanner extends Equatable {
  final String id;
  final String image;
  final String title;
  final String? productId;

  const AppBanner({required this.id, required this.image, required this.title, this.productId});

  @override
  List<Object?> get props => [id];
}
