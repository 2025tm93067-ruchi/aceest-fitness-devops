pipeline {
    agent any
    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
    }
    triggers { pollSCM('H/2 * * * *') }
    stages {
        stage('Docker access') {
            steps { sh 'docker version' }
        }
        stage('Clean checkout') {
            steps {
                deleteDir()
                checkout scm
            }
        }
        stage('Build runtime image') {
            steps { sh 'docker build --target runtime -t aceest-fitness:jenkins-$BUILD_NUMBER .' }
        }
        stage('Build validation image') {
            steps { sh 'docker build --target test -t aceest-fitness-test:jenkins-$BUILD_NUMBER .' }
        }
        stage('Syntax and lint') {
            steps {
                sh 'docker run --rm aceest-fitness-test:jenkins-$BUILD_NUMBER python -m compileall -q app.py services.py database.py tests'
                sh 'docker run --rm aceest-fitness-test:jenkins-$BUILD_NUMBER python -m ruff check .'
            }
        }
        stage('Containerized tests') {
            steps {
                sh 'docker run --name aceest-tests-$BUILD_NUMBER aceest-fitness-test:jenkins-$BUILD_NUMBER python -m pytest -q -p no:cacheprovider --junitxml=/tmp/test-results.xml --cov=app --cov=services --cov=database --cov-report=term-missing --cov-fail-under=90'
            }
        }
    }
    post {
        always {
            sh 'docker cp aceest-tests-$BUILD_NUMBER:/tmp/test-results.xml test-results.xml || true'
            junit allowEmptyResults: true, testResults: 'test-results.xml'
            sh 'docker rm -f aceest-tests-$BUILD_NUMBER || true'
        }
    }
}
