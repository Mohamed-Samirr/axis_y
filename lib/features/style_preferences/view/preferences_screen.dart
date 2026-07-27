import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

/// 4 quick chip questions. Choices persist locally and mark onboarding complete.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Map<String, String> _answers = {};

  static const _questions = <String, List<String>>{
    'prefs_colors': ['pref_color_vivid', 'pref_color_calm', 'pref_color_both'],
    'prefs_style': ['pref_style_casual', 'pref_style_formal', 'pref_style_sport', 'pref_style_fashion'],
    'prefs_shops': ['pref_shop_tops', 'pref_shop_pants', 'pref_shop_dresses', 'pref_shop_jackets', 'pref_shop_everything'],
    'prefs_freq': ['pref_freq_daily', 'pref_freq_weekly', 'pref_freq_monthly', 'pref_freq_occasions'],
  };

  void _finish() {
    sl<LocalStore>().setJson(StoreKeys.preferences, _answers);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('prefs_title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final entry in _questions.entries) ...[
            Text(context.tr(entry.key), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: entry.value.map((option) {
                final selected = _answers[entry.key] == option;
                return ChoiceChip(
                  label: Text(context.tr(option)),
                  selected: selected,
                  onSelected: (_) => setState(() => _answers[entry.key] = option),
                  selectedColor: AppColors.navy,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _finish, child: Text(context.tr('start_shopping'))),
        ],
      ),
    );
  }
}
