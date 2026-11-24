# Assignment 2 VM steps

Use the existing project at `/home/s2025tm93067/workspace/aceest-fitness`.
This package is an update to the supplied Assignment 1 repository, not proof
that the later pipeline stages or Kubernetes deployment have already run.

## Upload from your Mac

1. In Jenkins, open ACEest-Assignment2 and disable the job temporarily while
   updating its files and tool settings. This pauses its SCM polling builds.
2. Download and unzip the prepared archive on the Mac, outside the VM browser.
3. Open https://github.com/2025tm93067-ruchi/aceest-fitness-devops in the Mac browser.
4. Select Add file, Upload files. Open the extracted `aceest-fitness` folder
   and drag its contents into the upload area. Its `Jenkinsfile` must remain
   at the repository root. Existing Assignment 1 app files and tests are included.
5. Commit with a message describing the Assignment 2 pipeline update.
6. In the VM terminal, use these short commands:

```sh
cd ~/workspace/aceest-fitness
git status --short
git pull --ff-only
```

If Git reports local modifications or a non-fast-forward update, preserve the
files and resolve that message; do not use a hard reset.

## Jenkins configuration already agreed

- Secret text credential: `sonar-token`.
- SonarQube server installation name: `LocalSonar`.
- Server URL on this VM: `http://127.0.0.1:9000`.
- Server authentication credential: `sonar-token` (description ACEest SonarQube).
- Managed scanner tool name: `SonarScanner`.
- Scanner version: 5.0.1.3006 Linux package with its bundled Java 17.
- SonarQube project key: `aceest-fitness-assignment2`.
- Keep the existing Jenkins Pipeline script-from-SCM setup, branch `*/main`,
  script path `Jenkinsfile`.

Enable the job and run its first build. Publishing and Kubernetes deployment
parameters initially remain disabled so the Sonar analysis can be verified first.
Inspect the actual test report, Sonar project, and quality-gate result. A green
CI build with deployment stages skipped does not establish a completed CD task.
The scanner waits for the quality gate; no Sonar webhook is required for this
polling implementation.

## Publication and deployment still require setup

For Docker Hub, add username/password credential `dockerhub-creds`, using your
Docker Hub username and an access token. Set DOCKERHUB_USERNAME and enable
PUBLISH_DOCKERHUB in Build with Parameters. Retain the immutable image tag/digest.

For Kubernetes, read `k8s/README.md`. Bootstrap two published, identifiable
versions, then verify every strategy using the supplied scripts. Jenkins needs
kubectl and a reachable flattened kubeconfig in secret-file credential
`aceest-kubeconfig`. Enable DEPLOY_KUBERNETES only after that setup works.
The Kubernetes version routes are a read-only traffic-strategy demonstration;
the underlying Flask app retains the original client/progress functionality.

A VM-local address is not a public submission endpoint. Confirm the lab's
external forwarding facility and verify the final URL from outside the VM.

## Save evidence under workspace

Save screenshots, real build logs/results, Docker Hub image identifiers, endpoint
URLs, rollout/rollback observations, and the final report in
`~/workspace/submission-evidence`. Keep project files in the existing workspace
repository and commit them to GitHub. Keep credentials and kubeconfig private.
Jenkins and SonarQube runtime state are separate from these source files.

The project still requires real VM execution of Sonar analysis, image publication,
Kubernetes, all five release strategies, rollback, and the short final report.
