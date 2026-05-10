from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient

from api.app import create_app
from core import runtime_guard
import core.admin as admin_module
import core.painel_admin as painel_admin_module
from routes import chat_routes


class ApiSmokeTests(unittest.TestCase):
    def setUp(self) -> None:
        runtime_guard._BUCKETS.clear()
        chat_routes._PENDING_STRUCTURED_CHAT.clear()
        self.client = TestClient(create_app())

    def tearDown(self) -> None:
        self.client.close()
        runtime_guard._BUCKETS.clear()
        chat_routes._PENDING_STRUCTURED_CHAT.clear()

    def test_health_endpoint_returns_core_metadata(self) -> None:
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["entrypoint"], "fastapi_app")
        self.assertEqual(payload["service"], "nova-api")
        self.assertIn("/chat", payload["endpoints"])
        self.assertIn("/brain/graph", payload["endpoints"])
        self.assertIn("/brain/suggestions", payload["endpoints"])

    def test_voice_status_rate_limit_returns_429(self) -> None:
        last_ok = None
        for _ in range(120):
            last_ok = self.client.get("/voice/status")

        self.assertIsNotNone(last_ok)
        assert last_ok is not None
        self.assertEqual(last_ok.status_code, 200)

        limited = self.client.get("/voice/status")

        self.assertEqual(limited.status_code, 429)
        self.assertEqual(limited.json()["detail"]["error"], "rate_limited")

    def test_cors_preflight_options_still_passes_after_get_rate_limit(self) -> None:
        for _ in range(121):
            self.client.get("/voice/status")

        response = self.client.options(
            "/voice/status",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["access-control-allow-origin"], "http://localhost:3000")
        self.assertIn("GET", response.headers["access-control-allow-methods"])

    def test_cors_preflight_accepts_private_lan_origin_by_default(self) -> None:
        response = self.client.options(
            "/voice/status",
            headers={
                "Origin": "http://192.168.0.114:3000",
                "Access-Control-Request-Method": "POST",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://192.168.0.114:3000",
        )
        self.assertIn("POST", response.headers["access-control-allow-methods"])

    def test_chat_dev_mode_gera_codigo_e_ignora_confirmacao_pendente(self) -> None:
        chat_routes._PENDING_STRUCTURED_CHAT["default"] = {
            "tool_name": "schedule_calendar_event",
            "params": {"request_text": "agende reuniao amanha as 15:00"},
            "prompt_text": "agende reuniao",
            "mode": "normal",
        }
        generated = {
            "answer": "Entendi sua ideia: crie uma tela de login. Linguagem escolhida: Flutter.",
            "summary": "Projeto Flutter gerado.",
            "language": "flutter",
            "language_label": "Flutter",
            "project_name": "login_nova",
            "project_dir": "projetos_gerados/login_nova",
            "project_ref": "projetos_gerados/login_nova",
            "files": ["lib/main.dart"],
            "run_instructions": ["flutter pub get", "flutter run"],
            "improvements": ["Adicionar validacao"],
            "code_bundle": "// arquivo: lib/main.dart\nvoid main() {}",
            "copy_label": "Copiar codigo",
        }

        with patch(
            "routes.chat_routes.gerar_codigo_por_ideia",
            return_value=generated,
        ) as mocked_generate:
            response = self.client.post(
                "/chat",
                json={
                    "text": "Gerar codigo: crie uma tela de login\nLinguagem: flutter\nProjeto: login_nova",
                    "mode": "dev",
                    "context": "Priorizar geracao em flutter. Usar login_nova como nome do projeto.",
                },
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["type"], "dev")
        self.assertEqual(payload["language"], "flutter")
        self.assertEqual(payload["project_name"], "login_nova")
        self.assertIn("code_bundle", payload)
        self.assertNotIn("default", chat_routes._PENDING_STRUCTURED_CHAT)
        mocked_generate.assert_called_once_with(
            "crie uma tela de login",
            language="flutter",
            project_name="login_nova",
        )

    def test_auth_register_and_login_expose_consumer_flow(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            base = Path(tmpdir)
            users_file = base / "usuarios_admin.json"
            admin_file = base / "admin_config.json"
            crypto_file = base / ".nova_crypto.key"

            with patch.object(painel_admin_module, "ARQUIVO_USUARIOS", users_file), patch.object(
                admin_module,
                "ARQUIVO_ADMIN",
                admin_file,
            ), patch(
                "core.seguranca.ARQUIVO_CHAVE_CRIPTO",
                crypto_file,
            ):
                with TestClient(create_app()) as client:
                    register = client.post(
                        "/auth/register",
                        json={
                            "name": "Gabriel",
                            "email": "gabriel@example.com",
                            "password": "nova12345",
                        },
                    )
                    self.assertEqual(register.status_code, 200)
                    register_payload = register.json()
                    self.assertTrue(register_payload["ok"])
                    self.assertEqual(register_payload["session"]["email"], "gabriel@example.com")

                    login = client.post(
                        "/auth/login",
                        json={
                            "email": "gabriel@example.com",
                            "password": "nova12345",
                        },
                    )
                    self.assertEqual(login.status_code, 200)
                    login_payload = login.json()
                    self.assertTrue(login_payload["ok"])
                    self.assertEqual(login_payload["session"]["name"], "Gabriel")
                    self.assertTrue(login_payload["session"]["user_id"])


if __name__ == "__main__":
    unittest.main()
