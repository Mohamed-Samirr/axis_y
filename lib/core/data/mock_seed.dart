import '../models/catalog.dart';
import '../models/commerce.dart';
import '../models/notification.dart';
import '../models/user.dart';

/// Mock imagery comes from the Pexels CDN: each id is a photo picked to match
/// the garment it represents, so cards show real clothes instead of noise.
String _photo(int id, {int w = 600, int h = 750}) =>
    'https://images.pexels.com/photos/$id/pexels-photo-$id.jpeg'
    '?auto=compress&cs=tinysrgb&w=$w&h=$h&fit=crop';

String _logo(int id) => _photo(id, w: 200, h: 200);
String _banner(int id) => _photo(id, w: 900, h: 500);

/// Standard XS–XXL size ladder, scaled around a base chest measurement.
List<ProductSize> _sizes(int baseChest, {List<String> unavailable = const []}) {
  const ladder = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  return List.generate(ladder.length, (i) {
    final label = ladder[i];
    final chest = baseChest + i * 6;
    return ProductSize(
      label: label,
      chest: chest,
      waist: chest - 14,
      length: 62 + i * 3,
      available: !unavailable.contains(label),
    );
  });
}

const _colorNavy = ProductColor(name: 'كحلي', hex: 0xFF1B2A4A, image: '');
const _colorBlack = ProductColor(name: 'أسود', hex: 0xFF111111, image: '');
const _colorWhite = ProductColor(name: 'أبيض', hex: 0xFFF3F3F3, image: '');
const _colorBeige = ProductColor(name: 'بيج', hex: 0xFFD9C3A3, image: '');
const _colorOlive = ProductColor(name: 'زيتي', hex: 0xFF6B7345, image: '');
const _colorRed = ProductColor(name: 'أحمر', hex: 0xFFB23A48, image: '');

class MockSeed {
  static const defaultUser = AppUser(
    id: 'u1',
    name: 'مستخدم AXIS',
    phoneOrEmail: 'demo@axisy.eg',
    points: 250,
    measurements: Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74),
    addresses: [
      Address(
        id: 'a1',
        governorate: 'القاهرة',
        area: 'مدينة نصر',
        street: 'شارع عباس العقاد',
        building: '12',
        floor: '3',
        apartment: '9',
      ),
    ],
  );

  /// Storefront / boutique shots, one per store.
  static final List<Store> stores = [
    Store(id: 's1', name: 'زاره مصر', logo: _logo(8311880), productCount: 240, rating: 4.6),
    Store(id: 's2', name: 'كونكريت', logo: _logo(14534753), productCount: 180, rating: 4.4),
    Store(id: 's3', name: 'دفاكتو', logo: _logo(8386666), productCount: 320, rating: 4.2),
    Store(id: 's4', name: 'تاون تيم', logo: _logo(7679784), productCount: 150, rating: 4.7),
    Store(id: 's5', name: 'مود', logo: _logo(8387127), productCount: 95, rating: 4.1),
    Store(id: 's6', name: 'أوكسي جين', logo: _logo(7679742), productCount: 210, rating: 4.5),
  ];

  static final List<AppBanner> banners = [
    AppBanner(id: 'b1', image: _banner(30254262), title: 'خصم 30% على التوبات'),
    AppBanner(id: 'b2', image: _banner(33276443), title: 'تشكيلة الصيف وصلت'),
    AppBanner(id: 'b3', image: _banner(5622915), title: 'جرب قبل ما تشتري'),
    AppBanner(id: 'b4', image: _banner(5869619), title: 'توصيل مجاني فوق 1000ج'),
  ];

  static final List<Review> _sampleReviews = [
    const Review(user: 'أحمد', rating: 5, text: 'الخامة ممتازة والمقاس مظبوط', date: '2026-06-12', helpful: 8),
    const Review(user: 'مريم', rating: 4, text: 'حلو بس اللون أغمق شوية من الصورة', date: '2026-06-01', helpful: 3),
    const Review(user: 'كريم', rating: 5, text: 'التجربة الافتراضية ساعدتني أختار المقاس', date: '2026-05-20', helpful: 12),
  ];

  static final List<Product> products = _buildProducts();

  /// Three Pexels photo ids per product, in the same order as [_buildProducts]'s
  /// table. Each row was picked from a search for that exact garment.
  static const List<List<int>> _productPhotos = [
    [4115035, 9775889, 4066288], // تيشيرت قطن سادة
    [6103704, 1635596, 23547651], // قميص كاجوال مقلم
    [11751211, 12980904, 7648372], // بولو كلاسيك
    [11340657, 6551385, 7236120], // هودي أوفر سايز
    [8217314, 7824049, 9558716], // تيشيرت أوفر سايز مطبوع
    [5191435, 5149729, 7129369], // قميص كتان صيفي
    [5319513, 1634839, 6009198], // سويت شيرت بغطاء
    [32695898, 16996376, 20594780], // تيشيرت رياضي دراي فت

    [10133278, 6764142, 1082526], // بنطلون جينز سليم
    [9724757, 8350481, 9464625], // بنطلون تشينو بيج
    [11716436, 5365474, 12384601], // بنطلون كارجو
    [10133275, 10133273, 2129970], // جينز واسع
    [13339846, 8250137, 8121927], // بنطلون قماش رسمي
    [4195453, 4725152, 3093834], // شورت جينز
    [9901666, 34272485, 10392342], // بنطلون رياضي جوجر
    [7748773, 7593007, 6246487], // ليجن رياضي

    [5637456, 4589213, 6675408], // فستان صيفي زهور
    [1655841, 6234213, 13252124], // فستان سواريه
    [14452577, 14452587, 5362702], // فستان كاجوال ميدي
    [9119608, 13262239, 8633713], // فستان قطن يومي
    [5160503, 8060452, 5675268], // فستان محتشم واسع
    [4614881, 20544951, 25731827], // فستان دنيم
    [6235477, 12163542, 6234225], // فستان مخمل شتوي

    [12083001, 6770027, 5524406], // جاكيت جينز
    [12455995, 5350007, 5236973], // جاكيت بمبر
    [11124953, 7691041, 8484005], // بليزر رسمي
    [12345554, 9566118, 10785431], // جاكيت جلد
    [9603630, 8989555, 9603626], // كارديجان صوف
    [7147889, 7147891, 6084430], // بافي جاكيت شتوي
    [8454520, 6175641, 10385757], // جاكيت رياضي خفيف
    [13973198, 6533889, 5263493], // ترنش كوت
    [4014487, 10059068, 5120186], // جاكيت صوف كاجوال
  ];

  static List<Product> _buildProducts() {
    final result = <Product>[];
    final data = <List<Object>>[
      // name, category, price, oldPrice(0=none), storeIndex, baseChest, tryOn, sold, isNew
      ['تيشيرت قطن سادة', ProductCategory.tops, 299.0, 399.0, 0, 88, true, 320, false],
      ['قميص كاجوال مقلم', ProductCategory.tops, 549.0, 0.0, 1, 90, true, 140, true],
      ['بولو كلاسيك', ProductCategory.tops, 420.0, 0.0, 3, 92, true, 210, false],
      ['هودي أوفر سايز', ProductCategory.tops, 720.0, 899.0, 5, 96, true, 95, true],
      ['تيشيرت أوفر سايز مطبوع', ProductCategory.tops, 349.0, 0.0, 2, 94, true, 260, false],
      ['قميص كتان صيفي', ProductCategory.tops, 610.0, 0.0, 0, 90, true, 60, true],
      ['سويت شيرت بغطاء', ProductCategory.tops, 680.0, 780.0, 4, 98, false, 45, false],
      ['تيشيرت رياضي دراي فت', ProductCategory.tops, 380.0, 0.0, 5, 88, true, 175, false],

      ['بنطلون جينز سليم', ProductCategory.pants, 780.0, 999.0, 2, 84, true, 300, false],
      ['بنطلون تشينو بيج', ProductCategory.pants, 650.0, 0.0, 3, 86, true, 130, false],
      ['بنطلون كارجو', ProductCategory.pants, 720.0, 0.0, 1, 88, true, 110, true],
      ['جينز واسع', ProductCategory.pants, 690.0, 0.0, 0, 86, true, 90, false],
      ['بنطلون قماش رسمي', ProductCategory.pants, 830.0, 950.0, 4, 84, false, 40, false],
      ['شورت جينز', ProductCategory.pants, 410.0, 0.0, 2, 84, true, 200, false],
      ['بنطلون رياضي جوجر', ProductCategory.pants, 470.0, 0.0, 5, 86, true, 240, false],
      ['ليجن رياضي', ProductCategory.pants, 350.0, 420.0, 5, 80, true, 150, true],

      ['فستان صيفي زهور', ProductCategory.dresses, 890.0, 1100.0, 0, 84, true, 180, true],
      ['فستان سواريه', ProductCategory.dresses, 1450.0, 0.0, 4, 86, true, 55, false],
      ['فستان كاجوال ميدي', ProductCategory.dresses, 720.0, 0.0, 1, 84, true, 120, false],
      ['فستان قطن يومي', ProductCategory.dresses, 560.0, 690.0, 3, 82, true, 210, false],
      ['فستان محتشم واسع', ProductCategory.dresses, 980.0, 0.0, 5, 88, true, 70, true],
      ['فستان دنيم', ProductCategory.dresses, 640.0, 0.0, 2, 84, true, 95, false],
      ['فستان مخمل شتوي', ProductCategory.dresses, 1150.0, 1350.0, 0, 86, false, 30, false],

      ['جاكيت جينز', ProductCategory.jackets, 890.0, 0.0, 2, 96, true, 140, false],
      ['جاكيت بمبر', ProductCategory.jackets, 1050.0, 1290.0, 1, 98, true, 85, true],
      ['بليزر رسمي', ProductCategory.jackets, 1350.0, 0.0, 4, 100, true, 40, false],
      ['جاكيت جلد', ProductCategory.jackets, 1890.0, 2200.0, 0, 100, true, 25, true],
      ['كارديجان صوف', ProductCategory.jackets, 760.0, 0.0, 5, 98, false, 60, false],
      ['بافي جاكيت شتوي', ProductCategory.jackets, 1420.0, 1650.0, 3, 102, true, 50, false],
      ['جاكيت رياضي خفيف', ProductCategory.jackets, 690.0, 0.0, 5, 96, true, 130, false],
      ['ترنش كوت', ProductCategory.jackets, 1580.0, 0.0, 4, 100, true, 20, true],
      ['جاكيت صوف كاجوال', ProductCategory.jackets, 980.0, 1150.0, 1, 98, true, 35, false],
    ];

    final palettes = [
      [_colorNavy, _colorBlack, _colorWhite],
      [_colorBeige, _colorOlive, _colorBlack],
      [_colorRed, _colorWhite, _colorNavy],
      [_colorBlack, _colorBeige, _colorNavy],
    ];

    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final name = row[0] as String;
      final category = row[1] as ProductCategory;
      final price = row[2] as double;
      final oldPrice = row[3] as double;
      final storeIndex = row[4] as int;
      final baseChest = row[5] as int;
      final tryOn = row[6] as bool;
      final sold = row[7] as int;
      final isNew = row[8] as bool;
      final store = stores[storeIndex];
      final photos = [for (final id in _productPhotos[i]) _photo(id)];
      // Colour swatches reuse the product's own shots so they stay on-garment.
      final palette = [
        for (final (j, c) in palettes[i % palettes.length].indexed)
          ProductColor(name: c.name, hex: c.hex, image: photos[j % photos.length]),
      ];

      result.add(Product(
        id: 'p${i + 1}',
        name: name,
        storeId: store.id,
        storeName: store.name,
        price: price,
        oldPrice: oldPrice == 0 ? null : oldPrice,
        images: photos,
        colors: palette,
        sizes: _sizes(baseChest, unavailable: i % 4 == 0 ? const ['XXL'] : const []),
        material: category == ProductCategory.jackets ? 'بوليستر / قطن' : 'قطن 100%',
        description: 'قطعة $name بخامة مريحة ومناسبة للاستخدام اليومي. غسيل على 30 درجة.',
        rating: 3.8 + (i % 7) * 0.15,
        reviewCount: 20 + (sold ~/ 5),
        category: category,
        tryOnAvailable: tryOn,
        reviews: _sampleReviews,
        soldCount: sold,
        isNew: isNew,
        deliveryFee: 40,
      ));
    }
    return result;
  }

  static final List<AppNotification> notifications = [
    const AppNotification(
      id: 'n1',
      title: 'طلبك في الطريق 🚚',
      body: 'أوردر #10234 هيوصلك النهارده',
      type: NotificationType.order,
      date: '2026-07-20',
    ),
    const AppNotification(
      id: 'n2',
      title: 'عرض خاص ليك 🎉',
      body: 'خصم 25% على الجاكيتات لمدة يومين',
      type: NotificationType.offer,
      date: '2026-07-19',
    ),
    const AppNotification(
      id: 'n3',
      title: 'نزل سعر منتج في مفضلتك 💚',
      body: 'فستان صيفي زهور بقى بخصم',
      type: NotificationType.priceDrop,
      date: '2026-07-18',
    ),
    const AppNotification(
      id: 'n4',
      title: 'كسبت 200 نقطة ⭐',
      body: 'مبروك على أول عملية شراء',
      type: NotificationType.points,
      date: '2026-07-15',
      read: true,
    ),
  ];

  static List<AppOrder> orders() => [
        AppOrder(
          id: '10234',
          date: '2026-07-18',
          status: OrderStatus.shipping,
          total: 1180,
          lines: [
            OrderLine(productName: products[0].name, image: products[0].images.first, size: 'M', color: 'كحلي', qty: 1, price: 299),
            OrderLine(productName: products[8].name, image: products[8].images.first, size: 'L', color: 'أسود', qty: 1, price: 780),
          ],
        ),
        AppOrder(
          id: '10221',
          date: '2026-07-05',
          status: OrderStatus.delivered,
          total: 890,
          lines: [
            OrderLine(productName: products[16].name, image: products[16].images.first, size: 'S', color: 'أحمر', qty: 1, price: 890),
          ],
        ),
        AppOrder(
          id: '10198',
          date: '2026-06-22',
          status: OrderStatus.cancelled,
          total: 470,
          lines: [
            OrderLine(productName: products[14].name, image: products[14].images.first, size: 'M', color: 'كحلي', qty: 1, price: 470),
          ],
        ),
      ];

  /// Loyalty earning rules (label key -> points).
  static const List<(String, int)> earnRules = [
    ('أول عملية شراء', 200),
    ('كل 100 جنيه', 10),
    ('كتابة تقييم', 50),
    ('دعوة صديق', 150),
    ('إكمال ملف الجسم', 100),
    ('تسجيل دخول يومي', 5),
  ];
}
