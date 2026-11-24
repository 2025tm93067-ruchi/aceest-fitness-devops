# Assignment 2 integration changes

- Added `wsgi:create_app()` around the existing application factory. Existing business routes remain in `app.py`.
- Added `/version`, release identity response headers, and request IDs for deployment verification.
- Added stdout logging for `/version` requests so mirrored traffic can be correlated across pods.
- Updated the Docker runtime command to load `wsgi:create_app()` and accept version/commit build arguments.
- Added focused tests for metadata, existing health behavior, and request correlation.
- Added Jenkins quality-gate enforcement, optional DockerHub publication, optional Kubernetes deployment, and archived build evidence.
- Added Kubernetes manifests and scripts for the deployment demonstrations.

Copy this kit into the existing repository root, preserving the existing application, requirements, templates, and tests. Merge the new `tests/test_version.py` into the existing tests directory. Commit all supplied files together before rebuilding Jenkins.

Run the complete tests and Jenkins pipeline after integration. Record the actual results and URLs in the report; supplied configuration files alone do not establish successful deployment.
