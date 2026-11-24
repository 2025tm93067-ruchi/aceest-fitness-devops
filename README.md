# ACEest Fitness and Gym

I developed this project for the DevOps assignment using selected logic from the supplied ACEest 1.1 Python code. The Flask application supports client registration, sample calorie calculations and weekly progress tracking. It stores records in SQLite and includes automated tests, a Dockerfile, a GitHub Actions workflow and a Jenkins pipeline.

This README explains how to set up and test the project on a **Windows computer using PowerShell**. All local commands should be run from the project folder unless stated otherwise.

[Source repository](https://github.com/2025tm93067-ruchi/aceest-fitness-devops)
[GitHub Actions results](https://github.com/2025tm93067-ruchi/aceest-fitness-devops/actions)

## 1 Local setup and execution

### Install the required tools

1. Install **Python 3.12** with pip and the Python launcher. Python 3.12 matches the version used by the container and CI setup. See the [Python Windows documentation](https://docs.python.org/3.12/using/windows.html).
2. Install [Git for Windows](https://git-scm.com/downloads/win).
3. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) if you want to build and test the containers. Start Docker Desktop and use its **Linux containers** backend. The project's Python image is a Linux image.
4. Open **Windows PowerShell** from the Start menu.

Docker is not required for running Flask and Pytest directly on Windows. It is required for the container steps.

Check the installed tools:

```powershell
py -3.12 --version
git --version
docker version
```

The Docker command should display both Client and Server information when Docker Desktop is running. If a newly installed command is not recognized, close PowerShell and open it again.

### Download the project

Choose a folder on your computer where you want to keep the project. The example below uses your Documents folder:

```powershell
Set-Location ([Environment]::GetFolderPath('MyDocuments'))
git clone https://github.com/2025tm93067-ruchi/aceest-fitness-devops.git
Set-Location .\aceest-fitness-devops
```

If you already cloned the repository, open its existing folder instead of cloning it again. You should see `app.py`, `requirements.txt`, `requirements-dev.txt`, `Dockerfile` and the `tests` folder.

### Create a virtual environment and install dependencies

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
```

`requirements.txt` contains Flask and Gunicorn. `requirements-dev.txt` includes the application dependencies and adds Pytest, pytest-cov and Ruff. The commands use the virtual environment's Python executable directly, so there is no need to activate the environment or change PowerShell's execution policy.

If your Python 3.12 installation is available as `python` but not through `py`, use `python -m venv .venv` after confirming `python --version` reports Python 3.12.

### Project structure

| File or directory            | Purpose                                           |
| ---------------------------- | ------------------------------------------------- |
| `app.py`                     | Flask application factory and browser/API routes  |
| `services.py`                | Calorie calculations and input validation         |
| `database.py`                | SQLite table creation and database connections    |
| `templates/index.html`       | Client registration and weekly progress interface |
| `tests/`                     | Pytest fixtures, API tests and service tests      |
| `requirements.txt`           | Application dependencies                          |
| `requirements-dev.txt`       | Testing and lint dependencies                     |
| `pyproject.toml`             | Pytest and Ruff configuration                     |
| `Dockerfile`                 | Base, test and runtime image stages               |
| `.github/workflows/main.yml` | GitHub Actions build and test workflow            |
| `Jenkinsfile`                | Jenkins build and test pipeline                   |

### Start the application

```powershell
.\.venv\Scripts\python.exe -m flask --app app run --host 127.0.0.1 --port 5000
```

The terminal should display `Running on http://127.0.0.1:5000`. Open **http://127.0.0.1:5000** in your browser. Keep this PowerShell window running while using the application. Press **Ctrl+C** to stop the server.

The native Windows setup uses Flask's development server. Gunicorn is used inside the Linux Docker runtime image.

### Check the application

1. Register a sample client with a name, age `25`, weight `70` and program **Fat Loss**.
2. Check that the client appears in the list with a sample calorie estimate of `1540`.
3. Enter the saved client ID, a week date and adherence such as `85`, then save progress.
4. Select **View progress for entered client ID** and check the saved values.
5. Open **http://127.0.0.1:5000/health**. The response should contain `"status": "ok"`.

You can also check the health endpoint from a second PowerShell window:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:5000/health'
```

SQLite creates `instance\aceest.db` when the application starts. Restarting the application uses the same database. A client requires a nonblank name, integer age from 1 to 120, positive finite weight and a supported program. Progress requires a date in `YYYY-MM-DD` format and integer adherence from 0 to 100.

Invalid input returns HTTP 400; an unknown client ID returns HTTP 404. The API provides `/programs`, `/clients`, `/clients/<id>` and `/clients/<id>/progress`. This version focuses on basic client records and weekly progress.

### Run the application with Docker Desktop

Stop the local Flask server first so port 5000 is available. Keep Docker Desktop running in Linux containers mode.

Build the application image:

```powershell
docker build --target runtime -t aceest-fitness:local .
```

The final dot tells Docker to use the current project folder as its build context.

Create a named volume for the database and give the container's application user access to it:

```powershell
docker volume create aceest-data
docker run --rm --user 0 --mount type=volume,source=aceest-data,target=/app/instance aceest-fitness:local chown -R 10001:10001 /app/instance
```

The second command is a one-time directory-permission setup inside a temporary Linux container. The application itself runs as the non-root user `appuser` with UID and GID `10001`.

Start the application container:

```powershell
docker run -d --name aceest-app -p 127.0.0.1:5000:5000 --mount type=volume,source=aceest-data,target=/app/instance aceest-fitness:local
docker ps --filter name=aceest-app
docker logs aceest-app
docker exec aceest-app id
```

Open **http://127.0.0.1:5000** in your Windows browser. The logs should show Gunicorn starting, and the `id` command should show UID and GID `10001`.

The named volume keeps the container's database across container restarts. It is separate from the native Windows database at `instance\aceest.db`, so the two setups start with separate client records.

```powershell
docker stop aceest-app
docker start aceest-app
```

Use `docker start` if the named container already exists. If you rebuild the image and want the container to use that new image, stop and remove only the application container, then repeat the `docker run` command above:

```powershell
docker stop aceest-app
docker rm aceest-app
```

Removing this container does not remove the named database volume.

The Dockerfile uses `python:3.12-slim` and separate test and runtime stages. The runtime stage leaves out the development tools and uses Gunicorn. Dependency installation comes before source copying so Docker can reuse cached layers. `.dockerignore` excludes local environments and generated data.

## 2 Steps to run the tests manually on Windows

I used Pytest to check the application routes, business logic and database behaviour. The suite contains 11 API and database tests and 41 service test cases. The fixtures create temporary databases so tests do not modify your saved application records.

### Run compilation lint and tests

After installing `requirements-dev.txt`, run these commands in PowerShell from the project folder:

```powershell
.\.venv\Scripts\python.exe -m compileall -q app.py services.py database.py tests
.\.venv\Scripts\python.exe -m ruff check .
.\.venv\Scripts\python.exe -m pytest -q --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90
```

Successful compilation normally produces no output because `-q` enables quiet mode. Ruff should display `All checks passed!`. Pytest should show `52 passed` and a coverage summary for `app.py`, `services.py` and `database.py`.

The minimum coverage is set to 90% for this project. `--cov-report=term-missing` shows uncovered statements. A test failure or coverage below 90% produces a nonzero exit status, which the pipelines use to fail validation. Exact coverage can differ between Python versions.

To run the tests without coverage reporting:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

### What the tests check

| Area                 | Examples                                                                 |
| -------------------- | ------------------------------------------------------------------------ |
| Calorie calculations | All three program factors and fractional results                         |
| Client validation    | Empty names, invalid ages, unsupported programs and invalid weights      |
| Client API           | Create, list and retrieve records; handle malformed JSON and missing IDs |
| Weekly progress      | Save and retrieve records; validate dates and adherence boundaries       |
| Data separation      | A client's progress stays separate from another client's records         |
| Persistence          | Saved data remains available to another application instance             |
| Database handling    | Connection reuse and closure; SQL-like names are stored as data          |

The Flask test client checks routes without starting a separate server. Parameterized tests run the same logic against several inputs.

### Run tests inside Docker from PowerShell

With Docker Desktop running, build and execute the test image:

```powershell
docker build --target test -t aceest-fitness-test:local .
docker run --rm aceest-fitness-test:local python -m pytest -q -p no:cacheprovider --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90
```

The test image contains the application and development packages. `--rm` removes the test container after the command finishes. The test suite uses temporary databases and does not require `aceest-app` to be running.

### Common setup issues

| Issue                                      | Check                                                                            |
| ------------------------------------------ | -------------------------------------------------------------------------------- |
| `py` or `git` is not recognized            | Check installation and reopen PowerShell                                         |
| Flask or Pytest module is missing          | Install `requirements-dev.txt` using `.\.venv\Scripts\python.exe`                |
| Port 5000 is already in use                | Stop the earlier Flask process or `aceest-app` before starting another server    |
| Docker cannot connect to its server        | Start Docker Desktop and wait for the engine to be ready                         |
| Docker image platform error                | Use Linux containers for this Dockerfile                                         |
| Container name `aceest-app` already exists | Use `docker start aceest-app`, or recreate it after a rebuild as described above |

## 3 Jenkins and GitHub Actions integration

### GitHub Actions

The workflow is defined in `.github/workflows/main.yml`. It runs automatically on every `push` and `pull_request`. Once the project is pushed to GitHub, the checks run on GitHub's Ubuntu runner; the Windows computer does not need to stay running for them to finish.

| Stage               | Purpose                                                                         |
| ------------------- | ------------------------------------------------------------------------------- |
| Checkout and setup  | Get the commit and prepare Python 3.12                                          |
| Dependencies        | Install packages from `requirements-dev.txt`                                    |
| Compile and lint    | Compile Python files and run Ruff                                               |
| Docker builds       | Build runtime and test images tagged with the commit SHA                        |
| Container tests     | Run Pytest inside Docker with the 90% coverage requirement                      |
| Reports and cleanup | Copy the JUnit XML report, remove the test container and upload `pytest-report` |

Compilation, lint, image build or test failures fail the job. Report collection and cleanup use `if: always()` so they are attempted even if an earlier stage fails. The workflow has read-only repository contents permission.

To inspect results, open the repository's **Actions** tab, choose a run and select **build-and-test**. Expand a stage to read its log. The run summary includes the uploaded `pytest-report` artifact when a report was generated. Artifact downloads may require GitHub sign-in and are available within the configured retention period.

I used a documentation branch and [pull request 1](https://github.com/2025tm93067-ruchi/aceest-fitness-devops/pull/1) to check the branch workflow. Both push and pull-request checks passed before the change was merged into `main`.

### Jenkins build environment

The existing `Jenkinsfile` uses Linux shell commands through Jenkins `sh` steps. **It must run on a Linux build node with Git, the Docker CLI and access to a Linux Docker daemon. It cannot run unchanged on a native Windows Jenkins build node.**

You can open and configure Jenkins from your Windows browser while using a suitable Linux server or Linux agent for builds. If the Jenkins controller is installed on Windows, connect a Linux agent and ensure this job is scheduled on that agent. The current `agent any` setting means all eligible nodes for this job must support its Linux commands; do not leave the Windows controller eligible to execute this pipeline.

Jenkins also requires the Pipeline, Git and JUnit plugins. Confirm Docker access from the **Jenkins execution account**, since Docker working in your Windows PowerShell does not establish access on the Jenkins build node.

### Configure the project job

1. Open your Jenkins server URL in the Windows browser and sign in.
2. Select **New Item**, enter `ACEest-Build` and choose **Pipeline**.
3. Select **Pipeline script from SCM** and enter the following settings.

| Setting        | Value                                                            |
| -------------- | ---------------------------------------------------------------- |
| SCM            | Git                                                              |
| Repository URL | `https://github.com/2025tm93067-ruchi/aceest-fitness-devops.git` |
| Credentials    | None for this public repository                                  |
| Branch         | `*/main`                                                         |
| Script path    | `Jenkinsfile`                                                    |

4. Save the job and select **Build Now** for its first execution.
5. Open the build number and **Console Output**. A successful run ends with `Finished: SUCCESS`.
6. Open **Tests** to view passed, failed and skipped totals.

The Jenkinsfile checks Docker access, deletes its workspace and performs a clean GitHub checkout. It builds runtime and test images tagged with the build number, runs compilation and lint checks inside the test image, and executes the Pytest suite inside Docker. Post-build steps publish JUnit results and remove the test container. Concurrent builds of this job are disabled.

SCM polling is configured as `H/2 * * * *`. After the first build loads this setting, Jenkins checks `main` for changes about every two minutes while the server is running. A detected change starts a build automatically. Check its console for `Started by an SCM change`.

### How the pipelines work together

GitHub Actions checks pushes and pull requests on GitHub's runner. Jenkins independently polls `main` and performs a clean build on its configured Linux node. GitHub Actions does not start Jenkins in this setup. Both use the same Dockerfile and Pytest suite to validate the project in separate environments.

Recorded project validation includes 52 passing container tests with 100% coverage, successful GitHub Actions checks and a successful automatically triggered Jenkins build. These are the recorded project results; the setup commands above let another user reproduce the checks on their own computer.

### References

- [Python virtual environments](https://docs.python.org/3.12/library/venv.html)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Jenkins shell and batch steps](https://www.jenkins.io/doc/pipeline/tour/running-multiple-steps/)
