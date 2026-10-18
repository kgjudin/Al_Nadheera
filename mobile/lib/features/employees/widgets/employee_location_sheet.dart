import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/employee_model.dart';
import '../../../services/location_service.dart';

class EmployeeLocationSheet extends StatefulWidget {
  final Employee employee;

  const EmployeeLocationSheet({super.key, required this.employee});

  static Future<void> show(BuildContext context, Employee employee) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmployeeLocationSheet(employee: employee),
    );
  }

  @override
  State<EmployeeLocationSheet> createState() => _EmployeeLocationSheetState();
}

class _EmployeeLocationSheetState extends State<EmployeeLocationSheet> {
  late Employee _employee;
  bool _isLoading = false;
  List<Map<String, dynamic>> _locationLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _refreshEmployeeData();
    _loadLocationLogs();
  }

  Future<void> _refreshEmployeeData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('employees')
          .select('*, site:sites(name)')
          .eq('id', _employee.id)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _employee = Employee.fromJson(res);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing employee location: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocationLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final res = await Supabase.instance.client
          .from('employee_location_logs')
          .select('*')
          .eq('employee_id', _employee.id)
          .order('recorded_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _locationLogs = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (e) {
      debugPrint('Error loading location history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  bool get _isCurrentlyOnline {
    if (_employee.lastLocationUpdatedAt == null) return false;
    final diff = DateTime.now().toUtc().difference(_employee.lastLocationUpdatedAt!.toUtc());
    return _employee.isOnline && diff.inMinutes <= 5;
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _employee.lastLatitude != null && _employee.lastLongitude != null;
    final lat = _employee.lastLatitude;
    final lng = _employee.lastLongitude;
    final isOnline = _isCurrentlyOnline;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF0A2540).withValues(alpha: 0.08),
                    backgroundImage: (_employee.profileImageUrl != null && _employee.profileImageUrl!.isNotEmpty)
                        ? NetworkImage(_employee.profileImageUrl!)
                        : null,
                    child: (_employee.profileImageUrl == null || _employee.profileImageUrl!.isEmpty)
                        ? Text(
                            _employee.name.isNotEmpty ? _employee.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF16A34A) : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _employee.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_employee.role ?? 'Employee'}${_employee.employeeId != null ? ' • ID: ${_employee.employeeId}' : ''}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, color: Color(0xFF0A2540)),
                tooltip: 'Refresh Location',
                onPressed: _isLoading ? null : () {
                  _refreshEmployeeData();
                  _loadLocationLogs();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Flexible scrollable content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Status banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOnline ? const Color(0xFFA7F3D0) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOnline ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'Online in App (Live Location)' : 'App Closed / Offline (Last Known Location)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isOnline ? const Color(0xFF065F46) : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline
                                  ? 'Active right now. Live GPS is syncing in real-time.'
                                  : _employee.lastLocationUpdatedAt != null
                                      ? 'Last active ${timeago.format(_employee.lastLocationUpdatedAt!)}'
                                      : 'No app activity recorded yet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnline ? const Color(0xFF047857) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!hasLocation) ...[
                  // Empty state
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.location_off_outlined, size: 52, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No Location Recorded Yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The employee hasn\'t opened the app since location services were enabled. As soon as they use the app on their phone, their location will appear here automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Location details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade50.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on, color: Colors.blue, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOnline ? 'Current Live Position' : 'Last Recorded Exit Position',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2540)),
                                  ),
                                  if (_employee.lastLocationUpdatedAt != null)
                                    Text(
                                      DateFormat('dd MMM yyyy, hh:mm a').format(_employee.lastLocationUpdatedAt!.toLocal()),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                              tooltip: 'Copy Coordinates',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: '$lat, $lng'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Coordinates copied to clipboard!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Latitude', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(lat!.toStringAsFixed(6), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 28, color: Colors.grey.shade300),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Longitude', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(lng!.toStringAsFixed(6), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action button: Open in Google Maps
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2540),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 1,
                            ),
                            icon: const Icon(Icons.map_rounded, size: 20),
                            label: const Text(
                              'Open in Google Maps',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: () => LocationService.openMap(lat, lng),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Recent checkpoints section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Location Checkpoints',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                      ),
                      if (_isLoadingLogs)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_locationLogs.isEmpty && !_isLoadingLogs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No previous location logs recorded.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ..._locationLogs.map((log) {
                      final logLat = (log['latitude'] as num?)?.toDouble();
                      final logLng = (log['longitude'] as num?)?.toDouble();
                      final logTime = log['recorded_at'] != null ? DateTime.tryParse(log['recorded_at']) : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${logLat?.toStringAsFixed(4)}, ${logLng?.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  if (logTime != null)
                                    Text(
                                      DateFormat('hh:mm a • dd MMM').format(logTime.toLocal()),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                            if (logLat != null && logLng != null)
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.blue),
                                tooltip: 'View on Map',
                                onPressed: () => LocationService.openMap(logLat, logLng),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
