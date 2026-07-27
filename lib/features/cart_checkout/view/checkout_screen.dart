import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../cubit/cart_cubit.dart';

enum PayMethod { fawry, card, instapay, cod }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _step = 0;
  PayMethod _method = PayMethod.cod;
  final _promo = TextEditingController();
  double _discount = 0;
  bool _placing = false;

  Address? get _address => sl<AuthRepository>().currentUser?.addresses.firstOrNull;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  void _applyPromo() {
    setState(() => _discount = _promo.text.trim().isEmpty ? 0 : 50);
    if (_discount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('promo_applied', args: {'amount': formatEgp(50)}))),
      );
    }
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartCubit>();
    setState(() => _placing = true);
    final total = cart.state.subtotal + cart.state.deliveryFee - _discount;
    final result = await sl<OrderRepository>().placeOrder(cart.state.items, total);
    if (!mounted) return;
    result.when(
      success: (order) {
        // Award loyalty points: 200 first-time base + 10 per 100 EGP.
        final auth = sl<AuthRepository>();
        final user = auth.currentUser;
        if (user != null) {
          final earned = (total / 100).floor() * 10 + (user.points == 0 ? 200 : 0);
          auth.saveUser(user.copyWith(points: user.points + earned));
        }
        cart.clear();
        context.go(Routes.orderSuccess, extra: order);
      },
      failure: (m) {
        setState(() => _placing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(m))));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    final total = cart.subtotal + cart.deliveryFee - _discount;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('checkout'))),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (s) => setState(() => _step = s),
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: Text(context.tr('address')),
            isActive: _step >= 0,
            content: _AddressStep(address: _address, onNext: () => setState(() => _step = 1)),
          ),
          Step(
            title: Text(context.tr('payment')),
            isActive: _step >= 1,
            content: _PaymentStep(
              method: _method,
              onChanged: (m) => setState(() => _method = m),
              onNext: () => setState(() => _step = 2),
            ),
          ),
          Step(
            title: Text(context.tr('review_order')),
            isActive: _step >= 2,
            content: _ReviewStep(
              total: total,
              subtotal: cart.subtotal,
              delivery: cart.deliveryFee,
              discount: _discount,
              promo: _promo,
              onApplyPromo: _applyPromo,
              placing: _placing,
              onConfirm: _placeOrder,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  final Address? address;
  final VoidCallback onNext;
  const _AddressStep({required this.address, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (address != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.navy),
                const SizedBox(width: 10),
                Expanded(child: Text(address!.summary)),
              ],
            ),
          )
        else
          Text(context.tr('add_new_address'), style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: Text(context.tr('add_new_address'))),
        ElevatedButton(onPressed: onNext, child: Text(context.tr('next'))),
      ],
    );
  }
}

class _PaymentStep extends StatelessWidget {
  final PayMethod method;
  final ValueChanged<PayMethod> onChanged;
  final VoidCallback onNext;
  const _PaymentStep({required this.method, required this.onChanged, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final options = <(PayMethod, String, IconData)>[
      (PayMethod.fawry, context.tr('pay_fawry'), Icons.qr_code),
      (PayMethod.card, context.tr('pay_card'), Icons.credit_card),
      (PayMethod.instapay, context.tr('pay_instapay'), Icons.account_balance),
      (PayMethod.cod, context.tr('pay_cod'), Icons.local_shipping_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...options.map((o) {
          final selected = method == o.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(o.$1),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.navy.withValues(alpha: 0.06) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AppColors.navy : AppColors.divider, width: selected ? 1.6 : 1),
                ),
                child: Row(
                  children: [
                    Icon(o.$3, size: 20, color: AppColors.navy),
                    const SizedBox(width: 10),
                    Text(o.$2),
                    const Spacer(),
                    if (selected) const Icon(Icons.check_circle, color: AppColors.navy, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        ElevatedButton(onPressed: onNext, child: Text(context.tr('next'))),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final double total;
  final double subtotal;
  final double delivery;
  final double discount;
  final TextEditingController promo;
  final VoidCallback onApplyPromo;
  final bool placing;
  final VoidCallback onConfirm;

  const _ReviewStep({
    required this.total,
    required this.subtotal,
    required this.delivery,
    required this.discount,
    required this.promo,
    required this.onApplyPromo,
    required this.placing,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: promo,
                decoration: InputDecoration(hintText: context.tr('promo_code')),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onApplyPromo, child: Text(context.tr('apply'))),
          ],
        ),
        const SizedBox(height: 16),
        _row(context.tr('subtotal'), formatEgp(subtotal)),
        _row(context.tr('delivery_fee'), formatEgp(delivery)),
        if (discount > 0) _row(context.tr('promo_code'), '- ${formatEgp(discount)}'),
        const Divider(),
        _row(context.tr('total'), formatEgp(total), bold: true),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: placing ? null : onConfirm,
          child: placing
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(context.tr('confirm_pay')),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 17 : 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: bold ? AppColors.price : AppColors.textPrimary, fontSize: bold ? 17 : 14)),
        ],
      ),
    );
  }
}
