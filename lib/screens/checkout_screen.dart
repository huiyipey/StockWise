import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/saved_address.dart';
import '../services/address_book_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';
import 'orders_screen.dart';
import 'address_book_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartLine> lines;
  final AddressBookRepository? addressRepository;
  final String? initialName;
  final String? accountEmail;

  const CheckoutScreen({
    super.key,
    required this.lines,
    this.addressRepository,
    this.initialName,
    this.accountEmail,
  });

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
  String payment = 'Bank transfer';
  bool placing = false;
  late final repository =
      widget.addressRepository ?? AddressBookService.instance;
  StreamSubscription<AddressBook>? addressSubscription;
  AddressBook book = const AddressBook();
  String? selectedAddressId;
  bool userSelectedAddress = false;
  bool manualDetails = false;
  bool loadingAddresses = true;
  String? addressError;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text:
          widget.initialName ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '',
    );
    email = TextEditingController(
      text:
          widget.accountEmail ?? FirebaseAuth.instance.currentUser?.email ?? '',
    );
    addressSubscription = repository.watch().listen(
      (value) {
        if (!mounted) return;
        setState(() {
          book = value;
          loadingAddresses = false;
          addressError = null;
          final selected = book.find(selectedAddressId);
          if (!userSelectedAddress &&
              !manualDetails &&
              book.defaultAddress != null) {
            _fillAddress(book.defaultAddress!);
          } else if (selected != null && !manualDetails) {
            _fillAddress(selected);
          } else if (selectedAddressId != null && selected == null) {
            selectedAddressId = null;
            manualDetails = true;
          }
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            loadingAddresses = false;
            addressError =
                'Could not load saved addresses. Enter your delivery details below.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    addressSubscription?.cancel();
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    city.dispose();
    state.dispose();
    postalCode.dispose();
    super.dispose();
  }

  void _fillAddress(SavedAddress saved) {
    selectedAddressId = saved.id;
    manualDetails = false;
    name.text = saved.name;
    phone.text = saved.phone;
    address.text = saved.addressLine1;
    city.text = saved.city;
    state.text = saved.state;
    postalCode.text = saved.postalCode;
  }

  void _deliveryEdited(String _) {
    setState(() {
      userSelectedAddress = true;
      manualDetails = true;
      selectedAddressId = null;
    });
  }

  Future<void> _manageAddresses() async {
    final previousDefault = book.defaultAddress?.id;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressBookScreen(
          initialName: name.text,
          initialPhone: phone.text,
          repository: repository,
        ),
      ),
    );
    if (mounted &&
        !manualDetails &&
        book.defaultAddress != null &&
        previousDefault != book.defaultAddress!.id) {
      setState(() {
        userSelectedAddress = false;
        _fillAddress(book.defaultAddress!);
      });
    }
  }

  Widget _addressSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loadingAddresses) const LinearProgressIndicator(),
      if (addressError != null)
        Text(addressError!, style: const TextStyle(color: AppColors.danger)),
      if (book.addresses.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey(selectedAddressId ?? 'manual-address'),
          initialValue: selectedAddressId ?? 'manual-address',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Delivery address'),
          items: [
            ...book.addresses.map(
              (saved) => DropdownMenuItem(
                value: saved.id,
                child: Text(
                  '${saved.label}${book.defaultAddress?.id == saved.id ? ' (Default)' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const DropdownMenuItem(
              value: 'manual-address',
              child: Text('Enter address manually'),
            ),
          ],
          onChanged: placing
              ? null
              : (value) => setState(() {
                  final saved = book.find(value);
                  userSelectedAddress = true;
                  if (saved != null) {
                    _fillAddress(saved);
                  } else {
                    selectedAddressId = null;
                    manualDetails = true;
                    address.clear();
                    city.clear();
                    state.clear();
                    postalCode.clear();
                  }
                }),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: placing ? null : _manageAddresses,
          icon: const Icon(Icons.contact_mail_outlined),
          label: const Text('Manage addresses'),
        ),
      ),
    ],
  );

  int get subtotal =>
      widget.lines.fold<int>(0, (sum, line) => sum + line.lineTotalCents);
  int get shipping => 500;

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
                    'Delivery details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _addressSelector(),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-name'),
                    controller: name,
                    onChanged: _deliveryEdited,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-phone'),
                    controller: phone,
                    onChanged: _deliveryEdited,
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
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-address'),
                    controller: address,
                    onChanged: _deliveryEdited,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-city'),
                    controller: city,
                    onChanged: _deliveryEdited,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-state'),
                    controller: state,
                    onChanged: _deliveryEdited,
                    decoration: const InputDecoration(labelText: 'State'),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-postal'),
                    controller: postalCode,
                    onChanged: _deliveryEdited,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Postal code'),
                    validator: _required,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Bank transfer',
                        child: Text('Bank transfer'),
                      ),
                      DropdownMenuItem(
                        value: 'Touch n Go',
                        child: Text('Touch n Go'),
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
        fulfillmentType: 'delivery',
        paymentMethod: payment,
        receiver: {
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'email': email.text.trim(),
          'addressLine1': address.text.trim(),
          'city': city.text.trim(),
          'state': state.text.trim(),
          'postalCode': postalCode.text.trim(),
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
