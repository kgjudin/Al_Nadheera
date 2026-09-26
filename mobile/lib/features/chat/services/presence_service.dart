import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  static final PresenceService instance = PresenceService._internal();
  PresenceService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _presenceChannel;
  final ValueNotifier<Set<String>> onlineUsersNotifier = ValueNotifier<Set<String>>({});
  Timer? _heartbeatTimer;
  String? _myUserId;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _myUserId = _supabase.auth.currentUser?.id;

    if (_myUserId == null) return;

    _setupPresenceChannel();
    _startHeartbeat();
  }

  void _setupPresenceChannel() {
    try {
      _presenceChannel = _supabase.channel('online_presence');

      _presenceChannel!.onPresenceSync((_) {
        _syncPresenceState();
      });

      _presenceChannel!.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed && _myUserId != null) {
          try {
            await _presenceChannel!.track({
              'user_id': _myUserId,
              'online_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  void _syncPresenceState() {
    if (_presenceChannel == null) return;
    final state = _presenceChannel!.presenceState();
    final Set<String> onlineIds = {};

    for (final singleState in state) {
      for (final p in singleState.presences) {
        final userId = p.payload['user_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          onlineIds.add(userId);
        }
      }
    }

    onlineUsersNotifier.value = onlineIds;
  }

  void _startHeartbeat() {
    _updateDatabasePresence(true);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _updateDatabasePresence(true);
    });
  }

  Future<void> _updateDatabasePresence(bool isOnline) async {
    if (_myUserId == null) return;
    try {
      await _supabase.from('employees').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', _myUserId!);
    } catch (_) {}
  }

  bool isUserOnline(String userId, {bool? dbIsOnline, DateTime? lastSeen}) {
    // 1. Check realtime presence channel
    if (onlineUsersNotifier.value.contains(userId)) {
      return true;
    }

    // 2. Check database presence with 5-minute activity window
    if (dbIsOnline == true && lastSeen != null) {
      final difference = DateTime.now().difference(lastSeen);
      if (difference.inMinutes <= 5) {
        return true;
      }
    }

    return false;
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _updateDatabasePresence(false);
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    _isInitialized = false;
  }
}
