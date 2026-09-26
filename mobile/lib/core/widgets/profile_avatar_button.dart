import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/services/presence_service.dart';
import '../../features/profile/profile_settings_screen.dart';

class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({super.key});

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  final _supabase = Supabase.instance.client;
  String? _profileImageUrl;
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('employees')
          .select('name, profile_image_url')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && res != null) {
        setState(() {
          _name = res['name']?.toString() ?? user.userMetadata?['name']?.toString();
          _profileImageUrl = res['profile_image_url']?.toString() ?? user.userMetadata?['avatar_url']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      PresenceService.instance.dispose();
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _openProfileSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
    ).then((_) => _loadUserInfo());
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? 'User';
    final displayName = _name?.isNotEmpty == true ? _name! : email;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      icon: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
              ? NetworkImage(_profileImageUrl!)
              : null,
          child: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
              ? null
              : Text(
                  initial,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
      onSelected: (value) {
        if (value == 'settings') {
          _openProfileSettings();
        } else if (value == 'logout') {
          _signOut(context);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'settings',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_profileImageUrl!)
                      : null,
                  child: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: Colors.black87),
              SizedBox(width: 12),
              Text(
                'Profile & Settings',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
