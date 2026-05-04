import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/services/chat_api.dart';
import 'package:http/http.dart' as http;

void main() {
  test('envia cabecalhos de autenticacao quando token da API esta configurado',
      () async {
    Map<String, String>? capturedHeaders;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      apiToken: 'segredo-api',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        capturedHeaders = Map<String, String>.from(headers);
        expect(method, 'GET');
        expect(uri.toString(), 'http://127.0.0.1:8000/ops/status');
        return http.Response(jsonEncode({'ok': true}), 200);
      },
    );

    final payload = await service.getOpsStatus();

    expect(payload['ok'], isTrue);
    expect(capturedHeaders?['X-API-Key'], 'segredo-api');
    expect(capturedHeaders?['Authorization'], 'Bearer segredo-api');
  });

  test('nao envia X-API-Key quando token da API esta vazio', () async {
    Map<String, String>? capturedHeaders;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        capturedHeaders = Map<String, String>.from(headers);
        expect(uri.toString(), 'http://127.0.0.1:8000/health');
        return http.Response(jsonEncode({'ok': true}), 200);
      },
    );

    final payload = await service.getHealthProfile();

    expect(payload['ok'], isTrue);
    expect(capturedHeaders?.containsKey('X-API-Key'), isFalse);
  });

  test('updateApiToken autentica chamadas seguintes', () async {
    Map<String, String>? capturedHeaders;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        capturedHeaders = Map<String, String>.from(headers);
        expect(uri.toString(), 'http://127.0.0.1:8000/system/status');
        return http.Response(jsonEncode({'ok': true}), 200);
      },
    );

    service.updateApiToken('novo-token');
    final payload = await service.getSystemStatus();

    expect(payload['ok'], isTrue);
    expect(capturedHeaders?['X-API-Key'], 'novo-token');
  });

  test('analyzeDocument usa inspect quando analyze retorna 401', () async {
    final calls = <String>[];

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      apiToken: 'segredo-api',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        calls.add(uri.toString());
        expect(method, 'POST');
        if (uri.path == '/documents/analyze') {
          return http.Response(jsonEncode({'detail': 'unauthorized'}), 401);
        }
        if (uri.path == '/documents/inspect') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'report': {
                'file_name': 'teste.pdf',
                'executive_summary': 'Resumo via inspect.',
              },
              'learning': {'ok': false, 'skipped': true},
            }),
            200,
          );
        }
        fail('Chamada inesperada: ${uri.toString()}');
      },
    );

    final payload = await service.analyzeDocument(
      fileName: 'teste.pdf',
      bytes: Uint8List.fromList(utf8.encode('conteudo de teste para analise')),
    );

    expect(payload['ok'], isTrue);
    expect(calls, [
      'http://127.0.0.1:8000/documents/analyze',
      'http://127.0.0.1:8000/documents/inspect',
    ]);
  });

  test('analyzeImageInsights envia payload estruturado para o backend',
      () async {
    late Map<String, dynamic> body;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        expect(method, 'POST');
        expect(uri.toString(), 'http://127.0.0.1:8000/images/inspect');
        body = jsonDecode(encodedBody!) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'report': {'executive_summary': 'Resumo remoto de imagem.'},
          }),
          200,
        );
      },
    );

    final payload = await service.analyzeImageInsights(
      fileName: 'foto.jpg',
      recognizedText: 'Museu do Ipiranga',
      labels: const [
        {'label': 'Museum', 'confidence': 0.93},
      ],
      metadata: const {'width': 1080, 'height': 720},
      fromCamera: true,
      byteSize: 2048,
    );

    expect(payload['ok'], isTrue);
    expect(body['filename'], 'foto.jpg');
    expect(body['recognized_text'], 'Museu do Ipiranga');
    expect(body['labels'], isNotEmpty);
    expect(body['metadata']['width'], 1080);
    expect(body['from_camera'], isTrue);
    expect(body['byte_size'], 2048);
  });

  test('sendJarvisMessage inclui file_id e contexto adicional', () async {
    late Map<String, dynamic> body;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        expect(method, 'POST');
        expect(uri.toString(), 'http://127.0.0.1:8000/chat');
        body = jsonDecode(encodedBody!) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'reply': 'Arquivo analisado com sucesso.',
          }),
          200,
        );
      },
    );

    final payload = await service.sendJarvisMessage(
      'Analise o anexo',
      userId: 'gabriel',
      fileId: 'arquivo_123',
      context: 'interface do projeto NOVA',
    );

    expect(payload['ok'], isTrue);
    expect(body['user_id'], 'gabriel');
    expect(body['file_id'], 'arquivo_123');
    expect(body['context'], 'interface do projeto NOVA');
  });

  test('uploadFile e analyzeUploadedFile usam o contrato novo de arquivos',
      () async {
    final calls = <String>[];
    late Map<String, dynamic> uploadBody;
    late Map<String, dynamic> analyzeBody;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        calls.add(uri.toString());
        final decoded = jsonDecode(encodedBody!) as Map<String, dynamic>;
        if (uri.path == '/files/upload') {
          uploadBody = decoded;
          return http.Response(
            jsonEncode({
              'ok': true,
              'file_id': 'file_001',
            }),
            200,
          );
        }
        if (uri.path == '/files/analyze') {
          analyzeBody = decoded;
          return http.Response(
            jsonEncode({
              'ok': true,
              'answer': 'Analisei o arquivo enviado.',
              'next_actions': const ['Gerar codigo'],
            }),
            200,
          );
        }
        fail('Chamada inesperada: ${uri.toString()}');
      },
    );

    final upload = await service.uploadFile(
      fileName: 'briefing.txt',
      bytes: Uint8List.fromList(utf8.encode('conteudo importante')),
      mimeType: 'text/plain',
    );
    final analysis = await service.analyzeUploadedFile(
      fileId: upload['file_id'].toString(),
      question: 'Resuma isso',
      context: 'Projeto NOVA',
    );

    expect(upload['file_id'], 'file_001');
    expect(analysis['ok'], isTrue);
    expect(uploadBody['filename'], 'briefing.txt');
    expect(uploadBody['mime_type'], 'text/plain');
    expect(analyzeBody['file_id'], 'file_001');
    expect(analyzeBody['question'], 'Resuma isso');
    expect(analyzeBody['context'], 'Projeto NOVA');
    expect(calls, [
      'http://127.0.0.1:8000/files/upload',
      'http://127.0.0.1:8000/files/analyze',
    ]);
  });

  test('brain endpoints carregam notas e sugestoes do vault', () async {
    final called = <String>[];

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        called.add(uri.toString());
        if (uri.path == '/brain/notes') {
          expect(method, 'GET');
          return http.Response(
            jsonEncode({
              'ok': true,
              'items': [
                {'title': 'Atlas', 'excerpt': 'Projeto Atlas em andamento.'},
              ],
            }),
            200,
          );
        }
        if (uri.path == '/brain/suggestions') {
          expect(method, 'GET');
          return http.Response(
            jsonEncode({
              'ok': true,
              'items': [
                {'source': 'Atlas', 'target': 'CRM'},
              ],
            }),
            200,
          );
        }
        fail('Chamada inesperada: ${uri.toString()}');
      },
    );

    final notes = await service.getBrainNotes(limit: 5);
    final suggestions = await service.getBrainSuggestions(limit: 4);

    expect(notes.single['title'], 'Atlas');
    expect(suggestions.single['target'], 'CRM');
    expect(called, [
      'http://127.0.0.1:8000/brain/notes?query=&limit=5',
      'http://127.0.0.1:8000/brain/suggestions?note_ref=&limit=4',
    ]);
  });

  test('saveBrainNote envia markdown para o backend', () async {
    late Map<String, dynamic> body;

    final service = ChatApiService(
      baseUrl: 'http://127.0.0.1:8000',
      httpExecutor: (
        String method,
        Uri uri, {
        required Map<String, String> headers,
        String? encodedBody,
      }) async {
        expect(method, 'POST');
        expect(uri.toString(), 'http://127.0.0.1:8000/brain/notes');
        body = jsonDecode(encodedBody!) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'note': {'title': 'Nova Nota', 'path': 'projetos/Nova Nota.md'},
          }),
          200,
        );
      },
    );

    final note = await service.saveBrainNote(
      title: 'Nova Nota',
      content: 'Conteudo com [[Ligacoes]].',
      folder: 'projetos',
    );

    expect(note['title'], 'Nova Nota');
    expect(body['folder'], 'projetos');
    expect(body['content'], 'Conteudo com [[Ligacoes]].');
  });
}
