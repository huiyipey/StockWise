import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/order_status.dart';
import '../models/category_label.dart';
import '../services/firestore_service.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/order_receipt.dart';
import '../widgets/order_ui.dart';
import '../widgets/stockwise_ui.dart' show ProductArtwork;
import 'item_detail_screen.dart';
import 'admin_item_detail_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    this.isAdmin = true,
    this.orderLinesStream,
    this.productLookup,
    this.liveUpdates = true,
    this.orderUpdates,
    this.saveStatus,
    this.pickReceipt,
    this.uploadReceipt,
    this.receiptImage,
    this.saveCancellation,
    this.openReceipt = false,
  });
  final StoreOrder order;
  final bool isAdmin, liveUpdates, openReceipt;
  final Stream<List<OrderLine>>? orderLinesStream;
  final Stream<StoreOrder?>? orderUpdates;
  final Future<InventoryBatch?> Function(OrderLine)? productLookup;
  final Future<void> Function(StoreOrder, String)? saveStatus;
  final Future<void> Function(StoreOrder, String)? saveCancellation;
  final Future<XFile?> Function()? pickReceipt;
  final Future<String> Function(XFile, String)? uploadReceipt;
  final Future<ImageProvider> Function(String)? receiptImage;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late StoreOrder order = widget.order;
  late String status = order.status;
  late String? receiptPath = order.receiptPath;
  bool saving = false, uploadingReceipt = false, pickingReceipt = false;
  bool allowPop = false, missing = false;
  String? openingLineId,
      saveError,
      receiptError,
      updateNotice,
      savedCancellationReason;
  final scroll = ScrollController();
  bool receiptRevealed = false;
  StreamSubscription<StoreOrder?>? subscription;
  late Stream<List<OrderLine>> lines = watchLines().map((value) {
    if (widget.openReceipt && !receiptRevealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !scroll.hasClients || receiptRevealed) return;
        receiptRevealed = true;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return value;
  });
  bool get dirty => widget.isAdmin && status != order.status;
  bool get busy => saving || uploadingReceipt || pickingReceipt;
  bool get hasReceipt => receiptPath?.trim().isNotEmpty == true;
  Stream<List<OrderLine>> watchLines() =>
      widget.orderLinesStream ??
      FirestoreService.instance.watchOrderLines(order.id);

  @override
  void initState() {
    super.initState();
    if (widget.liveUpdates) {
      subscription =
          (widget.orderUpdates ??
                  FirestoreService.instance.watchOrder(order.id))
              .listen(
                (value) {
                  if (!mounted) return;
                  setState(() {
                    missing = value == null;
                    if (value == null) return;
                    if (value.status != order.status) {
                      status = value.status;
                      if (!saving) {
                        updateNotice =
                            'This order was updated. Review its current status.';
                      }
                    }
                    order = value;
                    receiptPath = value.receiptPath;
                  });
                },
                onError: (Object _) {
                  if (mounted) {
                    setState(
                      () => updateNotice =
                          'Live updates are unavailable. Refresh the order before making changes.',
                    );
                  }
                },
              );
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => PopScope(
        canPop: allowPop || (!dirty && !busy),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                InventoryHeader(
                  title: 'Order Details',
                  back: true,
                  onBack: leave,
                ),
                Expanded(
                  child: StreamBuilder<List<OrderLine>>(
                    stream: lines,
                    builder: (context, snapshot) => ListView(
                      key: const ValueKey('order-details-scroll'),
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        if (missing)
                          const OrderNotice(
                            'This order is no longer available.',
                            error: true,
                          ),
                        if (updateNotice != null) ...[
                          OrderNotice(updateNotice!),
                          const SizedBox(height: 16),
                        ],
                        OrderPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${order.orderNumber}',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OrderBadge(
                                    orderLabel(order.paymentStatus),
                                    value: order.paymentStatus,
                                    fontSize: 12,
                                  ),
                                  OrderBadge(
                                    orderLabel(order.status),
                                    value: order.status,
                                    fontSize: 12,
                                  ),
                                ],
                              ),
                              const Divider(height: 30),
                              OrderValueRow(
                                'Placed',
                                DateFormat(
                                  'd MMM yyyy, HH:mm',
                                ).format(order.placedAt),
                              ),
                              OrderValueRow(
                                'Fulfillment',
                                orderLabel(order.fulfillmentType),
                              ),
                              OrderValueRow(
                                'Payment Method',
                                order.payment['methodLabel'] as String? ?? '-',
                              ),
                            ],
                          ),
                        ),
                        const OrderHeading('Items'),
                        Builder(
                          builder: (context) {
                            if (snapshot.hasError) {
                              return OrderPanel(
                                child: Column(
                                  children: [
                                    const Text(
                                      'Could not load order items. Please try again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 18),
                                    InventoryButton(
                                      label: 'Retry',
                                      icon: Icons.refresh_rounded,
                                      onPressed: () =>
                                          setState(() => lines = watchLines()),
                                    ),
                                  ],
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const OrderPanel(
                                child: Padding(
                                  padding: EdgeInsets.all(25),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (snapshot.data!.isEmpty) {
                              return const OrderPanel(
                                child: Text(
                                  'No items found for this order.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (final line in snapshot.data!)
                                  lineCard(line),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        OrderTotals(
                          subtotal: order.subtotalCents,
                          delivery: order.shippingFeeCents,
                        ),
                        const OrderHeading('Receiver'),
                        OrderPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receiver('name'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                receiver('phone'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: InventoryColors.muted,
                                ),
                              ),
                              Text(
                                receiver('email'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: InventoryColors.muted,
                                ),
                              ),
                              if (deliveryAddress.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  deliveryAddress,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const OrderHeading('Payment Receipt'),
                        OrderReceipt(
                          orderNumber: order.orderNumber,
                          isAdmin: widget.isAdmin,
                          path: receiptPath,
                          busy: uploadingReceipt || pickingReceipt,
                          onUpload: missing ? null : upload,
                          imageResolver: widget.receiptImage,
                        ),
                        if (uploadingReceipt) ...[
                          const SizedBox(height: 16),
                          const OrderNotice(
                            'Uploading your receipt. Please wait.',
                          ),
                        ],
                        if (receiptError != null) ...[
                          const SizedBox(height: 16),
                          OrderNotice(receiptError!, error: true),
                        ],
                        if (widget.isAdmin) ...[
                          const OrderHeading('Order Status'),
                          OrderPickerField(
                            key: const ValueKey('order-status'),
                            value: orderLabel(status),
                            onTap: busy || missing ? null : chooseStatus,
                          ),
                          if ((savedCancellationReason ??
                                      order.cancellationReason)
                                  ?.isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: OrderNotice(
                                'Cancellation Reason: ${savedCancellationReason ?? order.cancellationReason}',
                              ),
                            ),
                          if (saveError != null) ...[
                            const SizedBox(height: 16),
                            OrderNotice(saveError!, error: true),
                          ],
                        ] else ...[
                          if (order.cancellationReason?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: OrderNotice(
                                'Cancellation Reason: ${order.cancellationReason}',
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: widget.isAdmin
              ? SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: InventoryColors.line),
                      ),
                    ),
                    child: InventoryButton(
                      key: const ValueKey('save-order'),
                      label: saving ? 'Saving...' : 'Save Order',
                      busy: saving,
                      onPressed: dirty && !busy && !missing ? save : null,
                    ),
                  ),
                )
              : null,
        ),
      ),
    ),
  );

  String receiver(String key) =>
      (order.receiver[key] as String?)?.trim().isNotEmpty == true
      ? order.receiver[key] as String
      : '-';
  String get deliveryAddress => [
    order.receiver['addressLine1'],
    order.receiver['addressLine2'],
    [
      order.receiver['postalCode'],
      order.receiver['city'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' '),
    order.receiver['state'],
  ].where((v) => v != null && '$v'.trim().isNotEmpty).join(', ');

  Widget lineCard(OrderLine line) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey('order-line-${line.id}'),
        onTap: openingLineId != null || busy ? null : () => openProduct(line),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArtwork(size: 72, imagePath: line.imagePath),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${line.quantity} ${line.unitLabel} · ${categoryTitleCase(line.categoryId.replaceAll('_', ' '))}\nExp: ${DateFormat('d MMM yyyy').format(line.expiryAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: InventoryColors.muted,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                orderMoney(line.lineTotalCents),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: InventoryColors.green,
                                ),
                              ),
                              if ((line.regularUnitPriceCents ??
                                      line.unitPriceCents) >
                                  line.unitPriceCents)
                                Text(
                                  orderMoney(
                                    line.regularUnitPriceCents! * line.quantity,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: InventoryColors.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        openingLineId == line.id
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: InventoryColors.muted,
                              ),
                      ],
                    ),
                    if (line.promotionLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          line.promotionLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: InventoryColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> chooseStatus() async {
    final disabled = <String, String>{};
    for (final next in orderStatuses) {
      final error = orderStatusError(
        order.status,
        next,
        hasReceipt: hasReceipt,
      );
      if (error != null) disabled[next] = error;
    }
    final value = await showOrderChoices(
      context: context,
      title: 'Order Status',
      choices: {for (final value in orderStatuses) value: orderLabel(value)},
      selected: status,
      disabled: disabled,
    );
    if (mounted && value != null) {
      setState(() {
        status = value;
        saveError = null;
      });
    }
  }

  Future<void> leave() async {
    if (busy) return;
    if (dirty &&
        !await showOrderConfirmation(
          context: context,
          title: 'Discard status change?',
          message: 'Your order status change has not been saved.',
          action: 'Discard',
          danger: true,
        )) {
      return;
    }
    if (mounted) {
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.maybePop(context);
    }
  }

  Future<void> save() async {
    if (busy || !dirty || missing) return;
    final current = order;
    final next = status;
    final validation = orderStatusError(
      current.status,
      next,
      hasReceipt: hasReceipt,
    );
    if (validation != null) {
      setState(() => saveError = validation);
      return;
    }
    final cancel = next == 'cancelled';
    String? cancellationReason;
    if (cancel) {
      final reasonController = TextEditingController();
      final key = GlobalKey<FormState>();
      cancellationReason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Cancellation Reason'),
          content: Form(
            key: key,
            child: TextFormField(
              key: const ValueKey('cancellation-reason'),
              controller: reasonController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Why is this order being cancelled?',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter a cancellation reason.'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Order'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(context, reasonController.text.trim());
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      reasonController.dispose();
      if (cancellationReason == null || !mounted) return;
    }
    if (!await showOrderConfirmation(
      context: context,
      title: cancel ? 'Cancel this order?' : 'Save order status?',
      message: cancel
          ? 'Cancel #${order.orderNumber}? Its ordered quantities will be returned to inventory.\nReason: $cancellationReason'
          : 'Update #${order.orderNumber} from ${orderLabel(order.status)} to ${orderLabel(next)}.',
      action: cancel ? 'Cancel order' : 'Save status',
      cancel: cancel ? 'Keep order' : 'Keep editing',
      danger: cancel,
    )) {
      return;
    }
    if (!mounted) return;
    if (order.status != current.status) {
      setState(
        () => saveError =
            'This order changed. Review its current status before saving.',
      );
      return;
    }
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      if (cancel && widget.saveCancellation != null) {
        await widget.saveCancellation!(current, cancellationReason!);
      } else if (widget.saveStatus != null) {
        await widget.saveStatus!(current, next);
      } else {
        await FirestoreService.instance.updateOrderStatus(
          current,
          next,
          reason: cancellationReason,
        );
      }
      if (mounted) {
        setState(() {
          order = StoreOrder(
            id: order.id,
            orderNumber: order.orderNumber,
            userId: order.userId,
            status: next,
            paymentStatus: cancel ? order.paymentStatus : 'paid',
            fulfillmentType: order.fulfillmentType,
            receiver: order.receiver,
            payment: order.payment,
            subtotalCents: order.subtotalCents,
            shippingFeeCents: order.shippingFeeCents,
            totalCents: order.totalCents,
            placedAt: order.placedAt,
            receiptPath: receiptPath,
            cancellationReason: cancellationReason,
          );
          status = next;
          savedCancellationReason = cancellationReason;
          updateNotice = 'Order updated successfully.';
        });
        showInventoryOverlayFeedback(context, 'Order updated successfully.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => saveError = error is StateError
              ? error.message
              : 'Could not save the order. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> openProduct(OrderLine line) async {
    if (openingLineId != null) return;
    setState(() => openingLineId = line.id);
    try {
      final item =
          await (widget.productLookup ??
              (widget.isAdmin
                  ? FirestoreService.instance.findSavedOrderItem
                  : FirestoreService.instance.findSellingOrderProduct))(line);
      if (!mounted) return;
      setState(() => openingLineId = null);
      if (item == null ||
          (!widget.isAdmin && !item.canSellAt(DateTime.now()))) {
        await showOrderConfirmation(
          context: context,
          title: widget.isAdmin ? 'Item unavailable' : 'Product unavailable',
          message: widget.isAdmin
              ? 'This item no longer exists in the inventory.'
              : 'This product no longer exists or is no longer available for sale.',
          action: 'OK',
          single: true,
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => widget.isAdmin
                ? AdminItemDetailScreen(
                    item: item,
                    liveUpdates: widget.liveUpdates,
                  )
                : ItemDetailScreen(item: item),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback(
            'Could not load the product. Please check your connection and try again.',
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => openingLineId = null);
    }
  }

  Future<void> upload() async {
    if (busy || missing) return;
    setState(() {
      pickingReceipt = true;
      receiptError = null;
    });
    try {
      final file =
          await (widget.pickReceipt ??
              () => ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1800,
              ))();
      if (!mounted || file == null) return;
      setState(() {
        pickingReceipt = false;
        uploadingReceipt = true;
      });
      final path =
          await (widget.uploadReceipt ??
              FirestoreService.instance.uploadOrderReceipt)(file, order.id);
      if (mounted) {
        setState(() => receiptPath = path);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(inventoryFeedback('Payment receipt uploaded.'));
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => receiptError = error.code.contains('access_denied')
              ? 'Allow photo access in your device settings to select a receipt.'
              : 'Could not open your photos. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              receiptError = 'Could not upload the receipt. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          pickingReceipt = false;
          uploadingReceipt = false;
        });
      }
    }
  }
}
