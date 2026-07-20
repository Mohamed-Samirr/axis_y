import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../cubit/auth_cubit.dart';
import 'widgets/social_buttons.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(sl<AuthRepository>()),
      child: const _RegisterBody(),
    );
  }
}

class _RegisterBody extends StatefulWidget {
  const _RegisterBody();

  @override
  State<_RegisterBody> createState() => _RegisterBodyState();
}

class _RegisterBodyState extends State<_RegisterBody> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().register(
            name: _name.text,
            phoneOrEmail: _contact.text,
            password: _password.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('register'))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success && state.otpRequired) {
            context.push(Routes.otp);
          } else if (state.status == AuthStatus.success) {
            // Social sign-in: session already saved, go straight in.
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
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: context.tr('full_name')),
                    validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('field_required') : null,
                  ),
                  const SizedBox(height: 14),
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
                    validator: (v) => (v == null || v.length < 8) ? context.tr('password_min') : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading ? null : () => _submit(context),
                    child: loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(context.tr('register_action')),
                  ),
                  const SizedBox(height: 12),
                  const SocialButtons(),
                  TextButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(context.tr('have_account')),
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
