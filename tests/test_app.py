from app import create_app
from database import close_db, get_db


def test_home_and_health(client):
    assert b"ACEest Fitness" in client.get("/").data
    assert client.get("/health").get_json()["status"] == "ok"


def test_programs(client):
    response = client.get("/programs")
    assert response.status_code == 200
    assert set(response.get_json()) == {"Fat Loss", "Muscle Gain", "Beginner"}


def test_create_list_and_retrieve(client, valid_client):
    assert client.get("/clients").get_json() == []
    response = client.post("/clients", json=valid_client)
    assert response.status_code == 201
    saved = response.get_json()
    assert saved["calories"] == 1540
    assert saved["name"] == valid_client["name"]
    assert client.get(f'/clients/{saved["id"]}').get_json() == saved
    assert client.get("/clients").get_json() == [saved]


def test_missing_client(client):
    assert client.get("/clients/999").status_code == 404
    assert client.get("/clients/999/progress").status_code == 404
    assert client.post("/clients/999/progress", json={}).status_code == 404


def test_invalid_client_does_not_save(client):
    response = client.post("/clients", json={"name": ""})
    assert response.status_code == 400
    assert "error" in response.get_json()
    assert client.get("/clients").get_json() == []


def test_malformed_and_non_object_json(client):
    assert client.post("/clients", data="{bad", content_type="application/json").status_code == 400
    assert client.post("/clients", json=[]).status_code == 400
    assert client.post("/clients", data="text").status_code == 400


def test_progress_round_trip(client, valid_client):
    client_id = client.post("/clients", json=valid_client).get_json()["id"]
    url = f"/clients/{client_id}/progress"
    assert client.get(url).get_json() == []
    response = client.post(url, json={"week": "2026-10-05", "adherence": 85})
    assert response.status_code == 201
    saved = response.get_json()
    assert saved["client_id"] == client_id
    assert saved["adherence"] == 85
    assert client.get(url).get_json() == [saved]
    assert client.post(url, json={"week": "2026-10-05", "adherence": 101}).status_code == 400
    assert len(client.get(url).get_json()) == 1


def test_clients_have_separate_progress(client, valid_client):
    first = client.post("/clients", json=valid_client).get_json()["id"]
    second = client.post("/clients", json=valid_client).get_json()["id"]
    client.post(f"/clients/{first}/progress", json={"week": "2026-10-05", "adherence": 50})
    assert client.get(f"/clients/{second}/progress").get_json() == []


def test_database_persists_between_app_instances(tmp_path, valid_client):
    config = {"TESTING": True, "DATABASE": str(tmp_path / "persistent.db")}
    first = create_app(config).test_client()
    first.post("/clients", json=valid_client)
    second = create_app(config).test_client()
    assert len(second.get("/clients").get_json()) == 1


def test_connection_is_reused_and_close_without_connection(app):
    with app.app_context():
        assert get_db() is get_db()
        close_db()
        close_db()


def test_sql_like_name_is_stored_as_data(client, valid_client):
    valid_client["name"] = "Student'); DROP TABLE clients; --"
    assert client.post("/clients", json=valid_client).status_code == 201
    assert len(client.get("/clients").get_json()) == 1
