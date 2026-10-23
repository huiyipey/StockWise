import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';

class StaffManagementScreen extends StatefulWidget {
  final Stream<List<Map<String, dynamic>>>? membersStream;
  final Stream<List<Map<String, dynamic>>>? invitesStream;
  final Future<void> Function(String)? sendInvite;

  const StaffManagementScreen({
    super.key,
    this.membersStream,
    this.invitesStream,
    this.sendInvite,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  bool inviting = false;
  late final members =
      widget.membersStream ?? FirestoreService.instance.watchStoreMembers();
  late final invites =
      widget.invitesStream ?? FirestoreService.instance.watchAdminInvites();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Store Admins',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: members,
              builder: (context, memberSnapshot) {
                if (memberSnapshot.hasError) {
                  return Center(child: Text('${memberSnapshot.error}'));
                }
                if (!memberSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: invites,
                  builder: (context, inviteSnapshot) {
                    final members = memberSnapshot.data!
                        .where((item) => item['role'] != 'customer')
                        .toList();
                    final pending = (inviteSnapshot.data ?? const [])
                        .where((item) => item['status'] == 'pending')
                        .toList();
                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        Text(
                          'Admins have access to inventory, reports, and orders for this store.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: inviting ? null : _invite,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            inviting ? 'SENDING...' : 'ADD ADMIN BY EMAIL',
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Store team',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...members.map(_memberTile),
                        if (pending.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Pending invitations',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          ...pending.map(_inviteTile),
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
  );

  Widget _memberTile(Map<String, dynamic> member) {
    final role = member['role'] as String? ?? 'admin';
    final active = member['isActive'] as bool? ?? true;
    final isOwner = role == 'owner';
    return Card(
      child: SwitchListTile.adaptive(
        secondary: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(
            isOwner ? Icons.store_rounded : Icons.admin_panel_settings_rounded,
            color: AppColors.primaryDark,
          ),
        ),
        title: Text(
          member['email'] as String? ?? (isOwner ? 'Store owner' : 'Admin'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(isOwner ? 'Owner' : 'Admin'),
        value: active,
        onChanged: isOwner
            ? null
            : (value) => FirestoreService.instance.setMemberActive(
                member['id'] as String,
                value,
              ),
      ),
    );
  }

  Widget _inviteTile(Map<String, dynamic> invite) => Card(
    child: ListTile(
      leading: const Icon(Icons.mark_email_unread_outlined),
      title: Text(
        invite['emailLowercase'] as String? ?? '',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('Access activates when this person signs in.'),
      trailing: const StatusPill('Pending', color: AppColors.warning),
    ),
  );

  Future<void> _invite() async {
    var email = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add store admin'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onChanged: (value) => email = value,
          decoration: const InputDecoration(labelText: 'Staff email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, email),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty || !mounted) return;
    setState(() => inviting = true);
    try {
      await (widget.sendInvite ?? FirestoreService.instance.inviteAdmin)(
        result,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Admin invitation created for ${result.trim().toLowerCase()}.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        if (error.code == 'not-found' &&
            error.details is Map &&
            error.details['reason'] == 'email-not-found') {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email does not exist'),
              content: const Text(
                'This email does not exist. Please enter a valid email.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.message ?? 'Could not add admin. Please try again.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => inviting = false);
    }
  }
}
