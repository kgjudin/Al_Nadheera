import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/site_model.dart';
import '../models/dashboard_metrics_model.dart';
import '../models/product_model.dart';
import '../models/ipc_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null) throw Exception('API_BASE_URL not set in .env');
    return url;
  }

  // Helper to handle response
  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = json.decode(response.body);
      if (body['success'] == true) {
        return body['data'];
      } else {
        throw Exception(body['message'] ?? 'API request failed');
      }
    } else {
      throw Exception('Failed with status code: ${response.statusCode}');
    }
  }

  // -- Dashboard --
  Future<DashboardMetrics> getDashboardMetrics() async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard'));
    final data = _processResponse(response);
    return DashboardMetrics.fromJson(data);
  }

  // -- Sites --
  Future<List<Site>> getSites() async {
    final response = await http.get(Uri.parse('$baseUrl/sites'));
    final data = _processResponse(response) as List;
    return data.map((json) => Site.fromJson(json)).toList();
  }

  Future<Site> getSite(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$id'));
    final data = _processResponse(response);
    return Site.fromJson(data);
  }

  Future<Site> createSite(Map<String, dynamic> siteData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sites'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(siteData),
    );
    final data = _processResponse(response);
    return Site.fromJson(data);
  }

  Future<Site> updateSite(String id, Map<String, dynamic> siteData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/sites/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(siteData),
    );
    final data = _processResponse(response);
    return Site.fromJson(data);
  }

  Future<void> deleteSite(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/sites/$id'));
    _processResponse(response);
  }

  // -- Financials (Summary & Budget) --
  Future<List<dynamic>> getSiteSummary(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/summary'));
    return _processResponse(response) as List;
  }

  Future<void> createSiteSummary(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sites/$siteId/summary'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    _processResponse(response);
  }

  Future<List<dynamic>> getSiteBudget(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/budget'));
    return _processResponse(response) as List;
  }

  Future<void> createSiteBudget(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sites/$siteId/budget'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    _processResponse(response);
  }

  // -- Other Financials (Labour, Materials, Subcontractors, Additional) --
  Future<List<dynamic>> getLabour(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/labour'));
    return _processResponse(response) as List;
  }
  Future<void> createLabour(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/sites/$siteId/labour'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
  }

  Future<List<dynamic>> getMaterials(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/materials'));
    return _processResponse(response) as List;
  }
  Future<void> createMaterial(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/sites/$siteId/materials'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
  }
  Future<void> updateMaterial(String id, Map<String, dynamic> data) async {
    final response = await http.put(Uri.parse('$baseUrl/sites/materials/$id'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
  }
  Future<void> deleteMaterial(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/sites/materials/$id'));
    _processResponse(response);
  }

  Future<String?> uploadAttachment({
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    String folder = 'materials',
  }) async {
    try {
      final base64Str = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('$baseUrl/sites/upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fileName': fileName,
          'base64Data': base64Str,
          'contentType': contentType ?? 'application/octet-stream',
          'folder': folder,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['url'] != null) {
          return decoded['url'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> getSubcontractors(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/subcontractors'));
    return _processResponse(response) as List;
  }
  Future<void> createSubcontractor(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/sites/$siteId/subcontractors'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
  }

  Future<List<dynamic>> getAdditionalExpenses(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/additional-expenses'));
    return _processResponse(response) as List;
  }
  Future<void> createAdditionalExpense(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/sites/$siteId/additional-expenses'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
  }

  // -- Employees --
  Future<List<dynamic>> getEmployees() async {
    final response = await http.get(Uri.parse('$baseUrl/employees'));
    return _processResponse(response) as List;
  }

  Future<dynamic> getEmployee(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/employees/$id'));
    return _processResponse(response);
  }

  Future<void> createEmployee(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employees'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    _processResponse(response);
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/employees/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    _processResponse(response);
  }

  Future<void> deleteEmployee(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/employees/$id'));
    _processResponse(response);
  }

  Future<void> changeEmployeePassword(String employeeId, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employees/$employeeId/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'password': newPassword}),
    );
    _processResponse(response);
  }

  Future<void> approveEmployee(String employeeId, {String? role, String? roleId, String? siteId}) async {
    final payload = <String, dynamic>{};
    if (role != null) payload['role'] = role;
    if (roleId != null) payload['role_id'] = roleId;
    if (siteId != null) payload['assigned_site_id'] = siteId;

    final response = await http.post(
      Uri.parse('$baseUrl/employees/$employeeId/approve'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    _processResponse(response);
  }

  Future<void> declineEmployee(String employeeId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employees/$employeeId/decline'),
      headers: {'Content-Type': 'application/json'},
    );
    _processResponse(response);
  }

  // -- Tasks --
  Future<List<dynamic>> getTasks(String siteId) async {
    try {
      final res = await Supabase.instance.client
          .from('tasks')
          .select('*, employee:employees(name)')
          .eq('site_id', siteId)
          .order('created_at', ascending: false);
      if (res.isNotEmpty) {
        return res;
      }
    } catch (_) {}

    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/tasks'));
    return _processResponse(response) as List;
  }

  Future<void> createTask(String siteId, Map<String, dynamic> data) async {
    bool savedDirectly = false;
    try {
      final insertData = {
        'site_id': siteId,
        'title': data['title'],
        'description': data['description'],
        'assigned_employee_id': data['assigned_employee_id'],
        'start_date': data['start_date'],
        'due_date': data['due_date'],
        'status': data['status'] ?? 'Pending',
        'sub_modules': data['sub_modules'] ?? [],
      };
      await Supabase.instance.client.from('tasks').insert(insertData);
      savedDirectly = true;
    } catch (_) {}

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sites/$siteId/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (!savedDirectly) {
        final res = _processResponse(response);
        if (res != null && res['id'] != null && data.containsKey('sub_modules')) {
          try {
            await Supabase.instance.client
                .from('tasks')
                .update({'sub_modules': data['sub_modules'] ?? []})
                .eq('id', res['id'].toString());
          } catch (_) {}
        }
      }
    } catch (e) {
      if (!savedDirectly) rethrow;
    }
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    bool savedDirectly = false;
    try {
      await Supabase.instance.client.from('tasks').update(data).eq('id', id);
      savedDirectly = true;
    } catch (_) {}

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/sites/tasks/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (!savedDirectly) {
        _processResponse(response);
      }
    } catch (e) {
      if (!savedDirectly) rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await Supabase.instance.client.from('tasks').delete().eq('id', id);
    } catch (_) {}

    try {
      final response = await http.delete(Uri.parse('$baseUrl/sites/tasks/$id'));
      _processResponse(response);
    } catch (_) {}
  }
  Future<void> bulkUpdateTasks(List<String> ids, Map<String, dynamic> data) async {
    if (ids.isEmpty) return;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/sites/tasks/bulk-update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': ids, 'updates': data}),
      );
      _processResponse(response);
    } catch (_) {
      // Fallback: update in parallel
      await Future.wait(ids.map((id) => updateTask(id, data)));
    }
  }
  Future<void> bulkDeleteTasks(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sites/tasks/bulk-delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': ids}),
      );
      _processResponse(response);
    } catch (_) {
      // Fallback: delete in parallel
      await Future.wait(ids.map((id) => deleteTask(id)));
    }
  }

  // -- Products --
  Future<List<Product>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));
    final data = _processResponse(response) as List;
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    final res = _processResponse(response);
    return Product.fromJson(res);
  }

  Future<Product> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    final res = _processResponse(response);
    return Product.fromJson(res);
  }

  Future<void> deleteProduct(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/products/$id'));
    _processResponse(response);
  }

  // -- Product Classes --
  Future<List<ProductClass>> getProductClasses() async {
    final response = await http.get(Uri.parse('$baseUrl/products/classes'));
    final data = _processResponse(response) as List;
    return data.map((json) => ProductClass.fromJson(json)).toList();
  }

  Future<ProductClass> createProductClass(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products/classes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name}),
    );
    final res = _processResponse(response);
    return ProductClass.fromJson(res);
  }

  Future<void> deleteProductClass(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/products/classes/$id'));
    _processResponse(response);
  }

  // -- Product Sub-Modules --
  Future<List<ProductSubmodule>> getProductSubmodules({String? className, String? classId}) async {
    String url = '$baseUrl/products/submodules';
    if (className != null && className.isNotEmpty) {
      url += '?class_name=${Uri.encodeComponent(className)}';
    } else if (classId != null && classId.isNotEmpty) {
      url += '?class_id=${Uri.encodeComponent(classId)}';
    }
    final response = await http.get(Uri.parse(url));
    final data = _processResponse(response) as List;
    return data.map((json) => ProductSubmodule.fromJson(json)).toList();
  }

  Future<ProductSubmodule> createProductSubmodule({
    required String name,
    required String className,
    String? classId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products/submodules'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'class_name': className,
        if (classId != null) 'class_id': classId,
      }),
    );
    final res = _processResponse(response);
    return ProductSubmodule.fromJson(res);
  }

  Future<void> deleteProductSubmodule(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/products/submodules/$id'));
    _processResponse(response);
  }

  // -- Auth --
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );
    final data = _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  // -- IPC (Interim Payment Certificates) --
  Future<List<IpcDocument>> getIpcDocuments() async {
    final response = await http.get(Uri.parse('$baseUrl/ipc'));
    final data = _processResponse(response);
    final list = data['data'] is List ? data['data'] as List : (data is List ? data : []);
    return list.map((json) => IpcDocument.fromJson(json)).toList();
  }

  Future<IpcDocument> getIpcDocumentById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/ipc/$id'));
    final data = _processResponse(response);
    final docData = data['data'] != null ? data['data'] : data;
    return IpcDocument.fromJson(docData);
  }

  Future<IpcDocument> createIpcDocument(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ipc'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    final res = _processResponse(response);
    final docData = res['data'] != null ? res['data'] : res;
    return IpcDocument.fromJson(docData);
  }

  Future<IpcDocument> updateIpcDocument(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ipc/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    final res = _processResponse(response);
    final docData = res['data'] != null ? res['data'] : res;
    return IpcDocument.fromJson(docData);
  }

  Future<void> deleteIpcDocument(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/ipc/$id'));
    _processResponse(response);
  }
}



