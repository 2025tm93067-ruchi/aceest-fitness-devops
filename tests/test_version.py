"""Release identity and correlation checks for the deployment entry point."""

import uuid

import pytest

import wsgi


@pytest.fixture
def application(monkeypatch, tmp_path):
    monkeypatch.setenv("APP_VERSION", "9.8.7")
    monkeypatch.setenv("GIT_COMMIT", "abcdef0123456789")
    monkeypatch.setattr(wsgi.socket, "gethostname", lambda: "test-pod")
    return wsgi.create_app({"TESTING": True, "DATABASE": str(tmp_path / "version.db")})


def test_version_reports_release_identity(application):
    response = application.test_client().get("/version")
    assert response.status_code == 200
    assert response.get_json() == {
        "version": "9.8.7",
        "commit": "abcdef0123456789",
        "hostname": "test-pod",
    }


def test_version_headers_match_response(application):
    response = application.test_client().get("/version")
    assert response.headers["X-ACEest-Version"] == response.get_json()["version"]
    assert response.headers["X-ACEest-Commit"] == response.get_json()["commit"]


def test_existing_health_route_remains_available(application):
    response = application.test_client().get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"
    assert response.headers["X-ACEest-Version"] == "9.8.7"
    assert response.headers["X-ACEest-Commit"] == "abcdef0123456789"


def test_incoming_request_id_is_preserved(application):
    response = application.test_client().get("/version", headers={"X-Request-ID": "shadow-proof-123"})
    assert response.headers["X-ACEest-Request-ID"] == "shadow-proof-123"


def test_missing_request_id_is_generated_per_request(application):
    client = application.test_client()
    first = client.get("/health").headers["X-ACEest-Request-ID"]
    second = client.get("/health").headers["X-ACEest-Request-ID"]
    assert str(uuid.UUID(first)) == first
    assert str(uuid.UUID(second)) == second
    assert first != second


def test_version_logs_shadow_correlation(application, monkeypatch):
    calls = []
    monkeypatch.setattr(wsgi.logger, "info", lambda *args: calls.append(args))
    application.test_client().get("/version", headers={"X-Request-ID": "same-in-both-pods"})
    assert len(calls) == 1
    assert calls[0][1:] == ("GET", "/version", "9.8.7", "abcdef0123456789", "same-in-both-pods")


def test_version_has_local_defaults(monkeypatch, tmp_path):
    monkeypatch.delenv("APP_VERSION", raising=False)
    monkeypatch.delenv("GIT_COMMIT", raising=False)
    application = wsgi.create_app({"TESTING": True, "DATABASE": str(tmp_path / "defaults.db")})
    response = application.test_client().get("/version")
    assert response.get_json()["version"] == "2.0.0"
    assert response.get_json()["commit"] == "unknown"


def test_error_responses_include_deployment_identity(application):
    response = application.test_client().get("/route-that-does-not-exist")
    assert response.status_code == 404
    assert response.headers["X-ACEest-Version"] == "9.8.7"
    assert uuid.UUID(response.headers["X-ACEest-Request-ID"])
