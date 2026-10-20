import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';
import 'orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartLine> lines;

  const CheckoutScreen({super.key, required this.lines});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController email;
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final postalCode = TextEditingController();
  String fulfillment = 'pickup';
  String payment = 'Maybank';
  bool placing = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    name = TextEditingController(text: user?.displayName ?? '');
    email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    city.dispose();
    state.dispose();
    postalCode.dispose();
    super.dispose();
  }

  int get subtotal =>
      widget.lines.fold<int>(0, (sum, line) => sum + line.lineTotalCents);
  int get shipping => fulfillment == 'delivery' ? 500 : 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(title: 'Checkout', leading: BackCircleButton()),
          Expanded(
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    'Fulfillment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  RadioGroup<String>(
                    groupValue: fulfillment,
                    onChanged: (value) =>
                        setState(() => fulfillment = value ?? 'pickup'),
                    child: const Column(
                      children: [
                        RadioListTile(value: 'pickup', title: Text('Pickup')),
                        RadioListTile(
                          value: 'delivery',
                          title: Text('Delivery'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Receiver',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _required,
                  ),
                  if (fulfillment == 'delivery') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: city,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: state,
                      decoration: const InputDecoration(labelText: 'State'),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: postalCode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Postal code',
                      ),
                      validator: _required,
                    ),
                  ],
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Maybank',
                        child: Text('Maybank'),
                      ),
                      DropdownMenuItem(
                        value: 'Touch n Go',
                        child: Text('Touch n Go'),
                      ),
                      DropdownMenuItem(
                        value: 'Pay at pickup',
                        child: Text('Pay at pickup'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => payment = value ?? payment),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _line('Subtotal', subtotal),
                          _line('Shipping', shipping),
                          const Divider(),
                          _line('Total', subtotal + shipping, bold: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: placing ? null : _placeOrder,
                    child: Text(placing ? 'PLACING ORDER...' : 'PLACE ORDER'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _line(String label, int cents, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          'RM ${(cents / 100).toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: bold ? AppColors.primaryDark : null,
          ),
        ),
      ],
    ),
  );

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _placeOrder() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => placing = true);
    try {
      await FirestoreService.instance.placeOrder(
        fulfillmentType: fulfillment,
        paymentMethod: payment,
        receiver: {
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'email': email.text.trim(),
          'addressLine1': fulfillment == 'delivery' ? address.text.trim() : '',
          'city': fulfillment == 'delivery' ? city.text.trim() : '',
          'state': fulfillment == 'delivery' ? state.text.trim() : '',
          'postalCode': fulfillment == 'delivery' ? postalCode.text.trim() : '',
          'countryCode': 'MY',
        },
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen(isAdmin: false)),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => placing = false);
    }
  }
}
