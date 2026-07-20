import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/commerce.dart';
import '../../../core/repositories/assistant_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../cart_checkout/cubit/cart_cubit.dart';
import '../cubit/assistant_cubit.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssistantCubit(sl<AssistantRepository>()),
      child: const _AssistantBody(),
    );
  }
}

class _AssistantBody extends StatelessWidget {
  const _AssistantBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome, color: AppColors.gold), const SizedBox(width: 8), Text(context.tr('assistant'))]),
      ),
      body: BlocBuilder<AssistantCubit, AssistantState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.tr('what_to_wear'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: Occasion.values.map((o) {
                  final selected = state.occasion == o && state.outfit.isNotEmpty;
                  return ChoiceChip(
                    label: Text(context.tr(o.key)),
                    selected: selected,
                    onSelected: (_) => context.read<AssistantCubit>().suggest(o),
                    selectedColor: AppColors.navy,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.divider)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.read<AssistantCubit>().matchClothes(),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(context.tr('match_my_clothes')),
              ),
              const SizedBox(height: 20),
              if (state.loading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.navy)))
              else if (state.outfit.isNotEmpty)
                _OutfitResult(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _OutfitResult extends StatelessWidget {
  final AssistantState state;
  const _OutfitResult({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...state.outfit.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
              child: Row(
                children: [
                  AppNetworkImage(url: p.images.first, width: 64, height: 78, radius: BorderRadius.circular(10)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(p.storeName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(formatEgp(p.price), style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (p.tryOnAvailable)
                    TextButton(onPressed: () => context.push('${Routes.tryon}/${p.id}'), child: Text(context.tr('try_on_cta'))),
                ],
              ),
            )),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('outfit_total'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(formatEgp(state.total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.price, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            final cart = context.read<CartCubit>();
            for (final p in state.outfit) {
              final size = p.sizes.firstWhere((s) => s.available, orElse: () => p.sizes.first);
              cart.add(CartItem(product: p, color: p.colors.first, size: size.label));
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('added_to_cart'))));
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(context.tr('add_all_to_cart')),
        ),
      ],
    );
  }
}
