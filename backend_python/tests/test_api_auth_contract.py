from __future__ import annotations

from pathlib import Path
import os
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient

from api.app import create_app
from core import runtime_guard


class ApiAuthContractTests(unittest.TestCase):
    def setUp(self) -> None:
        runtime_guard._BUCKETS.clear()

    def tearDown(self) -> None:
        runtime_guard._BUCKETS.clear()

    def _build_client(self, token: str | None):
        env = {
            "NOVA_API_TOKENS": "",
        }
        if token is not None:
            env["NOVA_API_TOKEN"] = token
        else:
            env["NOVA_API_TOKEN"] = ""

        return patch.dict(os.environ, env, clear=False)

    def test_public_health_route_stays_open(self) -> None:
        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            response = client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["ok"])

    def test_protected_route_requires_token(self) -> None:
        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            response = client.get("/ops/status")

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "unauthorized")

    def test_protected_route_remains_closed_without_any_configured_token(self) -> None:
        with self._build_client(None), TestClient(create_app()) as client:
            response = client.get("/ops/status")

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "unauthorized")

    def test_protected_route_accepts_x_api_key(self) -> None:
        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            response = client.get(
                "/ops/status",
                headers={"X-API-Key": "contrato-token"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["ok"])

    def test_protected_route_accepts_bearer_token(self) -> None:
        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            response = client.get(
                "/system/status",
                headers={"Authorization": "Bearer contrato-token"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["ok"])

    def test_documents_analyze_requires_token_and_accepts_valid_key(self) -> None:
        payload = {
            "filename": "contrato.txt",
            "content_base64": "VGVzdGUgZGUgY29udHJhdG8gZGUgYXV0ZW50aWNhY2FvLg==",
        }

        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            unauthorized = client.post("/documents/analyze", json=payload)
            authorized = client.post(
                "/documents/analyze",
                json=payload,
                headers={"X-API-Key": "contrato-token"},
            )

        self.assertEqual(unauthorized.status_code, 401)
        self.assertEqual(authorized.status_code, 200)
        self.assertTrue(authorized.json()["ok"])

    def test_documents_inspect_stays_open_without_token(self) -> None:
        payload = {
            "filename": "contrato.txt",
            "content_base64": "VGVzdGUgZGUgY29udHJhdG8gZGUgYXV0ZW50aWNhY2FvLg==",
        }

        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            response = client.post("/documents/inspect", json=payload)

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["ok"])

    def test_sensitive_routes_require_token_after_hardening(self) -> None:
        protected = [
            ("GET", "/actions/tools"),
            ("GET", "/memory/recent?user_id=frontend"),
            ("GET", "/brain/graph"),
            ("GET", "/knowledge"),
            ("GET", "/observability/summary"),
            ("GET", "/reminders"),
            ("GET", "/location/current"),
            ("POST", "/voice/neural"),
        ]

        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            for method, path in protected:
                response = client.request(method, path, json={})
                self.assertEqual(
                    response.status_code,
                    401,
                    msg=f"Route should be protected: {method} {path}",
                )

    def test_sensitive_routes_accept_valid_token_after_hardening(self) -> None:
        headers = {"X-API-Key": "contrato-token"}

        with self._build_client("contrato-token"), TestClient(create_app()) as client:
            tools = client.get("/actions/tools", headers=headers)
            self.assertEqual(tools.status_code, 200)
            self.assertTrue(tools.json()["ok"])

            memories = client.get("/memory/recent?user_id=frontend", headers=headers)
            self.assertEqual(memories.status_code, 200)
            self.assertTrue(memories.json()["ok"])

            brain = client.get("/brain/graph", headers=headers)
            self.assertEqual(brain.status_code, 200)
            self.assertTrue(brain.json()["ok"])

    def test_cors_can_be_restricted_by_env(self) -> None:
        env = {
            "NOVA_API_TOKEN": "contrato-token",
            "NOVA_API_TOKENS": "",
            "NOVA_API_CORS_ORIGINS": "https://app.example.com,https://admin.example.com",
        }

        with patch.dict(os.environ, env, clear=False), TestClient(create_app()) as client:
            response = client.options(
                "/voice/status",
                headers={
                    "Origin": "https://app.example.com",
                    "Access-Control-Request-Method": "GET",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["access-control-allow-origin"], "https://app.example.com")


if __name__ == "__main__":
    unittest.main()
