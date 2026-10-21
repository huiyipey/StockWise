import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:image_picker/image_picker.dart';
=======
<<<<<<< HEAD
import 'package:image_picker/image_picker.dart';
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';

class OrderDetailScreen extends StatefulWidget {
  final StoreOrder order;
  final bool isAdmin;

  const OrderDetailScreen({
    super.key,
    required this.order,
    this.isAdmin = true,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String status = widget.order.status;
  bool saving = false;
<<<<<<< HEAD
  bool uploadingReceipt = false;
  late String? receiptPath = widget.order.receiptPath;
=======
<<<<<<< HEAD
  bool uploadingReceipt = false;
  late String? receiptPath = widget.order.receiptPath;
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Order Details',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row('Order', '#${widget.order.orderNumber}'),
                        _row(
                          'Placed',
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(widget.order.placedAt),
                        ),
                        _row(
                          'Fulfillment',
                          _label(widget.order.fulfillmentType),
                        ),
                        _row('Payment', _label(widget.order.paymentStatus)),
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                        _row(
                          'Method',
                          widget.order.payment['methodLabel'] as String? ?? '-',
                        ),
<<<<<<< HEAD
=======
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Items', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                StreamBuilder<List<OrderLine>>(
                  stream: FirestoreService.instance.watchOrderLines(
                    widget.order.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('${snapshot.error}');
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: snapshot.data!
                          .map(
                            (line) => Card(
                              child: ListTile(
                                leading: ProductArtwork(
                                  size: 50,
                                  imagePath: line.imagePath,
                                ),
                                title: Text(
                                  line.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${line.quantity} ${line.unitLabel}  •  Exp ${DateFormat('dd/MM/yyyy').format(line.expiryAt)}',
                                ),
                                trailing: Text(
                                  'RM ${(line.lineTotalCents / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _moneyRow('Subtotal', widget.order.subtotalCents),
                        _moneyRow('Shipping', widget.order.shippingFeeCents),
                        const Divider(),
                        _moneyRow('Total', widget.order.totalCents, bold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Receiver', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.receiver['name'] as String? ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(widget.order.receiver['phone'] as String? ?? '-'),
                        Text(widget.order.receiver['email'] as String? ?? '-'),
                        if ((widget.order.receiver['addressLine1'] as String? ??
                                '')
                            .isNotEmpty)
                          Text(
                            '${widget.order.receiver['addressLine1']}, ${widget.order.receiver['city']}, ${widget.order.receiver['state']} ${widget.order.receiver['postalCode']}',
                          ),
                      ],
                    ),
                  ),
                ),
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                const SizedBox(height: 14),
                Text(
                  'Payment receipt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (receiptPath != null) ...[
                          ProductArtwork(size: 160, imagePath: receiptPath),
                          const SizedBox(height: 10),
                          const StatusPill(
                            'Receipt uploaded',
                            color: AppColors.primaryDark,
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('No payment receipt uploaded yet.'),
                          ),
                        if (!widget.isAdmin) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: uploadingReceipt ? null : _uploadReceipt,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(
                              uploadingReceipt
                                  ? 'UPLOADING...'
                                  : receiptPath == null
                                  ? 'UPLOAD RECEIPT'
                                  : 'REPLACE RECEIPT',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
<<<<<<< HEAD
=======
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                if (widget.isAdmin) ...[
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Order status',
                    ),
                    items:
                        const [
                              'to_pay',
                              'to_ship',
                              'to_receive',
                              'completed',
                              'cancelled',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => status = value ?? status),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: saving ? null : _save,
                    child: Text(saving ? 'SAVING...' : 'SAVE ORDER'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
  Widget _moneyRow(String label, int cents, {bool bold = false}) =>
      _row(label, 'RM ${(cents / 100).toStringAsFixed(2)}');
  String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await FirestoreService.instance.updateOrderStatus(widget.order, status);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249

  Future<void> _uploadReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null) return;
    setState(() => uploadingReceipt = true);
    try {
      final path = await FirestoreService.instance.uploadOrderReceipt(
        file,
        widget.order.id,
      );
      if (mounted) {
        setState(() => receiptPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment receipt uploaded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload receipt: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingReceipt = false);
    }
  }
<<<<<<< HEAD
=======
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
}
