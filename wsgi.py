"""Deployment metadata around the existing ACEest Flask application factory."""

import logging
import os
import socket
import sys
import uuid

from flask import g, jsonify, request

from app import create_app as base_create_app


logger = logging.getLogger("aceest.deployment")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
logger.propagate = False


def create_app(test_config=None):
    """Preserve the original app and add observable release information."""
    application = base_create_app(test_config)
    version = os.environ.get("APP_VERSION", "2.0.0")
    commit = os.environ.get("GIT_COMMIT", "unknown")
    hostname = socket.gethostname()

    @application.before_request
    def assign_request_id():
        g.aceest_request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())

    @application.after_request
    def add_deployment_headers(response):
        response.headers["X-ACEest-Version"] = version
        response.headers["X-ACEest-Commit"] = commit
        response.headers["X-ACEest-Request-ID"] = g.aceest_request_id
        return response

    @application.get("/version")
    def deployment_version():
        logger.info(
            "method=%s path=%s version=%s commit=%s request_id=%s",
            request.method,
            request.path,
            version,
            commit,
            g.aceest_request_id,
        )
        return jsonify(version=version, commit=commit, hostname=hostname)

    return application
