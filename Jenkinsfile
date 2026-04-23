pipeline {

    agent any

    environment {
        APP_NAME        = "crud-contacts"
        DOCKER_REGISTRY = "registry.example.com"   // ⚠️ à adapter
        IMAGE_NAME      = "${DOCKER_REGISTRY}/${APP_NAME}"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        FULL_IMAGE      = "${IMAGE_NAME}:${IMAGE_TAG}"
        LATEST_IMAGE    = "${IMAGE_NAME}:latest"

        DOCKER_CREDS = credentials('docker-registry-credentials')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    stages {

        // ───────────────────────────────
        stage('📥 Checkout') {
            steps {
                cleanWs()
                checkout scm
                echo "✅ Code récupéré"
            }
        }

        // ───────────────────────────────
        stage('🐍 Install & Test') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate

                    pip install --upgrade pip
                    pip install flask pytest flake8

                    echo "=== Lint ==="
                    flake8 app.py || true

                    echo "=== Tests ==="
                    if [ -d "tests" ]; then
                        pytest tests/
                    else
                        echo "Pas de tests"
                    fi
                '''
            }
        }

        // ───────────────────────────────
        stage('🐳 Build Docker') {
            steps {
                sh """
                    docker build -t ${FULL_IMAGE} .
                    docker tag ${FULL_IMAGE} ${LATEST_IMAGE}
                """
            }
        }

        // ───────────────────────────────
        stage('🔐 Login Docker') {
            steps {
                sh """
                    echo "${DOCKER_CREDS_PSW}" | docker login ${DOCKER_REGISTRY} -u "${DOCKER_CREDS_USR}" --password-stdin
                """
            }
        }

        // ───────────────────────────────
        stage('📤 Push Image') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    docker push ${FULL_IMAGE}
                    docker push ${LATEST_IMAGE}
                """
            }
        }

        // ───────────────────────────────
        stage('🚀 Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "Déploiement local..."
                    docker stop crud || true
                    docker rm crud || true

                    docker run -d -p 5000:5000 --name crud ${FULL_IMAGE}
                '''
            }
        }

        // ───────────────────────────────
        stage('✅ Smoke Test') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    sleep 5
                    curl -f http://localhost:5000 || exit 1
                '''
            }
        }
    }

    // ───────────────────────────────
    post {

        always {
            script {
                node {
                    echo "🧹 Nettoyage Docker"
                    sh "docker image prune -f || true"
                    sh "docker logout ${DOCKER_REGISTRY} || true"
                }
            }
        }

        success {
            echo "✅ PIPELINE RÉUSSI"
        }

        failure {
            script {
                node {
                    echo "❌ ECHEC – rollback"
                    sh '''
                        docker stop crud || true
                        docker rm crud || true
                    '''
                }
            }
        }

        unstable {
            echo "⚠️ Build instable"
        }
    }
}
