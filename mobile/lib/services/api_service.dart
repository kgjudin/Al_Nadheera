import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/site_model.dart';
import '../models/dashboard_metrics_model.dart';
import '../models/product_model.dart';

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

  // -- Tasks --
  Future<List<dynamic>> getTasks(String siteId) async {
    final response = await http.get(Uri.parse('$baseUrl/sites/$siteId/tasks'));
    return _processResponse(response) as List;
  }
  Future<void> createTask(String siteId, Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/sites/$siteId/tasks'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
  }
  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    final response = await http.put(Uri.parse('$baseUrl/sites/tasks/$id'), headers: {'Content-Type': 'application/json'}, body: json.encode(data));
    _processResponse(response);
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
}

