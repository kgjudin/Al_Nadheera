import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/document_template_model.dart';

class DocumentTemplateService extends ChangeNotifier {
  static final DocumentTemplateService _instance =
      DocumentTemplateService._internal();
  static DocumentTemplateService get instance => _instance;
  factory DocumentTemplateService() => _instance;
  DocumentTemplateService._internal();

  final _supabase = Supabase.instance.client;
  final Map<String, DocumentTemplate> _templates = {};
  bool _isLoading = false;

  Map<String, DocumentTemplate> get templates => _templates;
  bool get isLoading => _isLoading;

  Future<void> loadTemplates() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Try fetching from Supabase
      final res = await _supabase.from('document_templates').select('*');
      final list = (res as List)
          .map((item) => DocumentTemplate.fromJson(item as Map<String, dynamic>))
          .toList();

      for (final tmpl in list) {
        _templates[tmpl.templateType] = tmpl;
      }

      // Cache to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        for (final entry in _templates.entries) entry.key: entry.value.toJson()
      };
      await prefs.setString('cached_document_templates', json.encode(cacheData));
    } catch (e) {
      debugPrint('Failed to load templates from Supabase, loading from cache: $e');
      await _loadFromCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_document_templates');
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _templates[entry.key] =
              DocumentTemplate.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (_) {}
  }

  DocumentTemplate getTemplate(String type) {
    if (_templates.containsKey(type)) {
      return _templates[type]!;
    }
    return DocumentTemplate.defaultTemplate(type);
  }

  Future<String?> uploadAssetImage({
    required Uint8List bytes,
    required String fileName,
    required String assetType, // 'logo', 'seal', 'signature'
  }) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
      final path =
          '$assetType/${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';

      await _supabase.storage.from('document-assets').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('document-assets').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading asset to Supabase: $e');
      return null;
    }
  }

  Future<bool> saveTemplate(DocumentTemplate template) async {
    try {
      final data = template.toJson();

      final res = await _supabase
          .from('document_templates')
          .upsert(data, onConflict: 'template_type')
          .select()
          .single();

      final saved = DocumentTemplate.fromJson(res);
      _templates[template.templateType] = saved;

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        for (final entry in _templates.entries) entry.key: entry.value.toJson()
      };
      await prefs.setString('cached_document_templates', json.encode(cacheData));

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving template: $e');
      return false;
    }
  }
}
