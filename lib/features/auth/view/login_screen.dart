import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../cubit/auth_cubit.dart';
import 'widgets/social_buttons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(sl<AuthRepository>()),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().login(phoneOrEmail: _contact.text, password: _password.text);
    }
  }

  void _forgotPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('forgot_password')),
        content: Text(context.tr('otp_sub')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('verify')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('login'))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            context.go(Routes.home);
          } else if (state.status == AuthStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(state.error ?? 'error_generic'))));
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.loading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Text('AXIS Y', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppColors.navy)),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _contact,
                    decoration: InputDecoration(labelText: context.tr('phone_or_email')),
                    validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('field_required') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: context.tr('password')),
                    validator: (v) => (v == null || v.isEmpty) ? context.tr('field_required') : null,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(onPressed: () => _forgotPassword(context), child: Text(context.tr('forgot_password'))),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: loading ? null : () => _submit(context),
                    child: loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(context.tr('login_action')),
                  ),
                  const SizedBox(height: 12),
                  const SocialButtons(),
                  TextButton(
                    onPressed: () => context.go(Routes.register),
                    child: Text(context.tr('no_account')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
