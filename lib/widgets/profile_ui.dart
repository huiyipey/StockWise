import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'inventory_ui.dart';
import 'profile_avatar.dart';

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({super.key, required this.child, this.padding = 18});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class ProfileSection extends StatelessWidget {
  const ProfileSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: InventoryColors.ink,
      ),
    ),
  );
}

class ProfileAction extends StatelessWidget {
  const ProfileAction({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.subtitle,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: InventoryColors.green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: InventoryColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: InventoryColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: InventoryColors.muted,
          ),
        ],
      ),
    ),
  );
}

class ProfileNotice extends StatelessWidget {
  const ProfileNotice(
    this.message, {
    super.key,
    this.error = false,
    this.busy = false,
  });
  final String message;
  final bool error, busy;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFAE7E0) : InventoryColors.soft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: error ? InventoryColors.error : InventoryColors.green,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: error ? InventoryColors.error : InventoryColors.green,
            ),
          ),
        ),
      ],
    ),
  );
}

class ProfileEmpty extends StatelessWidget {
  const ProfileEmpty(
    this.title, {
    super.key,
    this.body,
    this.icon = Icons.info_outline_rounded,
  });
  final String title;
  final String? body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 55),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: InventoryColors.soft,
          child: Icon(icon, color: InventoryColors.green, size: 28),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (body != null) ...[
          const SizedBox(height: 12),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: InventoryColors.muted,
            ),
          ),
        ],
      ],
    ),
  );
}

class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    required this.name,
    this.path,
    this.preview,
    this.radius = 34,
  });
  final String name;
  final String? path;
  final Uint8List? preview;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? 'SW'
        : '${words.first.characters.first}${words.length > 1 ? words.last.characters.first : ''}'
              .toUpperCase();
    return (path?.isNotEmpty == true || preview != null)
        ? ProfileAvatar(photoPath: path, preview: preview, radius: radius)
        : Center(
            child: CircleAvatar(
              radius: radius,
              backgroundColor: InventoryColors.soft,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: radius * .55,
                  fontWeight: FontWeight.w700,
                  color: InventoryColors.green,
                ),
              ),
            ),
          );
  }
}

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.storeName,
    this.phone,
    this.photo,
  });
  final String name, email, role, storeName;
  final String? phone, photo;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: Stack(
              children: [
                Container(
                  key: const ValueKey('profile-identity-band'),
                  height: 64,
                  color: InventoryColors.soft,
                ),
                Positioned(
                  right: -16,
                  top: -38,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .32),
                        width: 15,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 22,
                  child: Center(
                    child: Container(
                      key: const ValueKey('profile-identity-photo'),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ProfilePhoto(name: name, path: photo, radius: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: InventoryColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: InventoryColors.green,
                      ),
                    ),
                    const Text(
                      '·',
                      style: TextStyle(color: InventoryColors.muted),
                    ),
                    const Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: InventoryColors.muted,
                    ),
                    Text(
                      storeName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: InventoryColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _contact(Icons.mail_outline_rounded, email),
                      if (phone?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 9),
                        _contact(Icons.phone_outlined, phone!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _contact(IconData icon, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 17, color: InventoryColors.green),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: InventoryColors.muted,
          ),
        ),
      ),
    ],
  );
}

class ProfileFooter extends StatelessWidget {
  const ProfileFooter({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      color: InventoryColors.background,
      child: InventoryButton(label: label, busy: busy, onPressed: onPressed),
    ),
  );
}

Future<bool> showProfileConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  required String action,
  String cancel = 'Keep editing',
  bool danger = false,
  bool single = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => InventoryTheme(
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: InventoryColors.ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: InventoryColors.muted,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Row(
                    children: [
                      if (!single) ...[
                        Expanded(
                          child: InventoryButton(
                            label: cancel,
                            soft: true,
                            height: 46,
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: InventoryButton(
                          label: action,
                          danger: danger,
                          height: 46,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ??
    false;

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({
    super.key,
    required this.title,
    required this.body,
    required this.footer,
    this.dirty = false,
    this.busy = false,
    this.completed = false,
    this.discardTitle = 'Discard changes?',
  });
  final String title, discardTitle;
  final Widget body, footer;
  final bool dirty, busy, completed;
  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  bool allowPop = false, confirming = false;
  Future<void> leave() async {
    if (widget.busy || confirming) return;
    confirming = true;
    final leave =
        !widget.dirty ||
        await showProfileConfirmation(
          context: context,
          title: widget.discardTitle,
          message: 'The changes you made have not been saved.',
          action: 'Discard and leave',
          danger: true,
        );
    confirming = false;
    if (leave && mounted) {
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => PopScope(
        canPop: !widget.busy && (allowPop || widget.completed || !widget.dirty),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                InventoryHeader(
                  title: widget.title,
                  back: true,
                  onBack: widget.busy ? null : leave,
                ),
                Expanded(child: widget.body),
              ],
            ),
          ),
          bottomNavigationBar: widget.footer,
        ),
      ),
    ),
  );
}
