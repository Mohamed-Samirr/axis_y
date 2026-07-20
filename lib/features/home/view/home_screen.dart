import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/catalog.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/home_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(sl<CatalogRepository>(), sl<AuthRepository>())..load(),
      child: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('AXIS Y', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(onPressed: () => context.go(Routes.explore), icon: const Icon(Icons.search)),
          _NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return switch (state) {
            HomeLoading() => const _HomeSkeleton(),
            HomeError(:final message) => ErrorView(message: context.tr(message), onRetry: () => context.read<HomeCubit>().load()),
            HomeLoaded() => _HomeContent(state: state),
          };
        },
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final unread = sl<NotificationRepository>().unreadCount;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(onPressed: () => context.push(Routes.notifications), icon: const Icon(Icons.notifications_outlined)),
        if (unread > 0)
          const Positioned(
            top: 12,
            right: 12,
            child: CircleAvatar(radius: 5, backgroundColor: AppColors.danger),
          ),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  final HomeLoaded state;
  const _HomeContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<HomeCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 12),
          _BannerSlider(banners: state.banners),
          const SizedBox(height: 20),
          const _CategoriesRow(),
          const SizedBox(height: 20),
          _SectionHeader(title: context.tr('picked_for_you')),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.pickedForYou.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ProductCard(product: state.pickedForYou[i]),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: context.tr('featured_stores')),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.stores.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _StoreCard(store: state.stores[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    );
  }
}

class _BannerSlider extends StatefulWidget {
  final List<AppBanner> banners;
  const _BannerSlider({required this.banners});

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      _index = (_index + 1) % widget.banners.length;
      _controller.animateToPage(_index, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.banners.length,
            itemBuilder: (_, i) {
              final b = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    if (b.productId != null) context.push('${Routes.product}/${b.productId}');
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(url: b.image, radius: BorderRadius.circular(16)),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        left: 16,
                        child: Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(color: active ? AppColors.navy : AppColors.divider, borderRadius: BorderRadius.circular(4)),
            );
          }),
        ),
      ],
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow();

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('cat_tops', '👕'),
      ('cat_pants', '👖'),
      ('cat_dresses', '👗'),
      ('cat_jackets', '🧥'),
      ('cat_new', '✨'),
      ('cat_bestseller', '🔥'),
    ];
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => context.go('${Routes.explore}?cat=${item.$1}'),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.07), shape: BoxShape.circle),
                  child: Center(child: Text(item.$2, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(height: 6),
                Text(context.tr(item.$1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          AppNetworkImage(url: store.logo, width: 52, height: 52, radius: BorderRadius.circular(26)),
          const SizedBox(height: 8),
          Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${store.productCount} ${context.tr('products_count')}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          RatingStars(rating: store.rating, size: 13),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerBox(height: 160),
        SizedBox(height: 20),
        ShimmerBox(height: 90),
        SizedBox(height: 20),
        ShimmerBox(height: 280),
      ],
    );
  }
}
