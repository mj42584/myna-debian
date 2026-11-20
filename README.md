# myna-debian

Paquets `.deb` natifs pour **Debian 13 (trixie)**, GNOME sous Wayland, de
[Myna](https://github.com/canonical/myna), l'outil de dictée vocale hors ligne
de Canonical. Pas de snapd, pas de bac à sable, un minimum de modifications du
code amont.

Projet non officiel, sans lien avec Canonical. Licence AGPL-3.0-or-later, comme
l'amont.

## État

| Phase | Contenu                                   | État       |
|-------|-------------------------------------------|------------|
| 0     | Dépôt, sous-module, squelette             | ✅ fait     |
| 1     | Préparation de la machine                 | ✅ fait     |
| 2     | Audit des dépendances au snap (`AUDIT.md`)| ✅ fait     |
| 3     | Compilation du client sans snap           | ✅ fait     |
| 4     | Moteur Whisper sans snap                  | ✅ fait     |
| 5     | Dictée de bout en bout, sans paquet       | ✅ fait     |
| 6     | Empaquetage des trois `.deb`              | ✅ fait     |
| 7     | Validation sur une installation propre    | à faire    |

## Paquets

| Paquet                       | Contenu |
|------------------------------|---------|
| `myna`                       | démon `myna-desktop` (service utilisateur `myna.service`), indicateur `myna-hud`, `myna-testbed`, `myna-settings` (réglages), `myna-status`, schéma GSettings, traductions |
| `myna-whisper`               | moteur Whisper CPU (faster-whisper / CTranslate2, runtime Python embarqué dans `/usr/lib/myna-whisper`), service `myna-whisper.service`, `myna-whisper-fetch-model` ; aucun modèle embarqué |
| `gnome-shell-extension-myna` | indicateur en bas de l'écran (extension `myna-shell@canonical.com`) |

**Myna Settings n'est pas empaqueté** : l'application amont est un frontal de
snapd (installation des modèles, choix du moteur, assistant) et reste bloquée
sur l'assistant sans snapd (voir `AUDIT.md`). Les réglages se font avec
`myna-settings`, le raccourci avec `myna-desktop --install-shortcut`.

## Installer

```bash
sudo apt install ./myna_*.deb ./myna-whisper_*.deb ./gnome-shell-extension-myna_*.deb
```

Puis, pour chaque utilisateur (rien n'est activé d'office : la dictation ouvre
le micro) :

```bash
myna-whisper-fetch-model base                      # tiny, base ou small (≈ 150 Mo pour base)
systemctl --user enable --now myna-whisper.service myna.service
myna-desktop --install-shortcut '<Super>d'         # raccourci GNOME : appui = début/fin
gnome-extensions enable myna-shell@canonical.com   # après une reconnexion
```

- Réglages du moteur (modèle, type de calcul…) : copier
  `/usr/share/doc/myna-whisper/examples/whisper.conf` dans
  `~/.config/myna/whisper.conf`, puis `systemctl --user restart myna-whisper`.
- Réglages de dictation (langue, mode, sons…) : `myna-settings`, par ex.
  `myna-settings set language "'fr'"` ; pris en compte à la volée.
- Diagnostic : `myna-status`, `journalctl --user -u myna -u myna-whisper`.

### Limites connues

- Moteur Whisper CPU seulement (pas de GPU, pas de Parakeet ni des autres
  moteurs de l'amont).
- `myna-whisper` est lié au Python 3.13 de trixie (roues PyPI) : à reconstruire
  si Debian change de version de Python.
- Construction non conforme à la Debian Policy : Rust par rustup, dépendances
  Rust et Python téléchargées pendant le build.

## Amont épinglé

- Dépôt : <https://github.com/canonical/myna>, sous-module `upstream/`
- Commit : `ea14d428775d1af435e641b083a6440947fa795e` (19/11/2026), soit
  `v0.3.3-4-gea14d428`

## Versions et tags

Version des paquets : `<version amont>+deb13~<n>`. La version amont suit le
schéma de `upstream/dev/version.sh` (`X.Y.Z` sur un tag, sinon
`X.Y.Z+git<commits depuis le tag>.<sha>`), celui que rapportent les binaires.

- Commit épinglé actuel : `0.3.3+git4.ea14d428+deb13~1`
- Tags de ce dépôt : `debian/<version>`, avec `~` remplacé par `_` (git refuse
  `~` dans un nom de ref, convention DEP-14), par exemple
  `debian/0.3.3+git4.ea14d428+deb13_1`.

## Récupérer le dépôt

```bash
git clone --recurse-submodules <url>/myna-debian
```

Pour un clone existant : `git submodule update --init`.

## Mettre à jour l'amont

```bash
git -C upstream fetch origin
git -C upstream checkout <nouveau-commit>
git add upstream
```

Puis :

1. mettre à jour la section « Amont épinglé » et les `debian/changelog` (nouvelle
   version, `~1`) ;
2. vérifier que les patches s'appliquent encore : `quilt push -a` dans chaque
   `build/<paquet>` ;
3. relire les changements de `myna-snap/`, `whisper-snap/` et `client/` qui
   touchent aux chemins audités dans `AUDIT.md` ;
4. faire un commit `amont : passage à <sha>`.

## Compiler

### Prérequis (Debian 13)

```bash
sudo apt install build-essential devscripts debhelper quilt pkgconf \
  libgtk-4-dev libadwaita-1-dev libpipewire-0.3-dev libclang-dev \
  libwayland-dev wayland-protocols libegl-dev libepoxy-dev libgl1-mesa-dev \
  libglib2.0-dev libglib2.0-dev-bin libgtk4-layer-shell-dev gettext lintian curl git
# facultatif, pour compiler Myna Settings à la main : blueprint-compiler
```

Le client demande Rust 1.99.0 (`upstream/client/rust-toolchain.toml`) alors que
trixie fournit la 1.85 : installer rustup (script officiel, pas le paquet
Debian `rustup`, qui entre en conflit avec les paquets `cargo` et `rustc`).
La bonne toolchain s'installe toute seule dans `upstream/client/`.

```bash
curl --proto '=https' -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
. ~/.cargo/env
(cd upstream/client && rustup show && cargo --version)   # doit afficher 1.99.0
```

`~/.cargo/bin` doit précéder `/usr/bin` dans le `PATH`, sinon le `cargo` de
Debian (1.85) est utilisé. Le moteur Whisper demande aussi
[uv](https://docs.astral.sh/uv/).

gtk4-layer-shell : la 1.0.4 de trixie suffit (le snap embarque la 1.3.0, mais
le client n'exige que la 1.x, et layer-shell ne sert pas sous GNOME).

### Compiler le client à la main (développement)

```bash
cd upstream/client
CARGO_TARGET_DIR=../../build/target cargo build --release --locked \
  -p myna-desktop -p myna-cli -p myna-hud -p myna-config
# schéma GSettings non installé : le compiler à part
mkdir -p ../../build/schemas && cp data/glib-2.0/schemas/*.xml ../../build/schemas/
glib-compile-schemas ../../build/schemas
GSETTINGS_SCHEMA_DIR=../../build/schemas GSETTINGS_BACKEND=keyfile \
  ../../build/target/release/myna-desktop --status --backend-dir "$XDG_RUNTIME_DIR/myna"
```

`CARGO_TARGET_DIR` hors du sous-module évite de le salir. Le binaire du crate
`myna-cli` s'appelle `myna-testbed`.

### Construire les paquets

```bash
scripts/build.sh myna          # ou myna-whisper, gnome-shell-extension-myna
scripts/build.sh all
```

Les `.deb` sont produits dans `build/<paquet>/`, avec le rapport de lintian.
`debian/changelog` doit porter la version de `upstream/dev/version.sh`, sinon
le script s'arrête. Il faut le réseau (crates Rust, roues PyPI).

## Modèles Whisper

Aucun modèle n'est embarqué. Pour en télécharger un dans
`~/.local/share/myna/models/<taille>` :

```bash
scripts/fetch-model.sh base    # tiny, base, small, large-v3, large-v3-turbo
```

Le moteur CPU de l'amont ne propose que `tiny`, `base` (défaut) et `small` ;
`large-*` est prévu pour le GPU (float16).

## Lancer le moteur à la main (développement)

```bash
cd upstream/server
UV_PROJECT_ENVIRONMENT=../../build/venv-whisper \
  uv sync --locked --extra whisper --no-dev --python /usr/bin/python3
cd ../..
scripts/run-whisper.sh base     # socket et provider.env dans $XDG_RUNTIME_DIR/myna/whisper/
```

`scripts/run-whisper.sh` reproduit `upstream/whisper-snap/engines/cpu/server`
(type de calcul lu dans le `model.yaml` du modèle, déchargement après 300 s
d'inactivité). Test sans micro, avec le fichier audio de l'amont :

```bash
build/target/release/myna-testbed --backend-dir "$XDG_RUNTIME_DIR/myna" \
  --clip upstream/tests/spread/adapter-smoke/fixture.wav --mode batch
```

## Structure

```
upstream/                     sous-module canonical/myna (jamais modifié directement)
packages/<paquet>/debian/     empaquetage ; modifications de l'amont dans debian/patches/ (quilt)
scripts/build.sh              assemble build/<paquet> et lance debuild
scripts/fetch-model.sh        télécharge un modèle Whisper (développement)
scripts/run-whisper.sh        lance le moteur depuis build/venv-whisper (développement)
scripts/dev-session.sh        moteur + démon depuis build/, pour tester sans paquet
AUDIT.md                      dépendances au snap et leur remplacement
.github/workflows/build.yml   compilation dans debian:trixie, artefacts sur les tags debian/*
```
