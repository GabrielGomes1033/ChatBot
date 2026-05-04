import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'attachment_analysis_service.dart';
import 'chat_api.dart';

class NovaAttachment {
  const NovaAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.localPath,
    this.fromCamera = false,
    this.fileId,
    this.analysis,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? localPath;
  final bool fromCamera;
  final String? fileId;
  final Map<String, dynamic>? analysis;

  bool get isImage {
    if (mimeType.toLowerCase().startsWith('image/')) return true;
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }

  String get summary {
    final payload = analysis ?? const <String, dynamic>{};
    final answer = payload['answer']?.toString().trim() ?? '';
    if (answer.isNotEmpty) return answer;
    final nested = payload['analysis'];
    if (nested is Map) {
      final report = nested['report'];
      if (report is Map) {
        final executiveSummary =
            report['executive_summary']?.toString().trim() ?? '';
        if (executiveSummary.isNotEmpty) return executiveSummary;
      }
    }
    return '';
  }

  NovaAttachment copyWith({
    String? name,
    String? mimeType,
    Uint8List? bytes,
    String? localPath,
    bool? fromCamera,
    String? fileId,
    Map<String, dynamic>? analysis,
    bool clearFileId = false,
    bool clearAnalysis = false,
  }) {
    return NovaAttachment(
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      bytes: bytes ?? this.bytes,
      localPath: localPath ?? this.localPath,
      fromCamera: fromCamera ?? this.fromCamera,
      fileId: clearFileId ? null : (fileId ?? this.fileId),
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
    );
  }
}

class FileService {
  FileService({
    required ChatApiService api,
    required AttachmentAnalysisService attachmentAnalysis,
  })  : _api = api,
        _attachmentAnalysis = attachmentAnalysis;

  final ChatApiService _api;
  final AttachmentAnalysisService _attachmentAnalysis;

  Future<NovaAttachment?> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'bmp',
        'gif',
        'pdf',
        'txt',
        'md',
        'docx',
        'json',
        'csv',
        'log',
      ],
    );
    if (result == null || result.files.isEmpty) return null;
    return _fromPlatformFile(result.files.first);
  }

  Future<NovaAttachment> prepareAttachment(
    NovaAttachment attachment, {
    String question = '',
    String context = '',
  }) async {
    final uploaded = await uploadAttachment(attachment);
    return analyzeAttachment(
      uploaded,
      question: question,
      context: context,
    );
  }

  Future<NovaAttachment> uploadAttachment(NovaAttachment attachment) async {
    final upload = await _api.uploadFile(
      fileName: attachment.name,
      bytes: attachment.bytes,
      mimeType: attachment.mimeType,
      source: attachment.fromCamera ? 'camera' : 'upload',
    );
    return attachment.copyWith(
      fileId: upload['file_id']?.toString().trim(),
    );
  }

  Future<NovaAttachment> analyzeAttachment(
    NovaAttachment attachment, {
    String question = '',
    String context = '',
  }) async {
    final fileId = attachment.fileId?.trim() ?? '';
    if (fileId.isEmpty) {
      throw Exception('O arquivo precisa ser enviado antes da análise.');
    }

    if (attachment.isImage) {
      final local = await _attachmentAnalysis.analyzeImage(
        fileName: attachment.name,
        bytes: attachment.bytes,
        filePath: attachment.localPath,
        fromCamera: attachment.fromCamera,
      );
      final report = (local['report'] is Map)
          ? Map<String, dynamic>.from(local['report'] as Map)
          : <String, dynamic>{};
      final remote = await _api.analyzeUploadedFile(
        fileId: fileId,
        question: question,
        context: context,
        recognizedText: report['recognized_text']?.toString() ?? '',
        labels: (report['detected_labels'] is List)
            ? List<Map<String, dynamic>>.from(report['detected_labels'] as List)
            : const [],
        metadata: (report['image'] is Map)
            ? Map<String, dynamic>.from(report['image'] as Map)
            : const {},
        fromCamera: attachment.fromCamera,
      );
      return attachment.copyWith(analysis: remote);
    }

    final analyzed = await _api.analyzeUploadedFile(
      fileId: fileId,
      question: question,
      context: context,
      fromCamera: attachment.fromCamera,
    );
    return attachment.copyWith(analysis: analyzed);
  }

  Future<NovaAttachment?> _fromPlatformFile(PlatformFile file) async {
    Uint8List? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        (file.path ?? '').trim().isNotEmpty) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) return null;
    return NovaAttachment(
      name: file.name.trim().isEmpty ? 'arquivo' : file.name.trim(),
      mimeType: _guessMimeType(file.name),
      bytes: bytes,
      localPath: file.path,
    );
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt') || lower.endsWith('.log')) return 'text/plain';
    return 'application/octet-stream';
  }
}
