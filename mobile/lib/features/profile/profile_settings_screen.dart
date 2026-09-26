import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import '../chat/services/presence_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _roleController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _profileImageUrl;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _roleController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _userId = user.id;
    _emailController.text = user.email ?? '';

    try {
      final res = await _supabase
          .from('employees')
          .select('name, phone, role, profile_image_url')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        _nameController.text = res['name']?.toString() ?? user.userMetadata?['name']?.toString() ?? '';
        _phoneController.text = res['phone']?.toString() ?? user.userMetadata?['phone']?.toString() ?? '';
        _roleController.text = res['role']?.toString() ?? user.userMetadata?['role']?.toString() ?? 'Staff';
        _profileImageUrl = res['profile_image_url']?.toString() ?? user.userMetadata?['avatar_url']?.toString();
      } else {
        _nameController.text = user.userMetadata?['name']?.toString() ?? '';
        _phoneController.text = user.userMetadata?['phone']?.toString() ?? '';
        _roleController.text = user.userMetadata?['role']?.toString() ?? 'Staff';
        _profileImageUrl = user.userMetadata?['avatar_url']?.toString();
      }
    } catch (e) {
      debugPrint('Error loading employee profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_userId == null) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.name.split('.').last.toLowerCase();
      final mimeType = fileExt == 'png' ? 'image/png' : 'image/jpeg';
      final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      // Upload binary to Supabase Storage
      await _supabase.storage.from('profile-images').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: mimeType,
            ),
          );

      final publicUrl = _supabase.storage.from('profile-images').getPublicUrl(filePath);

      // Update in employees table
      await _supabase.from('employees').upsert({
        'id': _userId!,
        'name': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (_supabase.auth.currentUser?.email ?? 'User'),
        'email': _supabase.auth.currentUser?.email,
        'profile_image_url': publicUrl,
      });

      // Update in Supabase auth metadata
      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'avatar_url': publicUrl}),
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profileImageUrl = publicUrl;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              if (_profileImageUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (_userId == null) return;
                    try {
                      await _supabase.from('employees').update({
                        'profile_image_url': null,
                      }).eq('id', _userId!);
                      setState(() => _profileImageUrl = null);
                    } catch (_) {}
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_userId == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final phone = _phoneController.text.trim();
      final role = _roleController.text.trim();

      await _supabase.from('employees').upsert({
        'id': _userId!,
        'name': name,
        'phone': phone.isNotEmpty ? phone : null,
        'role': role.isNotEmpty ? role : 'Staff',
        'email': _emailController.text.trim(),
        if (_profileImageUrl != null) 'profile_image_url': _profileImageUrl,
      });

      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'name': name,
              'phone': phone,
              'role': role,
            },
          ),
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool obscureConfirm = true;
    String? errorMsg;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final pwd = passwordCtrl.text.trim();
                          final confirm = confirmCtrl.text.trim();

                          if (pwd.length < 6) {
                            setDialogState(() => errorMsg = 'Password must be at least 6 characters');
                            return;
                          }
                          if (pwd != confirm) {
                            setDialogState(() => errorMsg = 'Passwords do not match');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMsg = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _supabase.auth.updateUser(
                              UserAttributes(password: pwd),
                            );

                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      PresenceService.instance.dispose();
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final initial = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : (_emailController.text.isNotEmpty ? _emailController.text[0].toUpperCase() : 'U');

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile & Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Profile Photo with Camera Button
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _isUploadingPhoto
                          ? Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                              ? Image.network(
                                  _profileImageUrl!,
                                  fit: BoxFit.cover,
                                  width: 110,
                                  height: 110,
                                  errorBuilder: (_, __, ___) => _buildFallbackAvatar(initial, primaryColor),
                                )
                              : _buildFallbackAvatar(initial, primaryColor),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: primaryColor,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _showImagePickerSheet,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _nameController.text.isNotEmpty ? _nameController.text : 'Staff Member',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _roleController.text.isNotEmpty ? _roleController.text : 'AL NADHEERA Staff',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),

            // Profile Fields Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _roleController,
                      decoration: const InputDecoration(
                        labelText: 'Role / Designation',
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        isDense: true,
                        helperText: 'Email is linked to your login credentials',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security & Settings Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.blue),
                    ),
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Update your login password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.red),
                    ),
                    title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle: const Text('Log out of this account'),
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String initial, Color color) {
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
