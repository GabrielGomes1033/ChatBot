import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/services/api_endpoint_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('normaliza URL digitada pelo usuario', () {
    final expectedLocal = 'http://192.168.0.25:${ApiEndpointConfig.apiPort}';
    expect(
      ApiEndpointConfig.normalizeBaseUrl('$expectedLocal/'),
      expectedLocal,
    );
    expect(
      ApiEndpointConfig.normalizeBaseUrl(' nova.local/api/ '),
      'http://nova.local/api',
    );
  });

  test('usa override local quando informado', () {
    final config = ApiEndpointConfig.resolve(
      explicitBaseUrl: 'api.minha-rede.local:9000',
    );

    expect(config.baseUrl, 'http://api.minha-rede.local:9000');
    expect(config.source, 'configuracao_local');
  });

  test('usa https por padrao para dominio publico sem protocolo', () {
    final config = ApiEndpointConfig.resolve(
      explicitBaseUrl: 'api.minhaapp.com',
    );

    expect(config.baseUrl, 'https://api.minhaapp.com');
    expect(config.source, 'configuracao_local');
  });

  test('faixa 172.16-31 continua local, fora dela nao', () {
    expect(
      ApiEndpointConfig.normalizeBaseUrl('172.16.0.25:9000'),
      'http://172.16.0.25:9000',
    );
    expect(
      ApiEndpointConfig.normalizeBaseUrl('172.15.0.25:9000'),
      'https://172.15.0.25:9000',
    );
  });

  test('android usa alias do emulador por padrao', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final config = ApiEndpointConfig.resolve();

    expect(config.baseUrl, 'http://10.0.2.2:${ApiEndpointConfig.apiPort}');
    expect(config.source, 'android_emulador');
  });

  test('gera candidatos de fallback para desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final candidates = ApiEndpointConfig.candidates();

    expect(candidates.first.baseUrl,
        'http://127.0.0.1:${ApiEndpointConfig.apiPort}');
    expect(
      candidates.map((item) => item.baseUrl),
      contains('http://localhost:${ApiEndpointConfig.apiPort}'),
    );
  });

  test('desktop usa localhost por padrao', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final config = ApiEndpointConfig.resolve();

    expect(config.baseUrl, 'http://127.0.0.1:${ApiEndpointConfig.apiPort}');
    expect(config.source, 'localhost');
  });
}
