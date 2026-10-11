"""ACEest Flask entry point and HTTP interface."""

import os
from pathlib import Path

from flask import Flask, jsonify, render_template, request

from database import get_db, init_db, close_db
from services import PROGRAMS, ValidationError, validate_client, validate_progress


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.update(DATABASE=os.environ.get("DATABASE", "instance/aceest.db"))
    if test_config:
        app.config.update(test_config)
    Path(app.config["DATABASE"]).parent.mkdir(parents=True, exist_ok=True)
    app.teardown_appcontext(close_db)
    with app.app_context():
        init_db()

    @app.errorhandler(ValidationError)
    def validation_error(error):
        return jsonify(error=str(error)), 400

    @app.get("/")
    def home():
        return render_template("index.html", programs=PROGRAMS)

    @app.get("/health")
    def health():
        get_db().execute("SELECT 1").fetchone()
        return jsonify(status="ok", application="ACEest Fitness & Gym")

    @app.get("/programs")
    def programs():
        return jsonify(PROGRAMS)

    @app.route("/clients", methods=["GET", "POST"])
    def clients():
        db = get_db()
        if request.method == "GET":
            return jsonify([dict(row) for row in db.execute("SELECT * FROM clients ORDER BY id")])
        data = validate_client(request.get_json(silent=True))
        cursor = db.execute(
            "INSERT INTO clients (name, age, weight, program, calories) VALUES (?, ?, ?, ?, ?)",
            (data["name"], data["age"], data["weight"], data["program"], data["calories"]),
        )
        db.commit()
        row = db.execute("SELECT * FROM clients WHERE id = ?", (cursor.lastrowid,)).fetchone()
        return jsonify(dict(row)), 201

    @app.get("/clients/<int:client_id>")
    def client(client_id):
        row = get_db().execute("SELECT * FROM clients WHERE id = ?", (client_id,)).fetchone()
        if row is None:
            return jsonify(error="Client not found"), 404
        return jsonify(dict(row))

    @app.route("/clients/<int:client_id>/progress", methods=["GET", "POST"])
    def progress(client_id):
        db = get_db()
        if db.execute("SELECT id FROM clients WHERE id = ?", (client_id,)).fetchone() is None:
            return jsonify(error="Client not found"), 404
        if request.method == "GET":
            return jsonify([dict(row) for row in db.execute(
                "SELECT * FROM progress WHERE client_id = ? ORDER BY week, id", (client_id,)
            )])
        data = validate_progress(request.get_json(silent=True))
        cursor = db.execute(
            "INSERT INTO progress (client_id, week, adherence) VALUES (?, ?, ?)",
            (client_id, data["week"], data["adherence"]),
        )
        db.commit()
        row = db.execute("SELECT * FROM progress WHERE id = ?", (cursor.lastrowid,)).fetchone()
        return jsonify(dict(row)), 201

    return app
