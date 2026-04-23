// ═══════════════════════════════════════════════════════════════════════════
//  Jenkinsfile  –  Pipeline CI/CD  –  CRUD Contacts App
//
//  Stages :
//    1. Checkout          – récupère le code source
//    2. Lint & Test       – vérification syntaxique Python + tests
//    3. Build Image       – construction de l'image Docker (multi-stage)
//    4. Trivy Scan        – analyse de vulnérabilités (HIGH / CRITICAL)
//    5. Push Registry     – pousse l'image sur le registre Docker
//    6. Deploy            – déploiement via docker-compose
//    7. Smoke Test        – vérification post-déploiement
//    8. Notify            – notification du résultat
// ═══════════════════════════════════════════════════════════════════════════

pipeline {

    agent any   // ou agent { docker { image 'python:3.11-slim' } } si agent Docker

    // ── Variables d'environnement globales ────────────────────────────────
    environment {
        APP_NAME        = "crud-contacts"
        DOCKER_REGISTRY = "registry.example.com"           // ← adapter
        IMAGE_NAME      = "${DOCKER_REGISTRY}/${APP_NAME}"
        IMAGE_TAG       = "${BUILD_NUMBER}-${GIT_COMMIT[0..6]}"
        FULL_IMAGE      = "${IMAGE_NAME}:${IMAGE_TAG}"
        LATEST_IMAGE    = "${IMAGE_NAME}:latest"

        // Credentials Jenkins (à créer dans : Manage Jenkins > Credentials)
        DOCKER_CREDS    = credentials('docker-registry-credentials')
        DEPLOY_HOST     = credentials('deploy-host-ssh')

        // Trivy
        TRIVY_SEVERITY  = "HIGH,CRITICAL"
        TRIVY_EXIT_CODE = "1"   // 1 = bloque le pipeline si vuln trouvée
        REPORT_DIR      = "trivy-reports"
    }

    // ── Options globales ──────────────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    // ── Déclencheurs ──────────────────────────────────────────────────────
    triggers {
        pollSCM('H/5 * * * *')   // vérifie le dépôt toutes les 5 min
        // githubPush()           // ou webhook GitHub
    }

    // ════════════════════════════════════════════════════════════════════════
    stages {

        // ── 1. CHECKOUT ────────────────────────────────────────────────────
        stage('📥 Checkout') {
            steps {
                cleanWs()
                checkout scm
                echo "✅ Code récupéré – Branche: ${env.BRANCH_NAME} | Commit: ${GIT_COMMIT[0..6]}"
            }
        }

        // ── 2. LINT & TESTS ────────────────────────────────────────────────
        stage('🔍 Lint & Test') {
            steps {
                sh '''
                    echo "=== Installation des outils ==="
                    pip install --quiet flake8 pytest flask gunicorn

                    echo "=== Lint Python (flake8) ==="
                    flake8 app.py \
                        --max-line-length=120 \
                        --ignore=E302,W503 \
                        --statistics

                    echo "=== Tests unitaires ==="
                    if [ -d "tests" ]; then
                        pytest tests/ -v --tb=short
                    else
                        echo "⚠️  Aucun dossier tests/ trouvé – skip"
                    fi
                '''
            }
            post {
                always {
                    // Archiver les rapports de test si pytest-junit est utilisé
                    junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
                }
            }
        }

        // ── 3. BUILD IMAGE DOCKER ──────────────────────────────────────────
        stage('🐳 Build Image Docker') {
            steps {
                script {
                    echo "=== Build image: ${FULL_IMAGE} ==="
                    sh """
                        docker build \
                            --no-cache \
                            --target runtime \
                            --tag ${FULL_IMAGE} \
                            --tag ${LATEST_IMAGE} \
                            --label "build.number=${BUILD_NUMBER}" \
                            --label "git.commit=${GIT_COMMIT[0..6]}" \
                            --label "git.branch=${BRANCH_NAME}" \
                            .
                    """
                    echo "✅ Image construite avec succès: ${FULL_IMAGE}"
                }
            }
        }

        // ── 4. TRIVY SCAN ──────────────────────────────────────────────────
        stage('🛡️ Trivy Security Scan') {
            steps {
                script {
                    echo "=== Scan de sécurité Trivy ==="

                    // Créer le répertoire de rapports
                    sh "mkdir -p ${REPORT_DIR}"

                    // Installation de Trivy si absent (ou utiliser l'image Docker)
                    sh '''
                        if ! command -v trivy &> /dev/null; then
                            echo "Installation de Trivy..."
                            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
                                | sh -s -- -b /usr/local/bin v0.51.0
                        fi
                        trivy --version
                    '''

                    // Scan de l'image – rapport TABLE (lisible)
                    sh """
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --format table \
                            --output ${REPORT_DIR}/trivy-table.txt \
                            --no-progress \
                            ${FULL_IMAGE}
                    """

                    // Scan de l'image – rapport JSON (pour archivage)
                    sh """
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --format json \
                            --output ${REPORT_DIR}/trivy-report.json \
                            --no-progress \
                            ${FULL_IMAGE}
                    """

                    // Scan bloquant : EXIT_CODE=1 si vulnérabilité critique/haute
                    def trivyStatus = sh(
                        script: """
                            trivy image \
                                --exit-code ${TRIVY_EXIT_CODE} \
                                --severity ${TRIVY_SEVERITY} \
                                --no-progress \
                                ${FULL_IMAGE}
                        """,
                        returnStatus: true
                    )

                    // Afficher le rapport lisible dans les logs Jenkins
                    sh "cat ${REPORT_DIR}/trivy-table.txt"

                    if (trivyStatus != 0) {
                        // Marquer unstable au lieu d'échouer (adapter selon politique)
                        currentBuild.result = 'UNSTABLE'
                        echo "⚠️  Vulnérabilités ${TRIVY_SEVERITY} détectées ! Voir le rapport."
                        // Pour bloquer complètement :
                        // error("🔴 Vulnérabilités critiques détectées – pipeline arrêté")
                    } else {
                        echo "✅ Aucune vulnérabilité ${TRIVY_SEVERITY} détectée"
                    }
                }
            }
            post {
                always {
                    // Archiver les rapports Trivy
                    archiveArtifacts artifacts: "${REPORT_DIR}/**", allowEmptyArchive: true
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: "${REPORT_DIR}",
                        reportFiles: 'trivy-table.txt',
                        reportName: 'Trivy Security Report'
                    ])
                }
            }
        }

        // ── 5. PUSH REGISTRY ───────────────────────────────────────────────
        stage('📤 Push Registry') {
            when {
                // Pousser seulement depuis main ou develop
                anyOf {
                    branch 'main'
                    branch 'develop'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    echo "=== Push vers ${DOCKER_REGISTRY} ==="
                    sh """
                        echo "${DOCKER_CREDS_PSW}" | \
                        docker login ${DOCKER_REGISTRY} \
                            -u "${DOCKER_CREDS_USR}" \
                            --password-stdin
                        docker push ${FULL_IMAGE}
                        docker push ${LATEST_IMAGE}
                    """
                    echo "✅ Image poussée: ${FULL_IMAGE}"
                }
            }
        }

        // ── 6. DÉPLOIEMENT ─────────────────────────────────────────────────
        stage('🚀 Deploy') {
            when {
                branch 'main'   // Déployer uniquement depuis main
            }
            steps {
                script {
                    echo "=== Déploiement sur le serveur de production ==="
                    sh """
                        # Exporter le tag pour docker-compose
                        export IMAGE_TAG=${IMAGE_TAG}

                        # Option A : déploiement local (Jenkins sur le même hôte)
                        docker compose pull app
                        docker compose up -d --force-recreate app

                        # Option B : déploiement SSH distant (décommenter si besoin)
                        # ssh -o StrictHostKeyChecking=no \${DEPLOY_HOST} "
                        #     cd /opt/crud-contacts &&
                        #     export IMAGE_TAG=${IMAGE_TAG} &&
                        #     docker compose pull app &&
                        #     docker compose up -d --force-recreate app
                        # "
                    """
                }
            }
        }

        // ── 7. SMOKE TEST ──────────────────────────────────────────────────
        stage('✅ Smoke Test') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "=== Vérification post-déploiement ==="
                    sleep 10   # attendre que le conteneur soit healthy

                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)
                    echo "HTTP Status: ${HTTP_CODE}"

                    if [ "${HTTP_CODE}" != "200" ]; then
                        echo "❌ Smoke test échoué – code HTTP: ${HTTP_CODE}"
                        exit 1
                    fi
                    echo "✅ Application accessible – code HTTP: ${HTTP_CODE}"
                '''
            }
        }

    } // end stages

    // ════════════════════════════════════════════════════════════════════════
    post {

        always {
            echo "=== Nettoyage des images locales ==="
            sh "docker image prune -f --filter label=build.number=${BUILD_NUMBER} || true"
            sh "docker logout ${DOCKER_REGISTRY} || true"
        }

        success {
            echo """
            ╔══════════════════════════════════════════╗
            ║  ✅  PIPELINE RÉUSSI                     ║
            ║  Image : ${FULL_IMAGE}
            ║  Build : #${BUILD_NUMBER}
            ╚══════════════════════════════════════════╝
            """
            // Notification Slack (si plugin Slack configuré)
            // slackSend color: 'good',
            //     message: "✅ Build #${BUILD_NUMBER} réussi – ${IMAGE_TAG}"
        }

        failure {
            echo "❌ Pipeline en échec – voir les logs ci-dessus"
            // slackSend color: 'danger',
            //     message: "❌ Build #${BUILD_NUMBER} échoué – ${JOB_NAME}"

            // Rollback automatique sur main
            script {
                if (env.BRANCH_NAME == 'main') {
                    sh """
                        echo "⚙️  Rollback vers la version précédente..."
                        docker compose up -d --force-recreate app || true
                    """
                }
            }
        }

        unstable {
            echo "⚠️  Pipeline instable – des vulnérabilités de sécurité ont été détectées"
        }

    } // end post

} // end pipeline
