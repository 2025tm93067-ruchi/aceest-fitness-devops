# ACEest assignment walkthrough for your Rocky Linux VM

This guide replaces the Windows walkthrough. Your screenshots confirm Rocky Linux 9.5, Python 3.9.21, Git 2.43.5, Docker 27.5.1, a working Linux Docker daemon, and an existing Jenkins sign-in page at localhost:8080.

**All commands below run in Terminal Emulator inside the VM. All localhost browser pages open in Firefox inside the VM.** Your Windows terminal and Windows browser cannot access the VM's localhost.

Keep the lab session tab open. Save source files in ~/workspace and push your work to GitHub before ending the session. The portal warns about 15 minutes of inactivity and loss of files outside ~/workspace on shutdown. Do not reinstall Jenkins, Docker or Java. SonarQube and Maven are not needed for this Python assignment.

The files are prepared, but no passing runtime tests or external pipeline results are claimed. Stop at the first failed checkpoint and send its output.

## 1 Sign in to the existing Jenkins

1. Return to the Jenkins page shown in your screenshot.
2. If the lab supplied/pre-filled credentials are correct, click Sign in.
3. If login fails, use credentials from Open Manual or the lab portal. Do not reset Jenkins and do not send me the password.
4. Keep the dashboard tab open. We will create jobs later.

## 2 Put the project files into the VM

The folder you created in the VM is currently separate from the prepared Windows files. We will create the project in it using one supplied setup block.

1. On your Windows computer, open VM_SETUP.txt from the outputs folder. It is linked in the chat.
2. Press Ctrl+A, then Ctrl+C to copy the entire file.
3. Click the VM's Terminal Emulator window.
4. Paste with Ctrl+Shift+V, or Terminal menu > Edit > Paste.
5. If your remote desktop does not pass clipboard text, use the lab's clipboard control described in Open Manual. If neither works, stop and send the clipboard/manual screen.
6. Press Enter once if the block has not executed.
7. Wait for the message PROJECT FILES READY.
8. The setup refuses to overwrite differing existing project files. If it reports a conflict, stop and send that message.
9. Run:

~~~bash
cd ~/workspace/aceest-fitness
pwd
ls -la
find .github tests templates -type f
~~~

**Expected:** your workspace project path, app.py, services.py, database.py, requirements files, Dockerfile, Jenkinsfile, README.md, WALKTHROUGH.md, tests, templates, and .github/workflows/main.yml.

The setup only writes project files. It does not install packages, use credentials, start services, or submit anything. Do not paste the setup block a second time after changing project files.

**Screenshot 01:** terminal showing the project files. Capture only the terminal, excluding the remote browser's token-bearing address bar.

## 3 Save screenshots on your Windows computer

Use this procedure at every screenshot checkpoint:

1. Make the requested VM result readable.
2. Press Windows+Shift+S on your physical keyboard.
3. Drag a rectangle around the terminal/page inside the VM.
4. Open the capture in Snipping Tool and press Ctrl+S.
5. Save to this Windows folder:

~~~text
C:\Users\Ruchi\Documents\Codex\2026-10-11\t\outputs\aceest-fitness\evidence
~~~

6. Create that folder in Windows File Explorer if absent.
7. Use the checkpoint filename, for example 01-vm-project-files.png.
8. Never include a password, token or Jenkins login form.

These captures are supporting evidence. The brief explicitly requests a public GitHub repository link; check the portal for additional evidence/report instructions.

## 4 Install dependencies in a VM virtual environment

In the VM terminal, run one line at a time:

~~~bash
cd ~/workspace/aceest-fitness
python3 -m venv .venv
~~~

**Expected:** prompt returns without error. Then:

~~~bash
.venv/bin/python -m pip install --upgrade pip
~~~

Wait for completion. Then:

~~~bash
.venv/bin/python -m pip install -r requirements-dev.txt
~~~

**Expected:** successful installation or requirement already satisfied.

Do not use sudo pip. Do not change the system Python. If venv/ensurepip/pip is missing or downloading fails, stop and send the error. We will use the lab-approved fix rather than guessing an OS package command.

## 5 Run the app locally inside the VM

~~~bash
.venv/bin/python -m flask --app app run --host 127.0.0.1 --port 5000
~~~

**Expected:** Running on http://127.0.0.1:5000. Leave that terminal running.

In Firefox inside the VM:

1. Open a new tab at http://127.0.0.1:5000.
2. Confirm ACEest Fitness & Gym appears.
3. Enter Name: Demo Student.
4. Enter Age: 25.
5. Enter Weight: 70.
6. Select Fat Loss.
7. Click Save client.
8. Confirm Calories shows 1540.
9. Read the saved row's ID.
10. Enter that ID in Weekly progress.
11. Use the date picker to select 5 October 2026.
12. Enter adherence 85.
13. Click Save progress.
14. Click View progress for entered client ID.
15. Confirm the JSON contains the date and adherence.

**Screenshot 02:** 02-vm-local-app.png, including the client row and saved progress.

Open http://127.0.0.1:5000/health in another VM Firefox tab.

**Expected:** JSON status ok.

**Screenshot 03:** 03-vm-health.png.

Return to Terminal Emulator and press Ctrl+C. Confirm the prompt returns before continuing.

## 6 Run local quality checks

One command at a time:

~~~bash
.venv/bin/python -m compileall -q app.py services.py database.py tests
~~~

**Expected:** no errors; no output is normal.

~~~bash
.venv/bin/python -m ruff check .
~~~

**Expected:** All checks passed!

~~~bash
.venv/bin/python -m pytest -q --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90
~~~

**Expected:** all tests pass, no errors/failures, coverage at least 90%. The percentage is a project quality gate, not a percentage required by the brief.

**Screenshot 04:** 04-vm-local-checks.png. Include commands, lint success, coverage and final test result; use two captures if needed.

Stop if a check fails. Do not lower the threshold to hide a failure.

## 7 Build and test Docker images

Keep the VM terminal in ~/workspace/aceest-fitness.

~~~bash
docker build --target test -t aceest-fitness-test:local .
~~~

Wait until it finishes successfully. The final dot is part of the command.

~~~bash
docker run --rm aceest-fitness-test:local python -m pytest -q -p no:cacheprovider --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90
~~~

**Expected:** containerized tests pass and coverage is at least 90%.

**Screenshot 05:** 05-vm-docker-tests.png.

~~~bash
docker build --target runtime -t aceest-fitness:local .
~~~

Wait for success, then:

~~~bash
docker image ls aceest-fitness
~~~

**Expected:** runtime image with tag local.

**Screenshot 06:** 06-vm-docker-image.png.

## 8 Run the application container

Local Flask must be stopped before using port 5000.

Use a bind mount under workspace so the database follows the portal's persistence rule:

~~~bash
mkdir -p ~/workspace/aceest-fitness/instance
~~~

The application container uses UID 10001. Give that UID access to only this database directory if the lab permits sudo:

~~~bash
sudo chown -R 10001:10001 ~/workspace/aceest-fitness/instance
~~~

If sudo is denied or asks for credentials you do not have, stop and send the message. Do not use chmod 777 or change unrelated directories.

~~~bash
docker run -d --name aceest-app -p 127.0.0.1:5000:5000 --mount type=bind,source="$HOME/workspace/aceest-fitness/instance",target=/app/instance aceest-fitness:local
~~~

~~~bash
docker ps --filter name=aceest-app
docker logs aceest-app
~~~

**Expected:** container Up, port 5000 mapped, Gunicorn startup without errors.

If the name already exists, use docker start aceest-app and inspect its logs instead of repeating creation.

**Screenshot 07:** 07-vm-running-container.png.

In VM Firefox, open http://127.0.0.1:5000 again. Register another fictional client as in Step 5. The Docker app uses the same workspace database path as local Flask, so earlier clients may already appear.

**Screenshot 08:** 08-vm-docker-app.png.

~~~bash
docker exec aceest-app id
~~~

**Expected:** uid=10001 and appuser.

**Screenshot 09:** 09-vm-nonroot-user.png.

## 9 Initialize Git and make project commits

~~~bash
cd ~/workspace/aceest-fitness
git init -b main
git branch --show-current
~~~

**Expected:** main. If an existing repository is on a different branch, stop and send the output.

Run the next line, type your actual name when asked, and press Enter:

~~~bash
read -r -p "Your name for Git commits: " assignment_git_name
~~~

Then enter your GitHub email or GitHub noreply email when asked:

~~~bash
read -r -p "Your GitHub email or noreply email: " assignment_git_email
~~~

~~~bash
git config user.name "$assignment_git_name"
git config user.email "$assignment_git_email"
~~~

Run each pair separately:

~~~bash
git add app.py services.py database.py templates requirements.txt .gitignore
git commit -m "Adapt ACEest logic into Flask with SQLite persistence"
~~~

~~~bash
git add tests requirements-dev.txt pyproject.toml
git commit -m "Add business-rule and API tests"
~~~

~~~bash
git add Dockerfile .dockerignore
git commit -m "Add Docker runtime and validation images"
~~~

~~~bash
git add .github Jenkinsfile
git commit -m "Configure Actions and Jenkins build validation"
~~~

~~~bash
git add README.md WALKTHROUGH.md
git commit -m "Document Rocky Linux lab execution"
~~~

~~~bash
git status
git log --oneline --graph --all
~~~

**Expected:** clean tree and meaningful commits. These record the prepared project, not a reconstructed history of the instructor's desktop versions.

**Screenshot 10:** 10-vm-git-history.png.

## 10 Create a public GitHub repository

Use Firefox inside the VM:

1. Open github.com and sign in.
2. Click + > New repository.
3. Repository name: aceest-fitness-devops. If already used, choose aceest-fitness-devops-assignment.
4. Visibility: Public.
5. Leave README initialization off.
6. Leave .gitignore and license selections as None.
7. Click Create repository.
8. Under Quick setup, select HTTPS and copy the URL.

Back in the VM terminal, run this line and paste the URL when prompted:

~~~bash
read -r -p "Paste your repository HTTPS URL: " assignment_repo_url
~~~

~~~bash
git remote add origin "$assignment_repo_url"
git remote -v
~~~

**Expected:** your correct repository. If origin already exists, inspect it and stop if it points somewhere else.

## 11 Authenticate and push from Linux

GitHub does not accept your normal account password for Git HTTPS pushes.

1. In GitHub, click profile picture > Settings.
2. Click Developer settings > Personal access tokens > Tokens (classic).
3. Click Generate new token > Generate new token (classic), if permitted by your account.
4. Name it ACEest lab; choose a short expiry such as 7 days.
5. Select repo and workflow scopes for uploading this repository and its Actions configuration.
6. Generate and copy the token privately. Do not put it in a command, README, screenshot or chat.
7. If classic tokens are unavailable under your account policy, stop and ask for the SSH alternative.

In the VM terminal:

~~~bash
git push -u origin main
~~~

If prompted for username, enter your GitHub username. If prompted for password, paste the token; input may be invisible. Press Enter. Do not include the token in the remote URL. Do not enable plaintext credential storage.

**Expected:** push succeeds and main tracks origin/main. A configured credential helper may authenticate without these prompts.

Refresh the repository in VM Firefox. Confirm source, tests, Dockerfile, Jenkinsfile and .github/workflows/main.yml are present.

**Screenshot 11:** 11-public-repository.png.

Revoke the temporary token after you finish all required pushes and final verification.

[Official GitHub token instructions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

## 12 Verify GitHub Actions

1. Click Actions in your repository.
2. Open ACEest CI.
3. Open the build-and-test job.
4. Wait for all required steps to go green.
5. Confirm compile/lint, both Docker builds and Docker Pytest passed.

**Screenshot 12:** 12-actions-success.png.

6. Expand Run Pytest inside Docker.
7. Confirm passing tests and coverage.

**Screenshot 13:** 13-actions-tests.png.

If a stage is red, send the actual failed output before continuing.

## 13 Demonstrate branch management

In VM terminal:

~~~bash
git switch -c docs/project-scope
~~~

Paste the entire next box, including EOF lines:

~~~bash
cat >> README.md <<'EOF'

## Assignment scope

The desktop baseline is adapted into Flask with client registration, sample calorie estimates and weekly progress. Actions validates pushes and pull requests; the existing lab Jenkins independently validates main.
EOF
~~~

~~~bash
git add README.md
git commit -m "Explain application scope and pipeline responsibilities"
git push -u origin docs/project-scope
~~~

In GitHub:

1. Click Compare & pull request, or Pull requests > New pull request.
2. Base: main; compare: docs/project-scope.
3. Title: Document assignment scope.
4. Create pull request.
5. Wait for green checks.

**Screenshot 14:** 14-pull-request-checks.png.

6. Merge pull request > Confirm merge.

In terminal:

~~~bash
git switch main
git pull --ff-only origin main
~~~

## 14 Check Docker access from the existing Jenkins

Your successful terminal Docker check proves access for your student account. It does not prove access for the Jenkins service account.

In the existing Jenkins dashboard:

1. Click New Item.
2. Name: ACEest-Environment-Check.
3. Select Pipeline > OK.
4. Under Pipeline, select Pipeline script.
5. Paste this script:

~~~groovy
pipeline {
    agent any
    stages {
        stage('Check build environment') {
            steps {
                sh 'whoami'
                sh 'git --version'
                sh 'docker version'
                sh 'docker info --format "{{.OSType}}"'
            }
        }
    }
}
~~~

6. Save > Build Now.
7. Open build number > Console Output.
8. Confirm Docker Client and Server details, linux, and Finished: SUCCESS.

**Screenshot 15:** 15-jenkins-environment.png.

If permission denied appears for the Docker socket, or no executor is available, stop and send that console output. Use the lab manual/support-approved fix. Do not reinstall Jenkins, reset its users, restart the whole lab, or change system Docker permissions by guessing.

If Jenkins is missing Pipeline support, ask the lab administrator or use permitted plugin management to install it. Do not alter unrelated jobs.

## 15 Create the assignment Jenkins job

1. Dashboard > New Item.
2. Name: ACEest-Build.
3. Select Pipeline > OK.
4. Scroll to Pipeline.
5. Definition: Pipeline script from SCM.
6. SCM: Git.
7. Repository URL: the public GitHub HTTPS URL from Step 10.
8. Credentials: none for public checkout.
9. Branch Specifier: */main.
10. Script Path: Jenkinsfile.
11. Save.
12. Click Build Now once to initialize polling.
13. Open build number > Console Output.
14. Wait for image builds, lint and containerized tests.
15. Confirm Finished: SUCCESS.

**Screenshot 16:** 16-jenkins-build-success.png.

16. Open Test Result from the build page.

**Screenshot 17:** 17-jenkins-junit.png.

The Jenkinsfile uses agent any instead of an unconfigured docker label. It still requires a Linux node with working Docker access, verified in Step 14. If junit is unknown, check whether the JUnit plugin is available through the lab's allowed plugin setup; send the error before changing the pipeline.

## 16 Prove Jenkins triggers automatically

Keep the VM active and Jenkins open.

~~~bash
git switch main
git pull --ff-only origin main
~~~

~~~bash
cat >> README.md <<'EOF'

## Local Jenkins polling

After its first manual run, the lab job checks main approximately every two minutes and builds when new commits are detected. GitHub Actions runs independently on the same push.
EOF
~~~

~~~bash
git add README.md
git commit -m "Document Jenkins automatic SCM polling"
git push origin main
git rev-parse HEAD
~~~

1. Note the new commit hash.
2. Return to ACEest-Build in Jenkins.
3. Do not click Build Now.
4. Wait about two to four minutes and refresh if needed.
5. Open the new build and inspect its cause/console.
6. Confirm an SCM-change trigger, the correct commit, and SUCCESS.

**Screenshot 18:** 18-jenkins-automatic-trigger.png. Use separate cause/success captures if needed.

7. Confirm the latest Actions run on main is green too.

If no automatic build appears, send the job's Polling Log and git log -1 --oneline. A manual build is not evidence of an automatic trigger.

## 17 Final check and submission

~~~bash
git status
git log -1 --oneline
git rev-parse HEAD
~~~

**Expected:** main is up to date and clean. Both systems must have validated the final main commit.

1. Open your repository in a private browser window to confirm public access.
2. Check source, requirements, tests, Dockerfile, Actions YAML, Jenkinsfile and README.
3. Copy the repository page URL.
4. Open the university submission page.
5. Paste the public URL into its required field.
6. Attach evidence/report only if required there.
7. Verify the portal's deadline and final requirements.
8. Submit and save the confirmation.

The brief does not specify a report template or deadline. Do not upload your virtual environment, client database, GitHub token or lab credentials.

## 18 Preserve your work before ending the VM session

1. Confirm your final commits are pushed to GitHub.
2. Keep source under ~/workspace/aceest-fitness.
3. Keep evidence on your Windows computer; it will not depend on VM lifetime.
4. The Jenkinsfile in GitHub preserves build logic. Jenkins service data and Docker images may not persist across VM destruction; do not assume they do.
5. If the lab manual provides a Jenkins export/backup procedure, follow it for job configuration.
6. Do not stop the university's Jenkins service.
7. You may stop your application container:

~~~bash
docker stop aceest-app
~~~

8. End the lab only after your work is saved and pushed.

For a later session, use git clone under ~/workspace if the project is missing and follow the lab's restore instructions. Do not paste the original setup over edited project files.

## Viva and scope

The app adapts selected ACEest 1.1 domain logic into Flask, adding actual client persistence and weekly progress. Login, billing, PDF reports and charts are outside this version. Confirm with the instructor if a particular baseline or extra feature set is mandatory; the supplied brief does not specify that.

Know these points: Flask handles HTTP; SQLite stores records; fixtures isolate tests; Git commits record changes; Docker test and runtime images share the application base; Actions reacts to push/PR events; Jenkins independently builds the public repository; polling triggers local Jenkins without a public webhook.

Runtime containers and Actions use Python 3.12. Local VM development uses Python 3.9. Dependencies support the selected local version, and behavior still needs actual testing. Read your code and follow your institution's policy on assistance.
