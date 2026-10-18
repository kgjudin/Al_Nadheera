import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  final _supabase = Supabase.instance.client;
  Timer? _periodicTimer;
  String? _employeeId;
  bool _isInitialized = false;
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  Future<void> initialize() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_isInitialized && _employeeId != null) {
      // Re-trigger location update when active
      recordCurrentLocation();
      return;
    }

    try {
      // 1. Resolve employee id in public.employees table
      final empRes = await _supabase
          .from('employees')
          .select('id')
          .or('id.eq.${user.id},email.ilike.${user.email ?? ''}')
          .maybeSingle();

      if (empRes != null) {
        _employeeId = empRes['id']?.toString();
      } else {
        _employeeId = user.id;
      }

      _isInitialized = true;

      // 2. Request location permission and start tracking
      final hasPermission = await _handleLocationPermission();
      if (hasPermission) {
        await recordCurrentLocation();
        _startPeriodicTracking();
      }
    } catch (e) {
      debugPrint('LocationService initialize error: $e');
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return false;
    }

    return true;
  }

  void _startPeriodicTracking() {
    _periodicTimer?.cancel();
    // Update location every 3 minutes while the app is actively used
    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      recordCurrentLocation();
    });
  }

  Future<void> recordCurrentLocation({bool isClosing = false}) async {
    if (_employeeId == null) {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _employeeId = user.id;
    }

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) return;
      _currentPosition = position;

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final lat = position.latitude;
      final lng = position.longitude;
      final locDesc = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

      // 1. Update the employee's current / last recorded location
      await _supabase.from('employees').update({
        'last_latitude': lat,
        'last_longitude': lng,
        'last_location_address': locDesc,
        'last_location_updated_at': nowUtc,
        'is_online': !isClosing,
        'last_seen': nowUtc,
      }).eq('id', _employeeId!);

      // 2. Insert into location history logs
      await _supabase.from('employee_location_logs').insert({
        'employee_id': _employeeId,
        'latitude': lat,
        'longitude': lng,
        'accuracy': position.accuracy,
        'address': locDesc,
        'recorded_at': nowUtc,
      });

      debugPrint('Employee location saved: $lat, $lng (closing: $isClosing)');
    } catch (e) {
      debugPrint('Error recording employee location: $e');
    }
  }

  /// Called when the app is paused, detached, or closed by the employee
  Future<void> onAppClosed() async {
    if (_employeeId == null) return;
    try {
      // Record latest exit position and flag as offline while keeping latest location
      await recordCurrentLocation(isClosing: true);
    } catch (e) {
      debugPrint('Error handling app closed location: $e');
    }
  }

  /// Launch Google Maps with coordinates
  static Future<void> openMap(double latitude, double longitude, {String? label}) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      final browserUrl = Uri.parse('https://maps.google.com/?q=$latitude,$longitude');
      await launchUrl(browserUrl, mode: LaunchMode.platformDefault);
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _isInitialized = false;
  }
}
