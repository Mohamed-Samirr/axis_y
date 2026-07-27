import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_cubit.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderNotif = true;
  bool _offerNotif = true;
  bool _profilePublic = false;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context.tr('language')),
          Row(
            children: [
              Expanded(child: _langButton(context, 'العربية', 'ar', locale.languageCode == 'ar')),
              const SizedBox(width: 12),
              Expanded(child: _langButton(context, 'English', 'en', locale.languageCode == 'en')),
            ],
          ),
          const SizedBox(height: 20),
          _section(context.tr('notifications')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('status_shipping')),
            value: _orderNotif,
            activeThumbColor: AppColors.navy,
            onChanged: (v) => setState(() => _orderNotif = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('suggestion_of_day')),
            value: _offerNotif,
            activeThumbColor: AppColors.navy,
            onChanged: (v) => setState(() => _offerNotif = v),
          ),
          const SizedBox(height: 20),
          _section(context.tr('privacy')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('profile')),
            value: _profilePublic,
            activeThumbColor: AppColors.navy,
            onChanged: (v) => setState(() => _profilePublic = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, color: AppColors.navy),
            title: Text(context.tr('change_password')),
            onTap: () => _snack(context, 'change_password'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent, color: AppColors.navy),
            title: Text(context.tr('support')),
            onTap: () => _snack(context, 'support'),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: Text(context.tr('delete_account'), style: const TextStyle(color: AppColors.danger)),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _langButton(BuildContext context, String label, String code, bool selected) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.navy : null,
        foregroundColor: selected ? Colors.white : AppColors.navy,
      ),
      onPressed: () => context.read<LocaleCubit>().setLocale(code),
      child: Text(label),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('delete_account')),
        content: Text(context.tr('delete_account_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('clear'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await sl<AuthRepository>().logout();
              if (context.mounted) context.go(Routes.login);
            },
            child: Text(context.tr('delete_account'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String key) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
}
