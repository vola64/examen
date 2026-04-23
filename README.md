# 🚀 CRUD Contacts – Pipeline CI/CD

## 📁 Structure des fichiers

```
.
├── app.py                 # Application Flask
├── index.html             # Template HTML
├── requirements.txt       # Dépendances Python
├── Dockerfile             # Build multi-stage (builder → runtime)
├── docker-compose.yml     # Orchestration des services
├── Jenkinsfile            # Pipeline CI/CD Jenkins
└── trivy-reports/         # Rapports de sécurité (généré automatiquement)
```

---

## 🐳 Commandes Docker locales

```bash
# Build de l'image
docker build -t crud-contacts:latest .

# Lancer l'application
docker compose up -d app

# Lancer le scan Trivy manuellement
docker compose --profile scan up trivy

# Voir les logs
docker compose logs -f app

# Arrêter
docker compose down
```

---

## 🛡️ Trivy – Scan de sécurité

Trivy est intégré au pipeline en **stage bloquant** (configurable).

| Variable         | Valeur par défaut | Description                        |
|------------------|-------------------|------------------------------------|
| `TRIVY_SEVERITY` | HIGH,CRITICAL     | Niveaux de sévérité scannés        |
| `TRIVY_EXIT_CODE`| 1                 | 1 = bloque, 0 = avertissement seul |

Rapports générés :
- `trivy-reports/trivy-table.txt` – lisible humain
- `trivy-reports/trivy-report.json` – pour intégration SIEM

---

## ⚙️ Configuration Jenkins

### Prérequis sur l'agent Jenkins

- Docker installé et accessible par l'utilisateur `jenkins`
- Python 3.11+ (ou utiliser un agent Docker)
- Trivy (installé automatiquement si absent)

### Credentials à créer dans Jenkins

| ID                            | Type                 | Usage                     |
|-------------------------------|----------------------|---------------------------|
| `docker-registry-credentials` | Username/Password   | Push vers le registre     |
| `deploy-host-ssh`             | SSH private key      | Déploiement distant       |

### Variables à adapter dans le Jenkinsfile

```groovy
DOCKER_REGISTRY = "registry.example.com"   // votre registre
TRIVY_EXIT_CODE = "1"                        // 0 = warn, 1 = bloque
```

---

## 🔄 Flux du pipeline

```
Checkout → Lint/Test → Build Image → Trivy Scan → Push Registry → Deploy → Smoke Test
                                          ↓
                                   Rapport archivé
                                   (HTML dans Jenkins)
```

### Règles de déploiement par branche

| Branche      | Build | Push | Deploy |
|--------------|-------|------|--------|
| `feature/*`  | ✅    | ❌   | ❌     |
| `develop`    | ✅    | ✅   | ❌     |
| `main`       | ✅    | ✅   | ✅     |

---

## 🔧 Plugins Jenkins requis

- **Docker Pipeline** – `docker-workflow`
- **HTML Publisher** – pour les rapports Trivy
- **Git** – checkout SCM
- **Credentials Binding** – gestion des secrets
- **Slack Notification** *(optionnel)* – alertes
