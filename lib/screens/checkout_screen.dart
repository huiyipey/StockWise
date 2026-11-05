import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/saved_address.dart';
import '../models/store_address.dart';
import '../services/address_book_service.dart';
import '../services/customer_postcode_controller.dart';
import '../services/firestore_service.dart';
import '../services/postcode_lookup.dart';
import '../services/profile_fields.dart';
import '../services/store_fields.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/order_ui.dart';
import '../widgets/commerce_quote.dart';
import '../widgets/customer_ui.dart';
import 'order_detail_screen.dart';
import 'address_book_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.lines,
    this.addressRepository,
    this.initialName,
    this.accountEmail,
    this.placeOrder,
    this.onPlaced,
    this.quoteLoader,
    this.acceptedPromotionReviewToken,
    this.lookupPostcode = MalaysianPostcodes.lookup,
  });
  final List<CartLine> lines;
  final AddressBookRepository? addressRepository;
  final String? initialName, accountEmail;
  final Future<String> Function(Map<String, dynamic>, String)? placeOrder;
  final VoidCallback? onPlaced;
  final Future<Map<String, dynamic>> Function(String)? quoteLoader;
  final String? acceptedPromotionReviewToken;
  final PostcodeLookup lookupPostcode;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final scroll = ScrollController();
  final anchors = <String, GlobalKey>{};
  late final TextEditingController name, email;
  final phone = TextEditingController();
  final address = TextEditingController();
  final address2 = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final postalCode = TextEditingController();
  late final CustomerPostcodeController location;
  String payment = 'Bank transfer';
  bool placing = false;
  Map<String, dynamic>? quote;
  String? quoteError;
  bool quoting = false;
  Timer? quoteDebounce;
  int quoteRevision = 0;
  String? acceptedPromotionReviewToken;
  bool get usesQuote => widget.quoteLoader != null || widget.placeOrder == null;
  Future<void> refreshQuote() async {
    if (!usesQuote) return;
    final revision = ++quoteRevision;
    setState(() {
      quoting = true;
      quoteError = null;
    });
    try {
      final value =
          await (widget.quoteLoader ??
              (code) => FirestoreService.instance.quoteCart(code))(
            postalCode.text.trim(),
          );
      if (mounted && revision == quoteRevision) setState(() => quote = value);
    } catch (e) {
      if (mounted && revision == quoteRevision) {
        setState(() {
          quote = null;
          quoteError = e is StateError
              ? e.message.toString()
              : 'Could not calculate your order. Please refresh.';
        });
      }
    } finally {
      if (mounted && revision == quoteRevision) setState(() => quoting = false);
    }
  }

  void scheduleQuote() {
    if (!usesQuote) return;
    quoteDebounce?.cancel();
    quoteRevision++;
    quoting = true;
    quoteDebounce = Timer(const Duration(milliseconds: 350), refreshQuote);
  }

  late final repository =
      widget.addressRepository ?? AddressBookService.instance;
  StreamSubscription<AddressBook>? addressSubscription;
  AddressBook book = const AddressBook();
  String? selectedAddressId, addressError, placementError;
  bool userSelectedAddress = false,
      manualDetails = false,
      loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    location = CustomerPostcodeController(
      postcode: postalCode,
      city: city,
      state: state,
      lookup: widget.lookupPostcode,
    )..addListener(locationChanged);
    acceptedPromotionReviewToken = widget.acceptedPromotionReviewToken;
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
    if (usesQuote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshQuote();
      });
    }
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
            fillAddress(book.defaultAddress!);
          } else if (selected != null && !manualDetails) {
            fillAddress(selected);
          } else if (selectedAddressId != null && selected == null) {
            selectedAddressId = null;
            manualDetails = true;
          }
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            loadingAddresses = false;
            addressError =
                'Could not load saved addresses. Enter delivery details manually.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    addressSubscription?.cancel();
    quoteDebounce?.cancel();
    location.dispose();
    scroll.dispose();
    for (final controller in [
      name,
      email,
      phone,
      address,
      address2,
      city,
      state,
      postalCode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void fillAddress(SavedAddress saved) {
    selectedAddressId = saved.id;
    manualDetails = false;
    name.text = saved.name;
    phone.text = saved.phone;
    address.text = saved.addressLine1;
    address2.text = saved.addressLine2;
    city.text = saved.city;
    state.text = saved.state;
    postalCode.text = saved.postalCode;
    unawaited(location.loadExisting());
    scheduleQuote();
  }

  void locationChanged() {
    if (mounted) setState(() {});
  }

  void deliveryEdited(String _) => setState(() {
    userSelectedAddress = true;
    manualDetails = true;
    selectedAddressId = null;
    scheduleQuote();
  });

  Future<void> manageAddresses() async {
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
        fillAddress(book.defaultAddress!);
      });
    }
  }

  Future<void> chooseAddress() async {
    final selected = await showOrderChoices(
      context: context,
      title: 'Delivery address',
      choices: {
        for (final saved in book.addresses)
          saved.id:
              '${saved.label}${book.defaultAddress?.id == saved.id ? ' (Default)' : ''}',
        'manual-address': 'Enter address manually',
      },
      selected: selectedAddressId ?? 'manual-address',
    );
    if (!mounted || selected == null) return;
    setState(() {
      userSelectedAddress = true;
      final saved = book.find(selected);
      if (saved != null) {
        fillAddress(saved);
      } else {
        selectedAddressId = null;
        manualDetails = true;
        address.clear();
        address2.clear();
        postalCode.clear();
        location.invalidate();
        scheduleQuote();
      }
    });
  }

  Future<void> choosePayment() async {
    final selected = await showOrderChoices(
      context: context,
      title: 'Payment method',
      choices: const {
        'Bank transfer': 'Bank transfer',
        'Touch n Go': 'Touch n Go',
      },
      selected: payment,
    );
    if (mounted && selected != null) setState(() => payment = selected);
  }

  int get subtotal =>
      (quote?['subtotalCents'] as num?)?.toInt() ??
      widget.lines.fold<int>(0, (sum, line) => sum + line.lineTotalCents);
  int get shipping =>
      (quote?['deliveryFeeCents'] as num?)?.toInt() ?? (usesQuote ? 0 : 500);
  bool get canPlace =>
      !location.lookingUp &&
      (!usesQuote ||
          (!quoting &&
              quoteError == null &&
              quote != null &&
              quote?['deliveryFeeCents'] != null));

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => PopScope(
        canPop: !placing,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                InventoryHeader(
                  title: 'Checkout',
                  back: true,
                  onBack: placing ? null : () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      key: const ValueKey('checkout-scroll'),
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (addressError != null) ...[
                          OrderNotice(addressError!, error: true),
                          const SizedBox(height: 16),
                        ],
                        OrderPanel(
                          padding: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Delivery details',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 22),
                              if (loadingAddresses) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(height: 16),
                              ],
                              OrderPickerField(
                                label: 'Delivery address',
                                value: selectedAddressId == null
                                    ? 'Enter address manually'
                                    : '${book.find(selectedAddressId)?.label ?? 'Saved address'}${book.defaultAddress?.id == selectedAddressId ? ' (Default)' : ''}',
                                onTap: placing ? null : chooseAddress,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: placing ? null : manageAddresses,
                                  child: const Text(
                                    'Manage addresses',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              field('name', 'Name', name),
                              field(
                                'phone',
                                'Phone',
                                phone,
                                keyboard: TextInputType.phone,
                                hint: 'e.g. 012-345 6789 or +60 12-345 6789',
                              ),
                              field(
                                'email',
                                'Email',
                                email,
                                keyboard: TextInputType.emailAddress,
                              ),
                              field(
                                'address',
                                'Address 1',
                                address,
                                hint: 'Unit / house number and street',
                                keyboard: TextInputType.streetAddress,
                                maxLines: 3,
                                maxLength: 200,
                              ),
                              field(
                                'address2',
                                'Address 2 (Optional)',
                                address2,
                                hint: 'Building, floor or area',
                                keyboard: TextInputType.streetAddress,
                                maxLines: 2,
                                maxLength: 200,
                              ),
                              field(
                                'postal',
                                'Postcode',
                                postalCode,
                                keyboard: TextInputType.number,
                                hint: 'e.g. 47500',
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                onChanged: (value) {
                                  location.changed(value);
                                  deliveryEdited(value);
                                },
                                suffix: location.lookingUp
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : location.ready
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: InventoryColors.green,
                                        size: 20,
                                      )
                                    : null,
                              ),
                              if (location.lookingUp)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    'Finding city and state…',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: InventoryColors.muted,
                                    ),
                                  ),
                                ),
                              if (location.lookupFailed)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: placing ? null : location.retry,
                                    child: const Text('Retry lookup'),
                                  ),
                                ),
                              field(
                                'city',
                                'City',
                                city,
                                hint: 'From postcode',
                                enabled: location.ready,
                                maxLength: 80,
                              ),
                              field(
                                'state',
                                'State',
                                state,
                                hint: 'From postcode',
                                readOnly: true,
                                suffix: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: InventoryColors.muted,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Text(
                                  'State is filled from your postcode and cannot be edited.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: InventoryColors.muted,
                                  ),
                                ),
                              ),
                              OrderPickerField(
                                key: const ValueKey('checkout-payment'),
                                label: 'Payment method',
                                value: payment,
                                onTap: placing ? null : choosePayment,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (usesQuote && quoting)
                          const Center(child: CircularProgressIndicator()),
                        if (usesQuote) QuoteLines(quote: quote),
                        if (!usesQuote || quote != null)
                          OrderTotals(
                            subtotal: subtotal,
                            delivery:
                                usesQuote && quote?['deliveryFeeCents'] == null
                                ? null
                                : shipping,
                          ),
                        if (quote?['deliveryFeeCents'] == null && usesQuote)
                          const Text(
                            'Delivery fee: unavailable until a supported postcode is entered.',
                          ),
                        if (quote?['deliveryFeeCents'] == null &&
                            quote?['message'] != null)
                          const OrderNotice(
                            'Delivery is not configured for this postcode. Please contact the store.',
                            error: true,
                          ),
                        if (quoteError != null)
                          OrderNotice(quoteError!, error: true),
                        if (usesQuote) ...[
                          TextButton.icon(
                            onPressed: quoting || placing ? null : refreshQuote,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Order Total'),
                          ),
                        ],
                        if (placementError != null) ...[
                          const SizedBox(height: 18),
                          OrderNotice(placementError!, error: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: InventoryColors.line)),
              ),
              child: InventoryButton(
                key: const ValueKey('place-order'),
                label: placing ? 'Placing order...' : 'Place Order',
                busy: placing,
                onPressed: canPlace ? place : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget field(
    String id,
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? hint,
    int? maxLength,
    int maxLines = 1,
    bool enabled = true,
    bool readOnly = false,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) => Padding(
    key: anchors.putIfAbsent(id, () => GlobalKey()),
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      key: ValueKey('checkout-$id'),
      controller: controller,
      enabled: !placing && enabled,
      readOnly: readOnly,
      onChanged: readOnly
          ? null
          : onChanged ?? (id == 'email' ? null : deliveryEdited),
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 13),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'Enter ${label.toLowerCase()}',
        counterText: '',
        suffixIcon: suffix,
        errorText: id == 'postal' ? location.error : null,
        errorMaxLines: 3,
      ),
      validator: (value) => fieldError(id, value),
    ),
  );

  StoreAddress get structuredAddress => StoreAddress(
    line1: address.text,
    line2: address2.text,
    postcode: postalCode.text,
    city: city.text,
    state: state.text,
  );

  String? fieldError(String id, String? value) {
    switch (id) {
      case 'name':
        return profileNameError(value);
      case 'phone':
        return addressPhoneError(value);
      case 'address':
        return addressLineError(value);
      case 'address2':
        final lineError = addressLineError(value, required: false);
        if (lineError != null) return lineError;
        if (location.ready &&
            addressLineError(address.text) == null &&
            cityError(city.text) == null) {
          return shopAddressError(structuredAddress.formatted);
        }
        return null;
      case 'city':
        return cityError(value) ??
            (RegExp(r'[\r\n]').hasMatch(value ?? '')
                ? 'Enter a valid city'
                : null);
      case 'postal':
        return postcodeError(value) ??
            location.error ??
            (!location.ready && !location.lookingUp
                ? 'Enter a valid postcode to fill City and State.'
                : null);
      case 'email':
        return addressRequired(value) ??
            (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
                ? 'Enter a valid email.'
                : null);
      default:
        return addressRequired(value);
    }
  }

  Future<void> place() async {
    if (placing || !canPlace) return;
    if (!(formKey.currentState?.validate() ?? false)) {
      final invalid =
          {
                'name': name,
                'phone': phone,
                'email': email,
                'address': address,
                'address2': address2,
                'postal': postalCode,
                'city': city,
                'state': state,
              }.entries
              .where((entry) => fieldError(entry.key, entry.value.text) != null)
              .firstOrNull;
      final anchor = anchors[invalid?.key]?.currentContext;
      if (anchor != null) {
        await Scrollable.ensureVisible(
          anchor,
          alignment: .1,
          duration: const Duration(milliseconds: 240),
        );
      }
      return;
    }
    setState(() {
      placing = true;
      placementError = null;
    });
    final receiver = <String, dynamic>{
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
      'addressLine1': address.text.trim(),
      'addressLine2': address2.text.trim(),
      'city': city.text.trim(),
      'state': state.text.trim(),
      'postalCode': postalCode.text.trim(),
      'countryCode': 'MY',
    };
    try {
      if (usesQuote) {
        await refreshQuote();
        if (!mounted) return;
        if (quote == null ||
            quoteError != null ||
            quote?['deliveryFeeCents'] == null) {
          throw StateError(
            quoteError ?? 'Refresh your order and check the delivery postcode.',
          );
        }
        if (promotionWarnings(quote).isNotEmpty &&
            (acceptedPromotionReviewToken == null ||
                acceptedPromotionReviewToken !=
                    quote?['promotionReviewToken'])) {
          final reviewedQuote = quote!;
          final reviewedToken = reviewedQuote['promotionReviewToken'];
          final reviewedTotal = reviewedQuote['totalCents'];
          setState(() => placing = false);
          final accepted = await confirmUnavailablePromotions(
            context,
            reviewedQuote,
            includesDelivery: true,
          );
          if (!mounted) return;
          if (!accepted) {
            if (Navigator.canPop(context)) Navigator.pop(context);
            return;
          }
          if (quote?['promotionReviewToken'] != reviewedToken ||
              quote?['totalCents'] != reviewedTotal) {
            throw StateError(
              'Your order changed while you were reviewing it. Please review the latest total and try again.',
            );
          }
          acceptedPromotionReviewToken = reviewedToken as String?;
          setState(() => placing = true);
        }
      }
      final orderId =
          await (widget.placeOrder ??
              (receiver, payment) => FirestoreService.instance.placeOrder(
                fulfillmentType: 'delivery',
                paymentMethod: payment,
                receiver: receiver,
                expectedTotalCents: (quote?['totalCents'] as num?)?.toInt(),
                acceptedPromotionReviewToken: acceptedPromotionReviewToken,
              ))(receiver, payment);
      if (!mounted) return;
      showCustomerFeedback(context, 'Order placed successfully');
      if (widget.onPlaced != null) {
        widget.onPlaced!();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PlacedOrderReceiptPage(orderId: orderId),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        if (usesQuote) unawaited(refreshQuote());
        if (error is StateError &&
            error.message.toString().startsWith('Ordering is closed')) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ordering Unavailable'),
              content: Text(error.message.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
        setState(
          () => placementError = error is StateError
              ? error.message
              : 'Could not place the order. Please try again.',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scroll.hasClients) {
            scroll.animateTo(
              scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => placing = false);
    }
  }
}

class PlacedOrderReceiptPage extends StatefulWidget {
  const PlacedOrderReceiptPage({super.key, required this.orderId});
  final String orderId;
  @override
  State<PlacedOrderReceiptPage> createState() => _PlacedOrderReceiptPageState();
}

class _PlacedOrderReceiptPageState extends State<PlacedOrderReceiptPage> {
  late Future<StoreOrder?> order = FirestoreService.instance.getOrder(
    widget.orderId,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<StoreOrder?>(
    future: order,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return OrderDetailScreen(
          order: snapshot.data!,
          isAdmin: false,
          openReceipt: true,
        );
      }
      return InventoryTheme(
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                InventoryHeader(
                  title: 'Order Details',
                  back: true,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Your order was placed. Could not open its receipt page yet.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                InventoryButton(
                                  label: 'Retry',
                                  onPressed: () => setState(
                                    () => order = FirestoreService.instance
                                        .getOrder(widget.orderId),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
