# ACEest Fitness and Gym DevOps Assignment

A Flask adaptation of selected program/calorie logic from the supplied ACEest 1.1 desktop baseline. It stores clients and weekly adherence in SQLite and demonstrates automated build/test validation through GitHub Actions and the university lab's existing Jenkins.

## Features

- Browser page for registration and weekly progress.
- Fat Loss, Muscle Gain and Beginner programs.
- Sample calorie calculation: integer of weight multiplied by 22, 35 or 26.
- Persistent client storage and progress records.
- JSON validation and HTTP 400/404 handling.
- Health endpoint checking database access.

These calorie estimates are assignment sample logic, not nutrition advice. Use fictional data; this sample has no authentication. Login, billing, PDF exports and charts are outside this implementation.

## Rocky Linux local setup

Requires Python 3.9 or later, Git and Docker. The university lab supplies these.

~~~bash
cd ~/workspace/aceest-fitness
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m flask --app app run --host 127.0.0.1 --port 5000
~~~

Open http://127.0.0.1:5000 in the VM browser. Stop with Ctrl+C. The database is created at instance/aceest.db.

## Manual validation

~~~bash
.venv/bin/python -m compileall -q app.py services.py database.py tests
.venv/bin/python -m ruff check .
.venv/bin/python -m pytest -q --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90
~~~

Tests cover calculation factors, boundary/invalid inputs, API status codes, isolated progress, persistence and parameterized SQL. Temporary databases isolate tests. The 90% threshold is a project quality gate. Commands must be verified; this README does not claim an external successful run.

## API

| Method | Route | Behavior |
|---|---|---|
| GET | / | Browser interface |
| GET | /health | Database/app health |
| GET | /programs | Program data |
| GET/POST | /clients | List/create clients |
| GET | /clients/<id> | Retrieve client |
| GET/POST | /clients/<id>/progress | List/add progress |

Client JSON: name, age, weight, program. Age is an integer 1–120, weight is positive and finite, program must match a listed name. Progress JSON: week as YYYY-MM-DD, adherence as integer 0–100. Invalid input returns HTTP 400; unknown client returns HTTP 404. Names may repeat; IDs identify clients.

~~~bash
curl -i -X POST http://127.0.0.1:5000/clients -H 'Content-Type: application/json' -d '{"name":"Demo Student","age":25,"weight":70,"program":"Fat Loss"}'
~~~

This sample produces 1540 calories.

## Docker

~~~bash
docker build --target test -t aceest-fitness-test:local .
docker run --rm aceest-fitness-test:local python -m pytest -q -p no:cacheprovider --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90
docker build --target runtime -t aceest-fitness:local .
~~~

Stop local Flask before running the container. Store data inside the lab's persistent workspace:

~~~bash
mkdir -p ~/workspace/aceest-fitness/instance
sudo chown -R 10001:10001 ~/workspace/aceest-fitness/instance
docker run -d --name aceest-app -p 127.0.0.1:5000:5000 --mount type=bind,source="$HOME/workspace/aceest-fitness/instance",target=/app/instance aceest-fitness:local
~~~

If sudo is unavailable, obtain the lab-approved directory-ownership procedure before running that command. Do not broadly weaken permissions. Local Flask and Docker point to this same database file; their simultaneous execution is unnecessary.

Multi-stage builds separate runtime dependencies from test tools. Both application images run as non-root UID 10001. Gunicorn starts one worker on port 5000. Docker images use Python 3.12; local development supports Python 3.9. .dockerignore excludes generated data, environments and secrets.

## GitHub Actions

.github/workflows/main.yml triggers on every push and pull request. It compiles/lints, builds runtime and validation images, and runs Pytest inside the validation image with a coverage gate. A JUnit report is collected as an artifact when available. Mandatory failures fail CI.

## Existing lab Jenkins

Use the provided Jenkins at http://localhost:8080. Do not start another Jenkins on that port. Sign in with lab-provided credentials.

First verify the Jenkins execution node can run git and access the Docker daemon. Your student account's Docker access alone is insufficient. Create a Pipeline-from-SCM job for your public HTTPS GitHub URL, branch */main and script path Jenkinsfile.

The Jenkinsfile uses a Linux node through agent any, performs clean checkout, checks Docker access, builds both images, compiles/lints and runs containerized tests. The JUnit plugin publishes results. Run once manually to load SCM polling; new main commits are then detected about every two minutes while Jenkins is running.

Actions and Jenkins independently validate GitHub commits. This implements build/test automation and does not claim public production deployment or registry publication.

## Files

app.py handles HTTP; services.py contains rules; database.py contains SQLite access; templates/index.html is the browser page; tests contains fixtures and cases; Dockerfile creates validation/runtime images; Jenkinsfile and .github/workflows/main.yml define pipelines. WALKTHROUGH.md gives click-by-click VM instructions.

Source/data must be kept under ~/workspace per lab policy. Push source to GitHub and save screenshots off the VM before shutdown. Jenkins data and Docker images are not assumed to survive VM destruction.

## References

- [Flask testing](https://flask.palletsprojects.com/en/stable/testing/)
- [Docker Python guide](https://docs.docker.com/guides/python/)
- [GitHub Actions Python](https://docs.github.com/en/actions/tutorials/build-and-test-code/python)
- [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/)

## Assignment scope

 The desktop baseline is adapted into flask with client registration, sample calorie estimates and weekly progress.Github actions validates pushes and pull requests; Jenkins independently validatesbuils from main.
