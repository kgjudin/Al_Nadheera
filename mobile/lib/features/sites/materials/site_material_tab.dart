import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';
import '../../../services/invoice_number_service.dart';
import '../../../services/camera/app_camera_service.dart';
import '../../../models/financial_models.dart';

class SiteMaterialTab extends StatefulWidget {
  final String siteId;
  final VoidCallback? onDataChanged;
  const SiteMaterialTab({super.key, required this.siteId, this.onDataChanged});

  @override
  State<SiteMaterialTab> createState() => _SiteMaterialTabState();
}

class AttachmentItem {
  final String name;
  final String type; // 'image', 'pdf', 'excel', 'doc', 'other'
  final int size;
  final String? url;
  final Uint8List? bytes;

  AttachmentItem({
    required this.name,
    required this.type,
    required this.size,
    this.url,
    this.bytes,
  });

  bool get isUploaded => url != null && url!.isNotEmpty;
}

class _SiteMaterialTabState extends State<SiteMaterialTab> {
  final ApiService _apiService = ApiService();
  late Future<List<MaterialCost>> _materialFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'date_desc'; // 'date_desc', 'date_asc', 'amount_desc', 'amount_asc'

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadMaterials() {
    setState(() {
      _materialFuture = _apiService.getMaterials(widget.siteId).then(
          (data) => data.map((json) => MaterialCost.fromJson(json)).toList());
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _determineFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'].contains(ext)) {
      return 'image';
    } else if (ext == 'pdf') {
      return 'pdf';
    } else if (['xlsx', 'xls', 'csv'].contains(ext)) {
      return 'excel';
    } else if (['doc', 'docx'].contains(ext)) {
      return 'doc';
    }
    return 'other';
  }

  Color _getBadgeBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return const Color(0xFFE8F1FF);
      case 'pdf':
        return const Color(0xFFFEE2E2);
      case 'excel':
        return const Color(0xFFDCFCE7);
      case 'doc':
        return const Color(0xFFDBEAFE);
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getBadgeTextColor(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return const Color(0xFF0B5ED7);
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'excel':
        return const Color(0xFF16A34A);
      case 'doc':
        return const Color(0xFF2563EB);
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'excel':
        return Icons.table_chart_rounded;
      case 'doc':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildAttachmentThumbnail(AttachmentItem item) {
    if (item.type == 'image') {
      if (item.bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(item.bytes!, width: 42, height: 42, fit: BoxFit.cover),
        );
      } else if (item.url != null) {
        if (item.url!.startsWith('data:')) {
          try {
            final b64 = item.url!.split(',').last;
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(base64Decode(b64), width: 42, height: 42, fit: BoxFit.cover),
            );
          } catch (_) {}
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: item.url!,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            placeholder: (ctx, u) => const SizedBox(width: 42, height: 42, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (ctx, u, e) => Container(
              width: 42,
              height: 42,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            ),
          ),
        );
      }
    }

    final bgColor = _getBadgeBgColor(item.type);
    final iconColor = _getBadgeTextColor(item.type);
    final iconData = _getFileIcon(item.type);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  Future<String?> _uploadAttachmentBytes({
    required String siteId,
    required String fileName,
    required Uint8List bytes,
    required String type,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'dat';
    final cleanExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$cleanExt';
    final storagePath = 'materials/$siteId/$uniqueName';

    String contentType = 'application/octet-stream';
    if (type == 'image') {
      contentType = ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
    } else if (type == 'pdf') {
      contentType = 'application/pdf';
    } else if (ext == 'xlsx') {
      contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (ext == 'xls') {
      contentType = 'application/vnd.ms-excel';
    } else if (ext == 'csv') {
      contentType = 'text/csv';
    }

    // 1. Try uploading via Backend upload API (service role bypasses RLS)
    try {
      final backendUrl = await _apiService.uploadAttachment(
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
        folder: 'materials/$siteId',
      );
      if (backendUrl != null && backendUrl.isNotEmpty) {
        return backendUrl;
      }
    } catch (e) {
      debugPrint('Backend upload attempt failed: $e');
    }

    // 2. Try direct Supabase Storage upload
    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from('site-attachments').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return supabase.storage.from('site-attachments').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Supabase direct upload failed: $e');
    }

    // 3. Fallback: If image and under 600KB, preserve as data URI
    if (bytes.length < 600 * 1024) {
      final b64 = base64Encode(bytes);
      return 'data:$contentType;base64,$b64';
    }

    return null;
  }

  void _showAttachmentSourceSheet(BuildContext context, Function(AttachmentItem) onAttachmentAdded) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Attachment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const Text(
                'Take a photo, choose from gallery, or import PDF / Excel / Document',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFE8F1FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF0B5ED7)),
                ),
                title: const Text('Take a Photo (Camera)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Capture invoice receipt, site delivery, or material on-site', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    final photo = await AppCameraService.capturePhoto(context);
                    if (photo != null) {
                      onAttachmentAdded(AttachmentItem(
                        name: photo.name,
                        type: 'image',
                        size: photo.size,
                        bytes: photo.bytes,
                      ));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open camera: $e')));
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library, color: Color(0xFF16A34A)),
                ),
                title: const Text('Choose Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Select photo or scanned invoice from device gallery', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      onAttachmentAdded(AttachmentItem(
                        name: photo.name,
                        type: 'image',
                        size: bytes.length,
                        bytes: bytes,
                      ));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open gallery: $e')));
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.upload_file, color: Color(0xFFDC2626)),
                ),
                title: const Text('Import File / Document (PDF, Excel, etc.)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Import PDF invoice, Excel (.xlsx, .csv), or Word document', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    final result = await FilePicker.pickFiles(
                      allowMultiple: true,
                      withData: true,
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      for (final file in result.files) {
                        Uint8List? fileBytes = file.bytes;
                        if (fileBytes == null && !kIsWeb && file.path != null) {
                          fileBytes = await File(file.path!).readAsBytes();
                        }
                        if (fileBytes != null) {
                          final fType = _determineFileType(file.name);
                          onAttachmentAdded(AttachmentItem(
                            name: file.name,
                            type: fType,
                            size: fileBytes.length,
                            bytes: fileBytes,
                          ));
                        }
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick files: $e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOrEditDialog({MaterialCost? existingMaterial}) {
    final formKey = GlobalKey<FormState>();
    final supplierCtrl = TextEditingController(text: existingMaterial?.supplierName ?? '');
    DateTime entryDate = existingMaterial?.date ?? DateTime.now();
    final initialInvoiceNo = existingMaterial?.invoiceNumber ?? InvoiceNumberService.generateInitialMaterialInvoiceNumber(entryDate);
    final invoiceNoCtrl = TextEditingController(text: initialInvoiceNo);
    if (existingMaterial == null) {
      InvoiceNumberService.fetchNextMaterialInvoiceNumber(siteId: widget.siteId, date: entryDate).then((newNumber) {
        if (invoiceNoCtrl.text == initialInvoiceNo || invoiceNoCtrl.text.isEmpty) {
          invoiceNoCtrl.text = newNumber;
        }
      });
    }
    final invoiceAmountCtrl = TextEditingController(
      text: existingMaterial != null && existingMaterial.invoiceAmount > 0
          ? existingMaterial.invoiceAmount.toStringAsFixed(2)
          : '',
    );
    final vatAmountCtrl = TextEditingController(
      text: existingMaterial != null && existingMaterial.vatAmount > 0
          ? existingMaterial.vatAmount.toStringAsFixed(2)
          : '',
    );
    final remarksCtrl = TextEditingController(text: existingMaterial?.remarks ?? '');
    final dateFormat = DateFormat('yyyy-MM-dd');
    bool isSaving = false;

    // Pre-populate existing attachments if editing
    final List<AttachmentItem> attachmentsList = [];
    if (existingMaterial != null && existingMaterial.attachments.isNotEmpty) {
      for (final att in existingMaterial.attachments) {
        attachmentsList.add(AttachmentItem(
          name: att.name,
          type: att.type,
          size: att.size ?? 0,
          url: att.url,
        ));
      }
    }

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final invVal = double.tryParse(invoiceAmountCtrl.text.trim()) ?? 0.0;
            final vatVal = double.tryParse(vatAmountCtrl.text.trim()) ?? 0.0;
            final previewTotal = invVal + vatVal;

            return AlertDialog(
              title: Text(existingMaterial == null ? 'Add Material Cost' : 'Edit Material Cost'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width > 500 ? 460 : double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Date
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text('Date: ${dateFormat.format(entryDate)}', style: const TextStyle(fontSize: 14)),
                          trailing: const Icon(Icons.calendar_today, size: 20, color: Color(0xFF0B5ED7)),
                          onTap: isSaving
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: entryDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => entryDate = picked);
                                  }
                                },
                        ),
                        const SizedBox(height: 14),

                        // 2. Supplier Name
                        TextFormField(
                          controller: supplierCtrl,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Supplier Name *',
                            hintText: 'e.g. Judin, Gulf ReadyMix',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Supplier name is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // 3. Invoice Number
                        TextFormField(
                          controller: invoiceNoCtrl,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: 'Invoice Number',
                            hintText: 'e.g. ${InvoiceNumberService.generateInitialMaterialInvoiceNumber(entryDate)}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              tooltip: 'Regenerate Invoice Number',
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final next = await InvoiceNumberService.fetchNextMaterialInvoiceNumber(
                                        siteId: widget.siteId,
                                        date: entryDate,
                                      );
                                      setDialogState(() {
                                        invoiceNoCtrl.text = next;
                                      });
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Invoice Amount
                        TextFormField(
                          controller: invoiceAmountCtrl,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Invoice Amount *',
                            prefixText: 'BHD ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Invoice amount is required' : null,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // 5. VAT Amount
                        TextFormField(
                          controller: vatAmountCtrl,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'VAT Amount',
                            prefixText: 'BHD ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 12),

                        // Calculated Total Preview
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF0B5ED7).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total (Invoice + VAT):',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0A2540)),
                              ),
                              Text(
                                currencyFormat.format(previewTotal),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0B5ED7)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 6. Remarks
                        TextFormField(
                          controller: remarksCtrl,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Remarks / Material Description',
                            hintText: 'e.g. High-Tensile Reinforcement Mesh, 45m³ Grade 40',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 18),

                        // 7. ATTACHMENT SECTION (PHOTO / PDF / EXCEL IMPORT)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_file, size: 18, color: Color(0xFF0A2540)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Attachments (${attachmentsList.length})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      backgroundColor: const Color(0xFF0B5ED7),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: isSaving
                                        ? null
                                        : () => _showAttachmentSourceSheet(context, (item) {
                                              setDialogState(() {
                                                attachmentsList.add(item);
                                              });
                                            }),
                                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                                    label: const Text('Add / Import', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              if (attachmentsList.isEmpty) ...[
                                const SizedBox(height: 10),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: isSaving
                                      ? null
                                      : () => _showAttachmentSourceSheet(context, (item) {
                                            setDialogState(() {
                                              attachmentsList.add(item);
                                            });
                                          }),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.blue.shade50.withValues(alpha: 0.3),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.camera_alt, size: 20, color: Colors.blue.shade700),
                                            const SizedBox(width: 12),
                                            Icon(Icons.photo_library, size: 20, color: Colors.green.shade700),
                                            const SizedBox(width: 12),
                                            Icon(Icons.picture_as_pdf, size: 20, color: Colors.red.shade700),
                                            const SizedBox(width: 12),
                                            Icon(Icons.table_chart, size: 20, color: Colors.teal.shade700),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Tap here to Take Photo or Import File',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF0B5ED7), fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Attach camera photos, PDFs, Excel bills & sheets',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 10),
                                ...attachmentsList.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildAttachmentThumbnail(item),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: _getBadgeBgColor(item.type),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      item.type.toUpperCase(),
                                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getBadgeTextColor(item.type)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _formatFileSize(item.size),
                                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                                  ),
                                                  if (item.isUploaded) ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(Icons.cloud_done, size: 12, color: Color(0xFF137333)),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isSaving)
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                            tooltip: 'Remove',
                                            onPressed: () {
                                              setDialogState(() {
                                                attachmentsList.removeAt(index);
                                              });
                                            },
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
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2540),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(dialogContext);

                            try {
                              // Upload newly picked attachments with bytes
                              final List<Map<String, dynamic>> finalAttachments = [];

                              for (final att in attachmentsList) {
                                if (att.isUploaded) {
                                  finalAttachments.add({
                                    'name': att.name,
                                    'url': att.url!,
                                    'type': att.type,
                                    'size': att.size,
                                  });
                                } else if (att.bytes != null) {
                                  final uploadedUrl = await _uploadAttachmentBytes(
                                    siteId: widget.siteId,
                                    fileName: att.name,
                                    bytes: att.bytes!,
                                    type: att.type,
                                  );
                                  if (uploadedUrl != null) {
                                    finalAttachments.add({
                                      'name': att.name,
                                      'url': uploadedUrl,
                                      'type': att.type,
                                      'size': att.size,
                                    });
                                  }
                                }
                              }

                              String finalRemarks = remarksCtrl.text.trim();
                              if (finalAttachments.isNotEmpty) {
                                finalRemarks = jsonEncode({
                                  'text': remarksCtrl.text.trim(),
                                  'attachments': finalAttachments,
                                });
                              }

                              final data = {
                                'date': entryDate.toIso8601String(),
                                'supplier_name': supplierCtrl.text.trim(),
                                'invoice_number': invoiceNoCtrl.text.trim(),
                                'invoice_amount': double.tryParse(invoiceAmountCtrl.text.trim()) ?? 0,
                                'vat_amount': double.tryParse(vatAmountCtrl.text.trim()) ?? 0,
                                'remarks': finalRemarks,
                              };

                              nav.pop();

                              if (existingMaterial == null) {
                                await _apiService.createMaterial(widget.siteId, data);
                                messenger.showSnackBar(const SnackBar(content: Text('Material entry added successfully!')));
                              } else {
                                await _apiService.updateMaterial(existingMaterial.id, data);
                                messenger.showSnackBar(const SnackBar(content: Text('Material entry updated successfully!')));
                              }

                              _loadMaterials();
                              widget.onDataChanged?.call();
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              messenger.showSnackBar(SnackBar(content: Text('Error saving material: $e')));
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existingMaterial == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openExternalUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open link: $e')));
      }
    }
  }

  void _previewImage(BuildContext context, String url, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 36.0),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: url.startsWith('data:')
                            ? Image.memory(base64Decode(url.split(',').last))
                            : CachedNetworkImage(
                                imageUrl: url,
                                placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                                errorWidget: (c, u, e) => const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image, color: Colors.white, size: 48),
                                      SizedBox(height: 8),
                                      Text('Failed to load image', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => _openExternalUrl(context, url),
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('Open in Browser'),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewDocument(BuildContext context, MaterialAttachment attachment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            _buildAttachmentThumbnail(AttachmentItem(
              name: attachment.name,
              type: attachment.type,
              size: attachment.size ?? 0,
              url: attachment.url,
            )),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                attachment.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Document Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(attachment.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (attachment.size != null && attachment.size! > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('File Size', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(_formatFileSize(attachment.size!), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      attachment.url,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0B5ED7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2540),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openExternalUrl(context, attachment.url);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open / Download'),
          ),
        ],
      ),
    );
  }

  void _showMaterialDetails(MaterialCost item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.supplierName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Received', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                Text(item.remarks!, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 16),
              ],
              const Divider(),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Invoice Number', style: TextStyle(color: Colors.grey, fontSize: 12)),
                subtitle: Text(item.invoiceNumber ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Date', style: TextStyle(color: Colors.grey, fontSize: 12)),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(item.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Invoice Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                subtitle: Text(currencyFormat.format(item.invoiceAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('VAT Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                subtitle: Text(currencyFormat.format(item.vatAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Total Amount (Invoice + VAT)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                subtitle: Text(currencyFormat.format(item.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B5ED7))),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ATTACHMENTS (${item.attachments.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showAddOrEditDialog(existingMaterial: item);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add / Manage', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.attachments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                  child: const Center(
                    child: Text('No attachments attached to this invoice yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                )
              else
                ...item.attachments.map((att) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: _buildAttachmentThumbnail(AttachmentItem(
                          name: att.name,
                          type: att.type,
                          size: att.size ?? 0,
                          url: att.url,
                        )),
                        title: Text(att.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${att.type.toUpperCase()} • ${_formatFileSize(att.size ?? 0)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF0B5ED7)),
                        onTap: () {
                          if (att.type == 'image') {
                            _previewImage(context, att.url, att.name);
                          } else {
                            _previewDocument(context, att);
                          }
                        },
                      ),
                    )),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showAddOrEditDialog(existingMaterial: item);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Material'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2540),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMaterial(MaterialCost item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material Cost?'),
        content: Text('Are you sure you want to delete invoice "${item.invoiceNumber ?? item.supplierName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _apiService.deleteMaterial(item.id);
                _loadMaterials();
                widget.onDataChanged?.call();
                messenger.showSnackBar(const SnackBar(content: Text('Material entry deleted')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error deleting material: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Sort Materials By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              title: const Text('Date: Newest First'),
              trailing: _sortBy == 'date_desc' ? const Icon(Icons.check, color: Color(0xFF0B5ED7)) : null,
              onTap: () {
                setState(() => _sortBy = 'date_desc');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Date: Oldest First'),
              trailing: _sortBy == 'date_asc' ? const Icon(Icons.check, color: Color(0xFF0B5ED7)) : null,
              onTap: () {
                setState(() => _sortBy = 'date_asc');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Amount: Highest First'),
              trailing: _sortBy == 'amount_desc' ? const Icon(Icons.check, color: Color(0xFF0B5ED7)) : null,
              onTap: () {
                setState(() => _sortBy = 'amount_desc');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Amount: Lowest First'),
              trailing: _sortBy == 'amount_asc' ? const Icon(Icons.check, color: Color(0xFF0B5ED7)) : null,
              onTap: () {
                setState(() => _sortBy = 'amount_asc');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: FutureBuilder<List<MaterialCost>>(
        future: _materialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rawList = snapshot.data ?? [];
          
          // Apply search filter
          var filteredList = rawList.where((item) {
            if (_searchQuery.isEmpty) return true;
            final sup = item.supplierName.toLowerCase();
            final inv = (item.invoiceNumber ?? '').toLowerCase();
            final rem = (item.remarks ?? '').toLowerCase();
            return sup.contains(_searchQuery) || inv.contains(_searchQuery) || rem.contains(_searchQuery);
          }).toList();

          // Apply sort
          filteredList.sort((a, b) {
            switch (_sortBy) {
              case 'date_asc':
                return a.date.compareTo(b.date);
              case 'amount_desc':
                return b.totalAmount.compareTo(a.totalAmount);
              case 'amount_asc':
                return a.totalAmount.compareTo(b.totalAmount);
              case 'date_desc':
              default:
                return b.date.compareTo(a.date);
            }
          });

          final totalBilled = rawList.fold(0.0, (sum, item) => sum + item.totalAmount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // TOP 3 KPI ROW
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TOTAL BILLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(totalBilled),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          ),
                          const SizedBox(height: 2),
                          Text('${rawList.length} invoice${rawList.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RECEIVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('${rawList.length} Dispatches', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                          const SizedBox(height: 2),
                          Text('Verified on-site', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PENDING POS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          const Text('0 Drafts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                          const SizedBox(height: 2),
                          Text('Awaiting sign-off', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // SEARCH & SORT BAR
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search, size: 18, color: Colors.grey),
                          hintText: 'Search invoice, material supplier...',
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showSortMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _sortBy.startsWith('amount') ? 'Sort: Amount' : 'Sort: Date',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.unfold_more, size: 14, color: Color(0xFF0B5ED7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MATERIAL INVOICES (${filteredList.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                  ),
                  if (rawList.isNotEmpty)
                    Text(
                      'Total: ${currencyFormat.format(filteredList.fold(0.0, (sum, i) => sum + i.totalAmount))}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (rawList.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'No Material Invoices Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2540)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the "Add / Import" button above to record your first material delivery or invoice.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (filteredList.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('No material invoices match "$_searchQuery"', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ] else
                ...filteredList.map(
                  (item) => _buildMaterialCard(
                    supplier: item.supplierName,
                    status: 'Received',
                    statusBg: const Color(0xFFE6F4EA),
                    statusColor: const Color(0xFF137333),
                    title: item.remarks != null && item.remarks!.isNotEmpty ? item.remarks! : item.supplierName,
                    invNo: item.invoiceNumber ?? 'N/A',
                    date: DateFormat('yyyy-MM-dd').format(item.date),
                    invoiceAmount: item.invoiceAmount,
                    vatAmount: item.vatAmount,
                    item: item,
                  ),
                ),
            ],
          );
        },
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2540),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showAddOrEditDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('ADD MATERIAL COST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard({
    required String supplier,
    required String status,
    required Color statusBg,
    required Color statusColor,
    required String title,
    required String invNo,
    required String date,
    required double invoiceAmount,
    double vatAmount = 0.0,
    MaterialCost? item,
  }) {
    final totalAmount = invoiceAmount + vatAmount;
    final attachments = item?.attachments ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item != null ? () => _showMaterialDetails(item) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            supplier.isNotEmpty ? supplier[0].toUpperCase() : 'M',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(supplier, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormat.format(invoiceAmount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total: ${currencyFormat.format(totalAmount)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                            ),
                          ],
                        ),
                        if (item != null) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                            onSelected: (val) {
                              if (val == 'details') {
                                _showMaterialDetails(item);
                              } else if (val == 'edit') {
                                _showAddOrEditDialog(existingMaterial: item);
                              } else if (val == 'delete') {
                                _confirmDeleteMaterial(item);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'details',
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Color(0xFF0B5ED7)),
                                    SizedBox(width: 8),
                                    Text('View Details'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16, color: Colors.black87),
                                    SizedBox(width: 8),
                                    Text('Edit & Attachments'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0A2540))),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Inv: $invNo   •   📅 $date', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    if (attachments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE8F1FF), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file, size: 12, color: Color(0xFF0B5ED7)),
                            const SizedBox(width: 2),
                            Text(
                              '${attachments.length} file${attachments.length > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                            ),
                          ],
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Inv: ${currencyFormat.format(invoiceAmount)}  +  VAT: ${currencyFormat.format(vatAmount)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Total: ${currencyFormat.format(totalAmount)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                      ),
                    ],
                  ),
                ),

                // ATTACHMENT CHIPS (IF ANY)
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: attachments.length,
                      separatorBuilder: (ctx, i) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) {
                        final att = attachments[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (att.type == 'image') {
                              _previewImage(context, att.url, att.name);
                            } else {
                              _previewDocument(context, att);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getBadgeBgColor(att.type),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getBadgeTextColor(att.type).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getFileIcon(att.type), size: 14, color: _getBadgeTextColor(att.type)),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 120),
                                  child: Text(
                                    att.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getBadgeTextColor(att.type)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
