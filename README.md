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
| 4     | Moteur Whisper sans snap                  | à faire    |
| 5     | Dictée de bout en bout, sans paquet       | à faire    |
| 6     | Empaquetage des quatre `.deb`             | à faire    |
| 7     | Validation sur une installation propre    | à faire    |

Rien n'est encore installable.

## Paquets prévus

| Paquet                       | Contenu                                                         |
|------------------------------|-----------------------------------------------------------------|
| `myna`                       | `myna-desktop`, `myna-cli`, `myna-hud`, service utilisateur     |
| `myna-whisper`               | moteur faster-whisper (venv dans `/opt/myna-whisper`), sans modèle |
| `myna-config`                | Myna Settings, adapté de `upstream/myna-config-deb/`            |
| `gnome-shell-extension-myna` | indicateur HUD, depuis `upstream/extensions/myna-shell/`        |

## Amont épinglé

- Dépôt : <https://github.com/canonical/myna>, sous-module `upstream/`
- Commit : `ea14d428775d1af435e641b083a6440947fa795e` (19/11/2026), soit
  `v0.3.3-4-gea14d428`

## Versions et tags

Version des paquets : `<version amont>+deb13~<n>`. La version amont suit le
schéma de `upstream/dev/version.sh` (`X.Y.Z` sur un tag, sinon
`X.Y.Z+git<date du commit>.<sha court>`).

- Commit épinglé actuel : `0.3.3+git20261119.ea14d42+deb13~1`
- Tags de ce dépôt : `debian/<version>`, avec `~` remplacé par `_` (git refuse
  `~` dans un nom de ref, convention DEP-14), par exemple
  `debian/0.3.3+git20261119.ea14d42+deb13_1`.

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
sudo apt install build-essential devscripts debhelper dh-cargo quilt meson ninja-build \
  pkg-config libgtk-4-dev libadwaita-1-dev libpipewire-0.3-dev libclang-dev \
  libwayland-dev wayland-protocols libegl-dev libepoxy-dev libgl1-mesa-dev \
  libglib2.0-dev-bin libgtk4-layer-shell-dev blueprint-compiler gettext lintian curl git
```

Le client demande Rust 1.99.0 (`upstream/client/rust-toolchain.toml`) alors que
trixie fournit la 1.85 : installer rustup (script officiel, pas le paquet
Debian `rustup`, qui entre en conflit avec `cargo` et `rustc` tirés par
`dh-cargo`). La bonne toolchain s'installe toute seule dans `upstream/client/`.

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
`blueprint-compiler` ne sert qu'à Myna Settings.

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
scripts/build.sh myna          # ou myna-whisper, myna-config, gnome-shell-extension-myna
scripts/build.sh all
```

Les `.deb` sont produits dans `build/`.

## Modèles Whisper

Aucun modèle n'est embarqué. Pour en télécharger un dans
`~/.local/share/myna/models/<taille>` :

```bash
scripts/fetch-model.sh base    # tiny, base, small, large-v3, large-v3-turbo
```

## Structure

```
upstream/                     sous-module canonical/myna (jamais modifié directement)
packages/<paquet>/debian/     empaquetage ; modifications de l'amont dans debian/patches/ (quilt)
scripts/build.sh              assemble build/<paquet> et lance debuild
scripts/fetch-model.sh        télécharge un modèle Whisper
AUDIT.md                      dépendances au snap et leur remplacement
.github/workflows/build.yml   compilation dans debian:trixie, artefacts sur les tags debian/*
```
