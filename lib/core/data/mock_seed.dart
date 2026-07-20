import '../models/catalog.dart';
import '../models/commerce.dart';
import '../models/notification.dart';
import '../models/user.dart';

/// Deterministic placeholder image from picsum (works as a network placeholder).
String _img(String seed) => 'https://picsum.photos/seed/$seed/600/750';
String _logo(String seed) => 'https://picsum.photos/seed/${seed}logo/200/200';

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

  static final List<Store> stores = [
    const Store(id: 's1', name: 'زاره مصر', logo: '', productCount: 240, rating: 4.6),
    const Store(id: 's2', name: 'كونكريت', logo: '', productCount: 180, rating: 4.4),
    const Store(id: 's3', name: 'دفاكتو', logo: '', productCount: 320, rating: 4.2),
    const Store(id: 's4', name: 'تاون تيم', logo: '', productCount: 150, rating: 4.7),
    const Store(id: 's5', name: 'مود', logo: '', productCount: 95, rating: 4.1),
    const Store(id: 's6', name: 'أوكسي جين', logo: '', productCount: 210, rating: 4.5),
  ].map((s) => Store(id: s.id, name: s.name, logo: _logo(s.id), productCount: s.productCount, rating: s.rating)).toList();

  static final List<AppBanner> banners = [
    AppBanner(id: 'b1', image: _img('banner1'), title: 'خصم 30% على التوبات'),
    AppBanner(id: 'b2', image: _img('banner2'), title: 'تشكيلة الصيف وصلت'),
    AppBanner(id: 'b3', image: _img('banner3'), title: 'جرب قبل ما تشتري'),
    AppBanner(id: 'b4', image: _img('banner4'), title: 'توصيل مجاني فوق 1000ج'),
  ];

  static final List<Review> _sampleReviews = [
    const Review(user: 'أحمد', rating: 5, text: 'الخامة ممتازة والمقاس مظبوط', date: '2026-06-12', helpful: 8),
    const Review(user: 'مريم', rating: 4, text: 'حلو بس اللون أغمق شوية من الصورة', date: '2026-06-01', helpful: 3),
    const Review(user: 'كريم', rating: 5, text: 'التجربة الافتراضية ساعدتني أختار المقاس', date: '2026-05-20', helpful: 12),
  ];

  static final List<Product> products = _buildProducts();

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
      final palette = palettes[i % palettes.length]
          .map((c) => ProductColor(name: c.name, hex: c.hex, image: _img('p${i}_${c.name}')))
          .toList();

      result.add(Product(
        id: 'p${i + 1}',
        name: name,
        storeId: store.id,
        storeName: store.name,
        price: price,
        oldPrice: oldPrice == 0 ? null : oldPrice,
        images: List.generate(3, (j) => _img('p${i + 1}_$j')),
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
