# Audit des dépendances au snap

À remplir en phase 2. Commit amont audité : `ea14d428`.

## Méthode

Recherche de `SNAP`, `SNAP_DATA`, `SNAP_USER_COMMON`, `SNAP_REAL_HOME`,
`SNAP_COMPONENTS`, `provider.env`, `backend/provider`, `modelctl`, `snapctl`
dans `upstream/client/` et `upstream/server/`, puis lecture de
`myna-snap/snap/snapcraft.yaml`, `whisper-snap/snap/snapcraft.yaml` (et hooks),
`whisper-snap/engines/cpu/` et `myna-config-deb/debian/`.

## Dépendances dans le code

| Fichier:ligne | Dépendance | Remplacement en natif | Patch ? |
|---------------|------------|-----------------------|---------|

## Variables d'environnement définies par les snaps

| Variable | Valeur dans le snap | Utile en natif ? | Remplacement |
|----------|---------------------|------------------|--------------|

## Configuration du moteur (`modelctl`)

| Clé | Rôle | Remplacement |
|-----|------|--------------|

## Conclusions
