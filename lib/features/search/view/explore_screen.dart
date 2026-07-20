import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/catalog.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/search_cubit.dart';
import 'widgets/filters_sheet.dart';

class ExploreScreen extends StatelessWidget {
  final String? initialCategoryKey;
  const ExploreScreen({super.key, this.initialCategoryKey});

  ProductCategory? get _initialCategory => switch (initialCategoryKey) {
        'cat_tops' => ProductCategory.tops,
        'cat_pants' => ProductCategory.pants,
        'cat_dresses' => ProductCategory.dresses,
        'cat_jackets' => ProductCategory.jackets,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(sl<CatalogRepository>(), sl<AuthRepository>())..load(initialCategory: _initialCategory),
      child: const _ExploreBody(),
    );
  }
}

class _ExploreBody extends StatefulWidget {
  const _ExploreBody();

  @override
  State<_ExploreBody> createState() => _ExploreBodyState();
}

class _ExploreBodyState extends State<_ExploreBody> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: TextField(
          controller: _controller,
          onChanged: (v) => context.read<SearchCubit>().setQuery(v),
          decoration: InputDecoration(
            hintText: context.tr('search_hint'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      context.read<SearchCubit>().setQuery('');
                      setState(() {});
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          ),
        ),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return Column(
            children: [
              _FilterBar(state: state),
              Expanded(child: _results(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _results(BuildContext context, SearchState state) {
    if (state.loading) return const ProductGridSkeleton();
    if (state.results.isEmpty) {
      return EmptyView(
        icon: Icons.search_off,
        title: context.tr('no_results'),
        subtitle: context.tr('no_results_hint'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            context.tr('found_n_products', args: {'n': '${state.results.length}'}),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: state.results.length,
            itemBuilder: (_, i) => ProductCard(product: state.results[i], width: double.infinity),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final SearchState state;
  const _FilterBar({required this.state});

  int get _activeCount {
    final f = state.filters;
    var c = 0;
    if (f.category != null) c++;
    if (f.price != null) c++;
    if (f.storeId != null) c++;
    if (f.minRating != null) c++;
    if (f.tryOnOnly == true) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () async {
              final cubit = context.read<SearchCubit>();
              final result = await showModalBottomSheet<SearchFilters>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FiltersSheet(current: state.filters, stores: state.stores),
              );
              if (result != null) cubit.setFilters(result);
            },
            icon: const Icon(Icons.tune, size: 18),
            label: Text('${context.tr('filters')}${_activeCount > 0 ? ' ($_activeCount)' : ''}'),
          ),
          const SizedBox(width: 8),
          if (_activeCount > 0)
            TextButton(onPressed: () => context.read<SearchCubit>().clearFilters(), child: Text(context.tr('clear'))),
        ],
      ),
    );
  }
}
