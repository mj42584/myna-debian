# CLAUDE.md : contexte pour les sessions futures

Lire aussi `README.fr.md` (état et versions ; `README.md` en est la version
anglaise publique, à tenir à jour ensemble) et `AUDIT.md` (dépendances au snap).

## 1. Le projet

Myna (<https://github.com/canonical/myna>, AGPL-3.0-or-later) est l'outil de
dictée vocale hors ligne de Canonical pour Ubuntu Desktop : un raccourci, on
parle, le texte est tapé dans l'application qui a le focus. La reconnaissance
tourne en local (Whisper, Parakeet…).

Canonical le distribue en snaps (client `myna` + un snap par moteur, ex.
`myna-whisper`) et Myna Settings en `.deb` via un PPA Ubuntu. Aucun paquet
Debian n'existe. Un portage Flatpak a été refusé par l'amont (ticket #93, patches
de contournement du bac à sable pour l'injection IBus).

**But** : des `.deb` natifs pour Debian 13 (trixie), GNOME 48 / Wayland, sans
snapd ni bac à sable, avec le moins possible de modifications de l'amont. Usage
personnel d'abord, proposition en amont si le travail est propre.

### Repères dans l'amont (`upstream/`)

- `client/` : workspace Rust (GTK4, libadwaita, PipeWire, gtk4-layer-shell 1.3.0)
  → `myna-desktop`, `myna-cli`, `myna-hud`. Toolchain : `client/rust-toolchain.toml`
  (1.99.0 au commit épinglé ; trixie a 1.85 → rustup). `myna-config` se compile
  avec le rustc de la distribution côté amont.
- `server/` : moteur d'inférence Python (`pyproject.toml`, `uv.lock`).
- `whisper-snap/` : moteur Whisper (`engines/cpu/server`, `models/*/model.yaml`
  avec l'URL Hugging Face et le `compute_type` de chaque modèle).
- `myna-snap/snap/snapcraft.yaml` : recette du client ; démon en service systemd
  utilisateur ; trouve le moteur via `provider.env` (nomme un socket Unix) dans
  `$SNAP_DATA/backend/provider` → point principal à adapter
  (cible : `$XDG_RUNTIME_DIR/myna/`).
- `myna-config-deb/debian/` : modèle pour l'empaquetage Debian.
- `extensions/myna-shell/` : extension GNOME Shell.
- Version : `dev/version.sh` (dernier tag `vX.Y.Z`) ; le client lit `client/.version`
  s'il existe. Les `0.0.0` de Cargo/pyproject sont des marqueurs, jamais modifiés.

### Documents amont à lire avant de toucher un sous-système

`upstream/CLAUDE.md`, `upstream/AGENTS.md`, `upstream/.kb/agents.md`, puis le
`AGENTS.md` du sous-système (`client/`, `server/`, `myna-config-deb/`, `docs/`)
et les `.kb/` utiles (`system-architecture.md`, `session-contract.md`,
`versioning.md`).

**Règle amont importante** : ne jamais lancer de GNOME Shell imbriqué ou sans
écran (ni une appli GTK sur un bus privé) hors de `dev/nested-session.sh` ; un
`dbus-run-session` nu remplace le socket AT-SPI de la session et casse Orca
jusqu'à la déconnexion.

## 2. Règles de travail

- Avancer phase par phase (voir le tableau du README). En fin de phase : résumer
  ce qui est fait et ce qui reste incertain, puis **attendre l'accord** de
  l'utilisateur avant de continuer (surtout avant la phase 5).
- Proposer un plan détaillé de la phase avant de modifier quoi que ce soit.
- **Ne jamais modifier `upstream/`** : toute modification passe par un patch
  quilt dans `packages/<paquet>/debian/patches/`, le plus petit possible.
- L'utilisateur teste lui-même le micro, le raccourci, l'injection IBus et
  l'indicateur : lui donner la commande exacte et dire quels logs renvoyer.
- Un commit par étape logique, messages en français. Ne rien pousser sur un
  dépôt distant sans demander.
- Pas de `sudo` sans prévenir et expliquer pourquoi.

## Conventions

- Version des paquets : `<version amont>+deb13~<n>` ;
  ex. `0.3.3+git4.ea14d428+deb13~1`.
- Tags : `debian/<version>` avec `~` remplacé par `_` (git refuse `~`).
- `scripts/build.sh <paquet>` copie `upstream/` + `packages/<paquet>/debian`
  dans `build/<paquet>` et lance `debuild`.

## Risques connus

- Rust 1.99.0 demandé, 1.85 dans trixie → rustup (non conforme à la Debian
  Policy, acceptable pour un usage perso).
- Python 3.13 face aux versions figées de `uv.lock` (CTranslate2 notamment).
- L'extension et GlobalShortcuts visent GNOME 49+ ; trixie a GNOME 48. Repli :
  `myna --control` + `install-shortcut`.
- L'amont bouge vite : sous-module épinglé, mise à jour presque automatique
  (`watch-upstream.yml` → `update-upstream.sh` → PR ; voir le README).
  `scripts/watched-paths` doit suivre `AUDIT.md` : tout nouveau point de
  contact avec le snap y ajoute son chemin.
