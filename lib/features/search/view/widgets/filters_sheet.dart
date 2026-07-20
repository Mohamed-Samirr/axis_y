import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/catalog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../cubit/search_cubit.dart';

/// Bottom sheet for search filters. Returns a [SearchFilters] on apply.
class FiltersSheet extends StatefulWidget {
  final SearchFilters current;
  final List<Store> stores;

  const FiltersSheet({super.key, required this.current, required this.stores});

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late SearchFilters _f = widget.current;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scroll,
            children: [
              Center(
                child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(context.tr('filters'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              _label(context.tr('categories')),
              Wrap(
                spacing: 8,
                children: ProductCategory.values.map((c) {
                  return _chip(
                    context.tr(c.key),
                    _f.category == c,
                    () => setState(() => _f = _f.category == c ? _f.copyWith(clearCategory: true) : _f.copyWith(category: c)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              _label(context.tr('price')),
              Wrap(
                spacing: 8,
                children: PriceRange.all.map((p) {
                  return _chip(
                    p.label,
                    _f.price?.label == p.label,
                    () => setState(() => _f = _f.price?.label == p.label ? _f.copyWith(clearPrice: true) : _f.copyWith(price: p)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              _label(context.tr('store')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.stores.map((s) {
                  return _chip(
                    s.name,
                    _f.storeId == s.id,
                    () => setState(() => _f = _f.storeId == s.id ? _f.copyWith(clearStore: true) : _f.copyWith(storeId: s.id)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              _label(context.tr('rating')),
              Wrap(
                spacing: 8,
                children: [3.0, 4.0].map((r) {
                  return _chip(
                    '$r+ ★',
                    _f.minRating == r,
                    () => setState(() => _f = _f.minRating == r ? _f.copyWith(clearRating: true) : _f.copyWith(minRating: r)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('tryon_available')),
                value: _f.tryOnOnly ?? false,
                activeThumbColor: AppColors.navy,
                onChanged: (v) => setState(() => _f = _f.copyWith(tryOnOnly: v)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _f = const SearchFilters()),
                      child: Text(context.tr('clear')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _f),
                      child: Text(context.tr('apply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.navy,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.divider)),
    );
  }
}
