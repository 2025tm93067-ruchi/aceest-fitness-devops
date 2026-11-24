pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 25, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '5'))
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        booleanParam(name: 'PUBLISH_DOCKERHUB', defaultValue: false,
            description: 'Publish only after tests and the SonarQube quality gate pass.')
        string(name: 'DOCKERHUB_USERNAME', defaultValue: '', trim: true,
            description: 'Your DockerHub username; repository name is aceest-fitness.')
        booleanParam(name: 'DEPLOY_KUBERNETES', defaultValue: false,
            description: 'Requires publishing, kubectl, the bootstrapped cluster, and aceest-kubeconfig.')
        choice(name: 'DEPLOY_STRATEGY', choices: ['rolling', 'bluegreen'],
            description: 'Strategy used for this deployment; other demonstrations are separate scripts.')
    }

    stages {
        stage('Checkout and validate') {
            steps {
                deleteDir()
                checkout scm
                script {
                    env.SOURCE_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.APP_VERSION = readFile('VERSION').trim()
                    if (!(env.APP_VERSION ==~ /[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?/)) {
                        error('VERSION must contain a version such as 2.0.0 or 2.0.0-rc1.')
                    }
                    if (params.DEPLOY_KUBERNETES && !params.PUBLISH_DOCKERHUB) {
                        error('Enable PUBLISH_DOCKERHUB when enabling DEPLOY_KUBERNETES.')
                    }
                    if (params.PUBLISH_DOCKERHUB &&
                        !(params.DOCKERHUB_USERNAME ==~ /[a-z0-9][a-z0-9_-]{2,29}/)) {
                        error('Supply your DockerHub username before enabling publication.')
                    }
                    env.RUN_KEY = "${env.SOURCE_COMMIT.take(12)}-b${env.BUILD_NUMBER}"
                    env.RUNTIME_IMAGE = "aceest-fitness-ci:${env.RUN_KEY}"
                    env.TEST_IMAGE = "aceest-fitness-ci:${env.RUN_KEY}-test"
                    env.TEST_CONTAINER = "aceest-tests-${env.RUN_KEY}"
                    env.DEPLOY_STRATEGY = params.DEPLOY_STRATEGY
                }
                sh '''
                    set -eu
                    docker version
                    mkdir -p reports artifacts
                    printf 'version=%s\ncommit=%s\nbuild=%s\n' \
                        "$APP_VERSION" "$SOURCE_COMMIT" "$BUILD_NUMBER" > artifacts/build-info.properties
                '''
            }
        }

        stage('Build Docker images') {
            steps {
                sh '''
                    set -eu
                    docker build --target runtime \
                        --build-arg APP_VERSION="$APP_VERSION" \
                        --build-arg GIT_COMMIT="$SOURCE_COMMIT" \
                        -t "$RUNTIME_IMAGE" .
                    docker build --target test \
                        --build-arg APP_VERSION="$APP_VERSION" \
                        --build-arg GIT_COMMIT="$SOURCE_COMMIT" \
                        -t "$TEST_IMAGE" .
                    docker image inspect --format '{{.Id}}' "$RUNTIME_IMAGE" > artifacts/image-id.txt
                '''
            }
        }

        stage('Compile and lint') {
            steps {
                sh '''
                    set -eu
                    docker run --rm --entrypoint sh "$TEST_IMAGE" -c \
                        'python -m compileall -q app.py services.py database.py wsgi.py && ruff check .'
                '''
            }
        }

        stage('Pytest in Docker') {
            steps {
                sh '''
                    set -eu
                    docker create --name "$TEST_CONTAINER" \
                        -e COVERAGE_FILE=/tmp/.coverage "$TEST_IMAGE" \
                        pytest -q -p no:cacheprovider \
                        --junitxml=/tmp/junit.xml --cov \
                        --cov-report=term-missing --cov-report=xml:/tmp/coverage.xml \
                        --cov-fail-under=90
                    attach_status=0
                    docker start -a "$TEST_CONTAINER" || attach_status=$?
                    test_state="$(docker inspect --format '{{.State.Status}}' "$TEST_CONTAINER")"
                    if [ "$test_state" != exited ]; then
                        echo "Test container did not finish normally: $test_state" >&2
                        exit 1
                    fi
                    test_status="$(docker inspect --format '{{.State.ExitCode}}' "$TEST_CONTAINER")"
                    if [ "$test_status" -eq 0 ] && [ "$attach_status" -ne 0 ]; then
                        test_status="$attach_status"
                    fi
                    docker cp "$TEST_CONTAINER:/tmp/junit.xml" reports/junit.xml || true
                    docker cp "$TEST_CONTAINER:/tmp/coverage.xml" reports/coverage.xml || true
                    if [ "$test_status" -eq 0 ]; then
                        test -s reports/junit.xml
                        test -s reports/coverage.xml
                    fi
                    exit "$test_status"
                '''
            }
        }

        stage('SonarQube analysis and quality gate') {
            steps {
                script {
                    def scannerHome = tool name: 'SonarScanner',
                        type: 'hudson.plugins.sonar.SonarRunnerInstallation'
                    withEnv(["SCANNER_HOME=${scannerHome}"]) {
                        withSonarQubeEnv(installationName: 'LocalSonar', credentialsId: 'sonar-token') {
                            sh '''
                                set +x
                                set -eu
                                "$SCANNER_HOME/bin/sonar-scanner" \
                                    -Dsonar.host.url="$SONAR_HOST_URL" \
                                    -Dsonar.login="$SONAR_AUTH_TOKEN" \
                                    -Dsonar.projectVersion="$APP_VERSION" \
                                    -Dsonar.scm.revision="$SOURCE_COMMIT" \
                                    -Dsonar.qualitygate.wait=true \
                                    -Dsonar.qualitygate.timeout=300
                            '''
                        }
                    }
                }
            }
        }

        stage('Package source artifact') {
            steps {
                sh '''
                    set -eu
                    git archive --format=tar.gz \
                        --output="artifacts/aceest-fitness-${APP_VERSION}-${RUN_KEY}.tar.gz" HEAD
                '''
            }
        }

        stage('Publish DockerHub image') {
            when {
                expression { params.PUBLISH_DOCKERHUB }
            }
            steps {
                script {
                    env.PUBLISHED_IMAGE = "${params.DOCKERHUB_USERNAME}/aceest-fitness:${env.APP_VERSION}-${env.RUN_KEY}"
                    env.RELEASE_IMAGE = "${params.DOCKERHUB_USERNAME}/aceest-fitness:${env.APP_VERSION}"
                }
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                    usernameVariable: 'HUB_USERNAME', passwordVariable: 'HUB_PASSWORD')]) {
                    sh '''
                        set +x
                        set -eu
                        if [ "$HUB_USERNAME" != "$DOCKERHUB_USERNAME" ]; then
                            echo 'dockerhub-creds username must match DOCKERHUB_USERNAME.' >&2
                            exit 1
                        fi
                        DOCKER_CONFIG="$(mktemp -d)"
                        export DOCKER_CONFIG
                        trap 'rm -f "$DOCKER_CONFIG/config.json"; rmdir "$DOCKER_CONFIG"' EXIT
                        printf '%s' "$HUB_PASSWORD" | \
                            docker login --username "$HUB_USERNAME" --password-stdin
                        docker tag "$RUNTIME_IMAGE" "$PUBLISHED_IMAGE"
                        docker tag "$RUNTIME_IMAGE" "$RELEASE_IMAGE"
                        docker push "$PUBLISHED_IMAGE"
                        docker push "$RELEASE_IMAGE"
                        docker image inspect --format '{{index .RepoDigests 0}}' \
                            "$PUBLISHED_IMAGE" > artifacts/published-image-digest.txt
                        printf 'immutable_tag=%s\nrelease_tag=%s\n' \
                            "$PUBLISHED_IMAGE" "$RELEASE_IMAGE" > artifacts/published-image.properties
                    '''
                }
                script {
                    env.DEPLOY_IMAGE = readFile('artifacts/published-image-digest.txt').trim()
                }
            }
        }

        stage('Deploy Kubernetes') {
            when {
                expression { params.DEPLOY_KUBERNETES }
            }
            steps {
                withCredentials([file(credentialsId: 'aceest-kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -eu
                        command -v kubectl
                        deploy_status=0
                        sh scripts/rollout.sh "$DEPLOY_IMAGE" "$DEPLOY_STRATEGY" \
                            > artifacts/deployment.log 2>&1 || deploy_status=$?
                        cat artifacts/deployment.log
                        exit "$deploy_status"
                    '''
                }
            }
        }
    }

    post {
        always {
            junit testResults: 'reports/junit.xml', allowEmptyResults: true
            archiveArtifacts artifacts: 'reports/*.xml,artifacts/*,.scannerwork/report-task.txt',
                allowEmptyArchive: true, fingerprint: true
            script {
                if (env.TEST_CONTAINER) {
                    sh 'docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true'
                }
            }
        }
        success {
            echo 'Tests and SonarQube quality gate passed. Review stage results: optional publication/deployment may be skipped.'
        }
    }
}
