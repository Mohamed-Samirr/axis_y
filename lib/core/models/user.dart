import 'package:equatable/equatable.dart';

class Measurements extends Equatable {
  final int chest;
  final int waist;
  final int hips;
  final int height;
  final int weight;

  const Measurements({
    required this.chest,
    required this.waist,
    required this.hips,
    required this.height,
    required this.weight,
  });

  /// Best-fitting standard size label for these measurements.
  String get recommendedSize {
    if (chest <= 86) return 'XS';
    if (chest <= 92) return 'S';
    if (chest <= 98) return 'M';
    if (chest <= 104) return 'L';
    if (chest <= 110) return 'XL';
    return 'XXL';
  }

  Map<String, dynamic> toJson() => {
        'chest': chest,
        'waist': waist,
        'hips': hips,
        'height': height,
        'weight': weight,
      };

  factory Measurements.fromJson(Map<String, dynamic> json) => Measurements(
        chest: json['chest'] as int,
        waist: json['waist'] as int,
        hips: json['hips'] as int,
        height: json['height'] as int,
        weight: json['weight'] as int,
      );

  @override
  List<Object?> get props => [chest, waist, hips, height, weight];
}

class Address extends Equatable {
  final String id;
  final String governorate;
  final String area;
  final String street;
  final String building;
  final String floor;
  final String apartment;

  const Address({
    required this.id,
    required this.governorate,
    required this.area,
    required this.street,
    required this.building,
    required this.floor,
    required this.apartment,
  });

  String get summary => '$street، $area، $governorate';

  Map<String, dynamic> toJson() => {
        'id': id,
        'governorate': governorate,
        'area': area,
        'street': street,
        'building': building,
        'floor': floor,
        'apartment': apartment,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        governorate: json['governorate'] as String,
        area: json['area'] as String,
        street: json['street'] as String,
        building: json['building'] as String,
        floor: json['floor'] as String,
        apartment: json['apartment'] as String,
      );

  @override
  List<Object?> get props => [id];
}

enum LoyaltyTier { regular, silver, gold, platinum }

extension LoyaltyTierX on LoyaltyTier {
  String get key => switch (this) {
        LoyaltyTier.regular => 'tier_regular',
        LoyaltyTier.silver => 'tier_silver',
        LoyaltyTier.gold => 'tier_gold',
        LoyaltyTier.platinum => 'tier_platinum',
      };

  int get threshold => switch (this) {
        LoyaltyTier.regular => 0,
        LoyaltyTier.silver => 1000,
        LoyaltyTier.gold => 5000,
        LoyaltyTier.platinum => 15000,
      };

  static LoyaltyTier fromPoints(int points) {
    if (points >= 15000) return LoyaltyTier.platinum;
    if (points >= 5000) return LoyaltyTier.gold;
    if (points >= 1000) return LoyaltyTier.silver;
    return LoyaltyTier.regular;
  }
}

class AppUser extends Equatable {
  final String id;
  final String name;
  final String phoneOrEmail;
  final int points;
  final Measurements? measurements;
  final List<Address> addresses;
  final String? avatarPath;

  const AppUser({
    required this.id,
    required this.name,
    required this.phoneOrEmail,
    this.points = 0,
    this.measurements,
    this.addresses = const [],
    this.avatarPath,
  });

  LoyaltyTier get tier => LoyaltyTierX.fromPoints(points);

  AppUser copyWith({
    String? name,
    int? points,
    Measurements? measurements,
    List<Address>? addresses,
    String? avatarPath,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        phoneOrEmail: phoneOrEmail,
        points: points ?? this.points,
        measurements: measurements ?? this.measurements,
        addresses: addresses ?? this.addresses,
        avatarPath: avatarPath ?? this.avatarPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phoneOrEmail': phoneOrEmail,
        'points': points,
        'measurements': measurements?.toJson(),
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'avatarPath': avatarPath,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        phoneOrEmail: json['phoneOrEmail'] as String,
        points: (json['points'] as int?) ?? 0,
        measurements: json['measurements'] == null
            ? null
            : Measurements.fromJson(json['measurements'] as Map<String, dynamic>),
        addresses: ((json['addresses'] as List?) ?? [])
            .map((a) => Address.fromJson(a as Map<String, dynamic>))
            .toList(),
        avatarPath: json['avatarPath'] as String?,
      );

  @override
  List<Object?> get props => [id, name, points, measurements, addresses, avatarPath];
}
