import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

typedef AttachmentOcrExecutor = Future<String> Function(
  String fileName,
  Uint8List bytes, {
  String? filePath,
});

typedef AttachmentLabelExecutor = Future<List<Map<String, dynamic>>> Function(
  String fileName,
  Uint8List bytes, {
  String? filePath,
});

typedef AttachmentResearchExecutor = Future<Map<String, dynamic>> Function({
  required String fileName,
  required String recognizedText,
  required List<Map<String, dynamic>> labels,
  required Map<String, dynamic> metadata,
  required bool fromCamera,
  required int byteSize,
});

class AttachmentAnalysisService {
  AttachmentAnalysisService({
    AttachmentOcrExecutor? ocrExecutor,
    AttachmentLabelExecutor? labelExecutor,
  })  : _ocrExecutor = ocrExecutor,
        _labelExecutor = labelExecutor;

  final AttachmentOcrExecutor? _ocrExecutor;
  final AttachmentLabelExecutor? _labelExecutor;

  static const Set<String> _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'gif',
  };

  bool isImageFileName(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) return false;
    return _imageExtensions.contains(normalized.substring(dot + 1));
  }

  Future<Map<String, dynamic>> analyzeImage({
    required String fileName,
    required Uint8List bytes,
    String? filePath,
    bool fromCamera = false,
    AttachmentResearchExecutor? researchExecutor,
  }) async {
    final metadata = _extractImageMetadata(fileName: fileName, bytes: bytes);
    final sourceLabel = fromCamera ? 'camera' : 'imagem';
    String recognizedText = '';
    String ocrStatus = 'indisponivel';
    String? ocrMessage;
    List<Map<String, dynamic>> detectedLabels = const [];
    String? labelsMessage;

    try {
      recognizedText = await _recognizeText(
        fileName,
        bytes,
        filePath: filePath,
      );
      if (recognizedText.trim().isNotEmpty) {
        ocrStatus = 'ok';
      } else {
        ocrStatus = 'sem_texto';
        ocrMessage = 'Nenhum texto legível foi identificado na imagem.';
      }
    } catch (e) {
      ocrStatus = 'erro';
      ocrMessage = e.toString().replaceFirst('Exception: ', '');
    }

    try {
      detectedLabels = await _detectLabels(
        fileName,
        bytes,
        filePath: filePath,
      );
    } catch (e) {
      labelsMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (researchExecutor != null &&
        (recognizedText.trim().isNotEmpty || detectedLabels.isNotEmpty)) {
      try {
        final remote = await researchExecutor(
          fileName: fileName,
          recognizedText: recognizedText,
          labels: detectedLabels,
          metadata: metadata,
          fromCamera: fromCamera,
          byteSize: bytes.length,
        );
        if (remote['ok'] == true) {
          return _enrichRemoteImageReport(
            remote,
            fallbackFileName: fileName,
            metadata: metadata,
            detectedLabels: detectedLabels,
            recognizedText: recognizedText,
            byteSize: bytes.length,
            sourceLabel: sourceLabel,
            ocrStatus: ocrStatus,
            ocrMessage: ocrMessage,
            labelsMessage: labelsMessage,
          );
        }
      } catch (_) {
        // Mantém fallback local quando o backend não estiver disponível.
      }
    }

    return buildLocalImageReport(
      fileName: fileName,
      bytes: bytes,
      recognizedText: recognizedText,
      sourceLabel: sourceLabel,
      metadata: metadata,
      detectedLabels: detectedLabels,
      ocrStatus: ocrStatus,
      ocrMessage: ocrMessage ?? labelsMessage,
    );
  }

  @visibleForTesting
  Map<String, dynamic> buildLocalImageReport({
    required String fileName,
    required Uint8List bytes,
    required String recognizedText,
    required String sourceLabel,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>> detectedLabels = const [],
    String ocrStatus = 'ok',
    String? ocrMessage,
  }) {
    final normalized = recognizedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = normalized.isEmpty ? <String>[] : normalized.split(' ');
    final topKeywords = _topKeywords(normalized, labels: detectedLabels);
    final risks = _detectRisks(normalized);
    final excerpts = _sampleExcerpts(normalized, labels: detectedLabels);
    final summary = _buildSummary(
      normalized,
      sourceLabel: sourceLabel,
      metadata: metadata ?? const <String, dynamic>{},
      labels: detectedLabels,
    );
    final recommendations = _buildRecommendations(
      normalized,
      sourceLabel: sourceLabel,
      ocrStatus: ocrStatus,
      metadata: metadata ?? const <String, dynamic>{},
      labels: detectedLabels,
    );

    return {
      'ok': true,
      'report': {
        'file_name': fileName,
        'generated_at': DateTime.now().toIso8601String(),
        'analysis_type': 'image',
        'source': sourceLabel,
        'stats': {
          'bytes': bytes.length,
          'chars': normalized.length,
          'words': words.length,
          'estimated_pages': normalized.isEmpty
              ? 1
              : (words.length / 450).ceil().clamp(1, 9999),
        },
        'image': metadata ?? const <String, dynamic>{},
        'detected_labels': detectedLabels,
        'recognized_text': normalized,
        'executive_summary': summary,
        'keywords': topKeywords,
        'risks': risks,
        'sample_excerpts': excerpts,
        'recommendations': recommendations,
      },
      'learning': {
        'ok': false,
        'skipped': true,
        'local_fallback': true,
        'message': ocrMessage ??
            'Análise de imagem realizada localmente no dispositivo.',
        'ocr_status': ocrStatus,
        'subject_memory': {'subjects': <String>[]},
      },
    };
  }

  Map<String, dynamic> _enrichRemoteImageReport(
    Map<String, dynamic> remote, {
    required String fallbackFileName,
    required Map<String, dynamic> metadata,
    required List<Map<String, dynamic>> detectedLabels,
    required String recognizedText,
    required int byteSize,
    required String sourceLabel,
    required String ocrStatus,
    String? ocrMessage,
    String? labelsMessage,
  }) {
    final payload = Map<String, dynamic>.from(remote);
    final report = (payload['report'] is Map)
        ? Map<String, dynamic>.from(payload['report'] as Map)
        : <String, dynamic>{};
    final stats = (report['stats'] is Map)
        ? Map<String, dynamic>.from(report['stats'] as Map)
        : <String, dynamic>{};
    final image = (report['image'] is Map)
        ? {...metadata, ...Map<String, dynamic>.from(report['image'] as Map)}
        : Map<String, dynamic>.from(metadata);
    final keywords = (report['keywords'] is List)
        ? List<Map<String, dynamic>>.from(report['keywords'] as List)
        : _topKeywords(recognizedText, labels: detectedLabels);
    final excerpts = (report['sample_excerpts'] is List)
        ? List<dynamic>.from(report['sample_excerpts'] as List)
        : _sampleExcerpts(recognizedText, labels: detectedLabels);

    report['file_name'] = report['file_name'] ?? fallbackFileName;
    report['generated_at'] =
        report['generated_at'] ?? DateTime.now().toIso8601String();
    report['analysis_type'] = 'image';
    report['source'] = report['source'] ?? sourceLabel;
    report['stats'] = {
      'bytes': stats['bytes'] ?? byteSize,
      'chars': stats['chars'] ?? recognizedText.length,
      'words': stats['words'] ??
          (recognizedText.trim().isEmpty
              ? 0
              : recognizedText.trim().split(' ').length),
      'estimated_pages': stats['estimated_pages'] ?? 1,
    };
    report['image'] = image;
    report['detected_labels'] = detectedLabels;
    report['recognized_text'] = recognizedText;
    report['keywords'] = keywords;
    report['sample_excerpts'] = excerpts;
    payload['report'] = report;

    final learning = (payload['learning'] is Map)
        ? Map<String, dynamic>.from(payload['learning'] as Map)
        : <String, dynamic>{};
    learning['ocr_status'] = ocrStatus;
    learning['message'] = learning['message'] ??
        ocrMessage ??
        labelsMessage ??
        'Pesquisa de imagem concluída.';
    payload['learning'] = learning;
    payload['ok'] = true;
    return payload;
  }

  Future<String> _recognizeText(
    String fileName,
    Uint8List bytes, {
    String? filePath,
  }) async {
    if (_ocrExecutor != null) {
      return _ocrExecutor!(fileName, bytes, filePath: filePath);
    }
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return '';
    }

    final resolvedPath =
        await _ensureFilePath(fileName, bytes, filePath: filePath);
    if (resolvedPath == null || resolvedPath.trim().isEmpty) {
      return '';
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(resolvedPath);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    } finally {
      recognizer.close();
    }
  }

  Future<List<Map<String, dynamic>>> _detectLabels(
    String fileName,
    Uint8List bytes, {
    String? filePath,
  }) async {
    if (_labelExecutor != null) {
      return _labelExecutor!(fileName, bytes, filePath: filePath);
    }
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const [];
    }

    final resolvedPath =
        await _ensureFilePath(fileName, bytes, filePath: filePath);
    if (resolvedPath == null || resolvedPath.trim().isEmpty) {
      return const [];
    }

    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.65),
    );
    try {
      final inputImage = InputImage.fromFilePath(resolvedPath);
      final labels = await labeler.processImage(inputImage);
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final item in labels) {
        final label = item.label.trim();
        if (label.isEmpty) continue;
        final key = label.toLowerCase();
        if (!seen.add(key)) continue;
        out.add({
          'label': label,
          'confidence': double.parse(item.confidence.toStringAsFixed(2)),
        });
        if (out.length >= 6) break;
      }
      return out;
    } finally {
      labeler.close();
    }
  }

  Future<String?> _ensureFilePath(
    String fileName,
    Uint8List bytes, {
    String? filePath,
  }) async {
    final existing = (filePath ?? '').trim();
    if (existing.isNotEmpty) {
      return existing;
    }
    if (kIsWeb) return null;

    final extension = _safeExtension(fileName);
    final temp = File(
      '${Directory.systemTemp.path}/nova_img_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await temp.writeAsBytes(bytes, flush: true);
    return temp.path;
  }

  String _safeExtension(String fileName) {
    final trimmed = fileName.trim();
    final dot = trimmed.lastIndexOf('.');
    if (dot >= 0 && dot < trimmed.length - 1) {
      final ext = trimmed.substring(dot).toLowerCase();
      if (ext.length <= 8) return ext;
    }
    return '.jpg';
  }

  Map<String, dynamic> _extractImageMetadata({
    required String fileName,
    required Uint8List bytes,
  }) {
    final format = img.findFormatForData(bytes);
    final decoded = img.decodeImage(bytes);
    final width = decoded?.width ?? 0;
    final height = decoded?.height ?? 0;
    final brightness = _estimateBrightness(decoded);

    return {
      'format': format.name.toUpperCase(),
      'width': width,
      'height': height,
      'orientation': _orientationLabel(width, height),
      if (brightness != null) 'brightness': brightness.toStringAsFixed(1),
      if (brightness != null) 'brightness_label': _brightnessLabel(brightness),
      'extension': _safeExtension(fileName).replaceFirst('.', '').toUpperCase(),
    };
  }

  double? _estimateBrightness(img.Image? decoded) {
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }
    final stepX = (decoded.width / 24).floor().clamp(1, decoded.width);
    final stepY = (decoded.height / 24).floor().clamp(1, decoded.height);
    var samples = 0;
    var total = 0.0;
    for (var y = 0; y < decoded.height; y += stepY) {
      for (var x = 0; x < decoded.width; x += stepX) {
        total += decoded.getPixel(x, y).luminance.toDouble();
        samples += 1;
      }
    }
    if (samples == 0) return null;
    return total / samples;
  }

  String _orientationLabel(int width, int height) {
    if (width <= 0 || height <= 0) return 'indefinida';
    if (width == height) return 'quadrada';
    return width > height ? 'paisagem' : 'retrato';
  }

  String _brightnessLabel(double brightness) {
    if (brightness < 85) return 'escura';
    if (brightness > 170) return 'clara';
    return 'equilibrada';
  }

  String _buildSummary(
    String recognizedText, {
    required String sourceLabel,
    required Map<String, dynamic> metadata,
    List<Map<String, dynamic>> labels = const [],
  }) {
    final width = metadata['width'];
    final height = metadata['height'];
    final orientation = metadata['orientation'] ?? 'indefinida';
    final labelText = labels
        .map((item) => item['label']?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .take(3)
        .join(', ');

    if (recognizedText.isNotEmpty) {
      final firstSentence = recognizedText.length > 420
          ? '${recognizedText.substring(0, 420)}...'
          : recognizedText;
      return 'Imagem analisada (${sourceLabel == "camera" ? "capturada pela câmera" : "arquivo enviado"}), '
          'com resolução $width x $height e orientação $orientation. '
          'Texto identificado: $firstSentence';
    }

    if (labelText.isNotEmpty) {
      return 'Imagem analisada (${sourceLabel == "camera" ? "capturada pela câmera" : "arquivo enviado"}), '
          'com resolução $width x $height e orientação $orientation. '
          'Os elementos mais prováveis na cena são: $labelText.';
    }

    return 'Imagem analisada (${sourceLabel == "camera" ? "capturada pela câmera" : "arquivo enviado"}), '
        'com resolução $width x $height e orientação $orientation. '
        'Não encontrei texto legível suficiente para gerar um resumo textual.';
  }

  List<Map<String, dynamic>> _topKeywords(
    String text, {
    List<Map<String, dynamic>> labels = const [],
  }) {
    if (text.isEmpty && labels.isEmpty) return const [];
    const stop = {
      'para',
      'com',
      'que',
      'uma',
      'como',
      'mais',
      'dos',
      'das',
      'nos',
      'nas',
      'por',
      'seu',
      'sua',
      'sobre',
      'este',
      'esta',
      'isso',
      'essa',
      'http',
      'https',
    };
    final matches = RegExp(r'[a-zA-ZÀ-ÿ0-9_]{4,}')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0) ?? '')
        .where((token) => token.isNotEmpty && !stop.contains(token));
    final freq = <String, int>{};
    for (final token in matches) {
      freq[token] = (freq[token] ?? 0) + 1;
    }
    for (final item in labels) {
      final label = item['label']?.toString().toLowerCase().trim() ?? '';
      if (label.isEmpty) continue;
      final confidence =
          (item['confidence'] is num) ? item['confidence'] as num : 0;
      final boost =
          confidence <= 0 ? 2 : (confidence * 10).round().clamp(1, 10);
      for (final token in RegExp(r'[a-zA-ZÀ-ÿ0-9_]{3,}').allMatches(label)) {
        final value = token.group(0) ?? '';
        if (value.isEmpty || stop.contains(value)) continue;
        freq[value] = (freq[value] ?? 0) + boost;
      }
    }
    final ordered = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordered
        .take(12)
        .map((e) => {'token': e.key, 'count': e.value})
        .toList();
  }

  List<String> _detectRisks(String text) {
    final lowered = text.toLowerCase();
    final risks = <String>[];
    final checks = {
      'senha': 'A imagem pode conter senhas ou credenciais.',
      'token': 'A imagem pode conter token ou chave de acesso.',
      'cpf': 'A imagem pode conter dado pessoal sensível (CPF).',
      'cartão': 'A imagem pode conter dado financeiro sensível.',
      'cartao': 'A imagem pode conter dado financeiro sensível.',
      'pix': 'A imagem menciona transação financeira via PIX.',
      'banco': 'A imagem parece conter contexto bancário ou comprovante.',
      'comprovante': 'A imagem parece ser um comprovante ou recibo.',
      'confidencial': 'A imagem traz marcação de conteúdo confidencial.',
    };
    checks.forEach((token, message) {
      if (lowered.contains(token)) {
        risks.add(message);
      }
    });
    return risks;
  }

  List<String> _sampleExcerpts(
    String text, {
    List<Map<String, dynamic>> labels = const [],
  }) {
    if (text.isEmpty && labels.isEmpty) return const [];
    final excerpts = <String>[];
    for (final part in reSplitSentences(text)) {
      final cleaned = part.trim();
      if (cleaned.length >= 24) {
        excerpts.add(
            cleaned.length > 280 ? '${cleaned.substring(0, 280)}...' : cleaned);
      }
      if (excerpts.length >= 4) break;
    }
    if (labels.isNotEmpty && excerpts.length < 4) {
      final labelText = labels
          .map((item) => item['label']?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .take(4)
          .join(', ');
      if (labelText.isNotEmpty) {
        excerpts.add('Objetos detectados: $labelText');
      }
    }
    return excerpts;
  }

  List<String> _buildRecommendations(
    String recognizedText, {
    required String sourceLabel,
    required String ocrStatus,
    required Map<String, dynamic> metadata,
    List<Map<String, dynamic>> labels = const [],
  }) {
    final out = <String>[
      'Revise manualmente o texto reconhecido antes de compartilhar ou arquivar.',
    ];
    if (recognizedText.isEmpty || ocrStatus != 'ok') {
      out.add(
        sourceLabel == 'camera'
            ? 'Tente fotografar novamente com mais luz, foco e enquadramento reto.'
            : 'Se a imagem estiver pequena ou desfocada, tente reenviar uma versão mais nítida.',
      );
    } else {
      out.add(
          'Se quiser, use esse conteúdo para gerar um resumo mais específico no chat.');
    }
    if (recognizedText.isEmpty && labels.isNotEmpty) {
      out.add(
          'Use os objetos detectados para pesquisar o contexto da cena, do produto ou do lugar.');
    }

    final brightness = double.tryParse('${metadata['brightness'] ?? ''}');
    if (brightness != null && brightness < 85) {
      out.add(
          'A imagem parece escura; aumente a iluminação para melhorar a leitura.');
    }
    if ((metadata['orientation'] ?? '') == 'paisagem' &&
        recognizedText.isEmpty) {
      out.add(
          'Se for um documento, tente capturar em modo retrato para melhorar o OCR.');
    }
    out.add(
        'Para aprendizado automático no backend, mantenha também a análise de documentos autenticada.');
    return out;
  }
}

List<String> reSplitSentences(String text) {
  return text.split(RegExp(r'(?<=[.!?])\s+'));
}
