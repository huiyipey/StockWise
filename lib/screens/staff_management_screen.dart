import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/store_role.dart';
import '../services/firestore_service.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';
import '../widgets/profile_tag.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    this.membersStream,
    this.invitesStream,
    this.sendInvite,
    this.changeAccess,
    this.currentUserId,
  });
  final Stream<List<Map<String, dynamic>>>? membersStream, invitesStream;
  final Future<void> Function(String)? sendInvite;
  final Future<void> Function(String, bool)? changeAccess;
  final String? currentUserId;
  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  bool inviting = false;
  final pending = <String>{};
  String? error;
  late final members =
      widget.membersStream ?? FirestoreService.instance.watchStoreMembers();
  late final invites =
      widget.invitesStream ?? FirestoreService.instance.watchAdminInvites();
  late final currentUserId =
      widget.currentUserId ??
      (widget.membersStream == null
          ? FirestoreService.instance.currentUserId
          : null);

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Store Admins',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: members,
                  builder: (context, memberSnapshot) {
                    if (memberSnapshot.hasError) {
                      return const SingleChildScrollView(
                        child: ProfileEmpty(
                          'Could not load store admins',
                          body: 'Check your connection and reopen this page.',
                        ),
                      );
                    }
                    if (!memberSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: invites,
                      builder: (context, inviteSnapshot) {
                        final rows = memberSnapshot.data!
                            .where((item) => isStoreAdminRole(item['role']))
                            .toList();
                        final activeAdmins = rows
                            .where((item) => item['isActive'] == true)
                            .length;
                        final invitations =
                            (inviteSnapshot.data ??
                                    const <Map<String, dynamic>>[])
                                .where((item) => item['status'] == 'pending')
                                .toList();
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            InventoryButton(
                              label: inviting
                                  ? 'Sending...'
                                  : 'Add Admin by Email',
                              icon: Icons.add_rounded,
                              busy: inviting,
                              onPressed: inviting ? null : invite,
                            ),
                            const ProfileSection('Store Team'),
                            for (final row in rows)
                              memberCard(row, activeAdmins: activeAdmins),
                            if (inviteSnapshot.hasError)
                              const ProfileNotice(
                                'Could not load pending invitations. Please reopen this page.',
                                error: true,
                              ),
                            if (invitations.isNotEmpty) ...[
                              const ProfileSection('Pending Invitations'),
                              for (final invitation in invitations)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ProfilePanel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.mail_outline_rounded,
                                              color: InventoryColors.green,
                                              size: 19,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                invitation['emailLowercase']
                                                        as String? ??
                                                    '',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Access activates when this person signs in.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.5,
                                            color: InventoryColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: ProfileTag(
                                            'Pending',
                                            pending: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                            if (pending.isNotEmpty)
                              const ProfileNotice(
                                'Updating admin access...',
                                busy: true,
                              ),
                            if (error != null) ...[
                              const SizedBox(height: 16),
                              ProfileNotice(error!, error: true),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget memberCard(Map<String, dynamic> member, {required int activeAdmins}) {
    final id = member['id'] as String? ?? '';
    final isActive = member['isActive'] == true;
    final ownMembership = id == currentUserId;
    final protected = ownMembership || (isActive && activeAdmins <= 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProfilePanel(
        padding: 14,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: InventoryColors.soft,
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 21,
                color: InventoryColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member['email'] as String? ?? 'Admin',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ownMembership ? 'Admin · You' : 'Admin',
                    style: const TextStyle(
                      fontSize: 11,
                      color: InventoryColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: ValueKey('member-active-$id'),
              value: isActive,
              activeTrackColor: InventoryColors.green,
              onChanged: protected || pending.contains(id) || id.isEmpty
                  ? null
                  : (value) => changeAccess(id, value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> changeAccess(String id, bool value) async {
    if (pending.contains(id)) return;
    setState(() {
      pending.add(id);
      error = null;
    });
    try {
      await (widget.changeAccess ?? FirestoreService.instance.setMemberActive)(
        id,
        value,
      );
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is StateError
              ? failure.message
              : 'Could not update access. The previous setting is retained.',
        );
      }
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  Future<void> invite() async {
    if (inviting) return;
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteAdminDialog(),
    );
    if (email == null || !mounted) return;
    setState(() {
      inviting = true;
      error = null;
    });
    try {
      await (widget.sendInvite ?? FirestoreService.instance.inviteAdmin)(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback('Admin invitation created for $email.'),
        );
      }
    } on FirebaseFunctionsException catch (failure) {
      if (!mounted) return;
      if (failure.code == 'not-found' &&
          failure.details is Map &&
          failure.details['reason'] == 'email-not-found') {
        setState(() => inviting = false);
        await showProfileConfirmation(
          context: context,
          title: 'Email does not exist',
          message: 'This email does not exist. Please enter a valid email.',
          action: 'OK',
          single: true,
        );
      } else {
        setState(
          () => error =
              failure.message ?? 'Could not add admin. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not add admin. Please try again.');
      }
    } finally {
      if (mounted) setState(() => inviting = false);
    }
  }
}

class _InviteAdminDialog extends StatefulWidget {
  const _InviteAdminDialog();
  @override
  State<_InviteAdminDialog> createState() => _InviteAdminDialogState();
}

class _InviteAdminDialogState extends State<_InviteAdminDialog> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState?.validate() ?? false) {
      Navigator.pop(context, email.text.trim().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add store admin',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: InventoryColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Use the email linked to their StockWise account.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: InventoryColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('staff-invite-email'),
                controller: email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'Admin Email'),
                validator: (value) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InventoryButton(
                      label: 'Cancel',
                      soft: true,
                      height: 46,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InventoryButton(
                      label: 'Invite',
                      height: 46,
                      onPressed: submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
