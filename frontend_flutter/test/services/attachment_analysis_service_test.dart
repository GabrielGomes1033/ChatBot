import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/services/attachment_analysis_service.dart';

void main() {
  test('classifica extensao de imagem corretamente', () {
    final service = AttachmentAnalysisService();

    expect(service.isImageFileName('foto.png'), isTrue);
    expect(service.isImageFileName('recibo.JPG'), isTrue);
    expect(service.isImageFileName('contrato.pdf'), isFalse);
  });

  test('gera relatorio local de imagem com OCR e metadados', () {
    final service = AttachmentAnalysisService();

    final payload = service.buildLocalImageReport(
      fileName: 'comprovante.png',
      bytes: Uint8List.fromList(List<int>.generate(16, (i) => i)),
      recognizedText: 'Comprovante PIX Banco valor total 120 reais.',
      sourceLabel: 'camera',
      metadata: {
        'format': 'PNG',
        'width': 1080,
        'height': 1920,
        'orientation': 'retrato',
        'brightness': '142.0',
        'brightness_label': 'equilibrada',
      },
      detectedLabels: const [
        {'label': 'Receipt', 'confidence': 0.91},
      ],
      ocrStatus: 'ok',
    );

    expect(payload['ok'], isTrue);
    final report = Map<String, dynamic>.from(payload['report'] as Map);
    expect(report['analysis_type'], 'image');
    expect(report['source'], 'camera');
    expect((report['detected_labels'] as List), isNotEmpty);
    expect((report['executive_summary'] as String).toLowerCase(),
        contains('texto identificado'));
    expect((report['risks'] as List).join(' ').toLowerCase(), contains('pix'));
    expect(report['keywords'], isNotEmpty);
  });

  test('usa pesquisa remota quando ha sinais suficientes na imagem', () async {
    final service = AttachmentAnalysisService(
      ocrExecutor: (
        String fileName,
        Uint8List bytes, {
        String? filePath,
      }) async =>
          'Placa Museu do Ipiranga Sao Paulo',
      labelExecutor: (
        String fileName,
        Uint8List bytes, {
        String? filePath,
      }) async =>
          const [
        {'label': 'Museum', 'confidence': 0.93},
      ],
    );

    final payload = await service.analyzeImage(
      fileName: 'museu.jpg',
      bytes: Uint8List.fromList(List<int>.generate(24, (i) => i)),
      fromCamera: true,
      researchExecutor: ({
        required String fileName,
        required String recognizedText,
        required List<Map<String, dynamic>> labels,
        required Map<String, dynamic> metadata,
        required bool fromCamera,
        required int byteSize,
      }) async {
        expect(fileName, 'museu.jpg');
        expect(recognizedText, contains('Museu do Ipiranga'));
        expect(labels, isNotEmpty);
        expect(fromCamera, isTrue);
        expect(byteSize, 24);
        return {
          'ok': true,
          'report': {
            'executive_summary':
                'O Museu do Ipiranga fica em Sao Paulo e e um museu historico brasileiro.',
            'keywords': const [
              {'token': 'museu', 'count': 4},
            ],
            'sample_excerpts': const [
              'Consulta gerada para pesquisa: Museu do Ipiranga Sao Paulo'
            ],
          },
          'learning': const {'ok': false, 'skipped': true},
        };
      },
    );

    expect(payload['ok'], isTrue);
    final report = Map<String, dynamic>.from(payload['report'] as Map);
    expect(report['analysis_type'], 'image');
    expect((report['executive_summary'] as String).toLowerCase(),
        contains('museu do ipiranga'));
    expect((report['detected_labels'] as List), isNotEmpty);
  });
}
