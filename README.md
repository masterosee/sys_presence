# CONATEL - Système de Présence
> Flutter + FastAPI + PostgreSQL

## Structure du projet

```
conatel_presence/
├── database/
│   └── schema.sql          ← Schéma PostgreSQL (exécutez en premier)
├── backend/                ← FastAPI Python
│   ├── main.py
│   ├── requirements.txt
│   ├── .env.example        ← Copiez en .env
│   └── app/
│       ├── core/           ← Config, DB, Sécurité
│       ├── models/         ← Tables SQLAlchemy
│       ├── services/       ← Logique métier
│       └── api/v1/         ← Routes API
└── flutter/                ← Application mobile/desktop
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── theme/
        ├── services/       ← Communication API
        └── screens/        ← Interfaces
```

## Installation rapide

### 1. Base de données
```bash
psql -U postgres
CREATE DATABASE conatel_presence;
\c conatel_presence
\i database/schema.sql
```

### 2. Backend FastAPI
```bash
cd backend
python -m venv venv
source venv/bin/activate       # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env           # Éditez les valeurs
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Flutter
```bash
cd flutter
flutter pub get
# Éditez lib/services/api_service.dart → changez l'IP du serveur
flutter run
```

## Documentation API
Une fois le serveur démarré : http://localhost:8000/docs

## Méthodes de pointage disponibles

| Méthode       | Endpoint                    | Usage                        |
|---------------|-----------------------------|------------------------------|
| QR Code       | POST /attendances/checkin/qr | Scanner l'écran kiosque      |
| GPS           | POST /attendances/checkin/gps| Employé à distance           |
| PIN           | POST /attendances/checkin/pin| Kiosque sans smartphone      |
| Sortie        | POST /attendances/checkout   | Fin de journée               |

## Extension biométrie (future)
Ajoutez simplement un nouveau Provider qui hérite de `AttendanceProvider`.
Aucune modification de la base de données ou du dashboard nécessaire.

## Rôles utilisateurs
- `employee` — Pointer entrée/sortie, voir son historique
- `manager` — Voir les présences de son équipe
- `rh` — Gérer congés, rapports, zones géographiques
- `admin` — Accès complet
