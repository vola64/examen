# ─── Stage 1 : Build / deps ────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# Copier uniquement les fichiers de dépendances d'abord (cache layer)
COPY requirements.txt .

RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── Stage 2 : Image finale légère ─────────────────────────────────────────
FROM python:3.11-slim AS runtime

LABEL maintainer="devops@contacts-app.local"
LABEL app="crud-contacts"
LABEL version="1.0"

# Sécurité : utilisateur non-root
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

# Copier les dépendances installées depuis le builder
COPY --from=builder /install /usr/local

# Copier le code applicatif
COPY app.py .
COPY index.html .

# Droits sur le répertoire de travail
RUN chown -R appuser:appgroup /app

USER appuser

# Exposer le port Flask
EXPOSE 5000

# Health check intégré
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000')" || exit 1

# Lancement en mode production avec Gunicorn
CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
