# NOVA

Assistente inteligente com backend em FastAPI/Python e app Flutter para Android, Web e desktop.

## O que o projeto entrega hoje

- Chat com a assistente
- Memoria e Brain Vault
- Lembretes e integracoes operacionais
- Analise de documentos e imagens
- Painel administrativo e trilhas de auditoria

## Estrutura

- `backend_python/`: API e nucleo da assistente
- `frontend_flutter/`: app principal
- `docs/`: guias tecnicos e operacionais
- `platforms/`: atalhos de execucao por plataforma
- `scripts/`: checks e automacoes locais

## Subir rapido

Backend:

```bash
cp .env.nova.example .env.nova
bash scripts/start_api.sh
```

Frontend:

```bash
cd frontend_flutter
flutter pub get
flutter run --dart-define=NOVA_API_URL=http://127.0.0.1:8000
```

Se o backend estiver com token ativo:

```bash
flutter run \
  --dart-define=NOVA_API_URL=http://127.0.0.1:8000 \
  --dart-define=NOVA_API_TOKEN=seu-token
```

## Seguranca

- Configure `NOVA_API_TOKEN` ou `NOVA_API_TOKENS` fora do ambiente local simples.
- Restrinja o CORS em produção com `NOVA_API_CORS_ORIGINS`.
- O app também permite salvar o token nas configuracoes locais seguras.

## Checks uteis

```bash
bash scripts/quick_check.sh
bash scripts/backend_quality.sh
cd frontend_flutter && flutter test
```
