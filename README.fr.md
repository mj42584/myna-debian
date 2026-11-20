# myna-debian

Paquets `.deb` natifs pour **Debian 13 (trixie)**, GNOME sous Wayland, de
[Myna](https://github.com/canonical/myna), l'outil de dictée vocale hors ligne
de Canonical. Pas de snapd, pas de bac à sable, un minimum de modifications du
code amont.

English version: [README.md](README.md).

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
| 7     | Validation sur une installation propre    | ✅ fait     |
| 8     | Suivi automatique de l'amont              | à valider  |

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

Télécharger les trois `.deb` de la [dernière release](https://github.com/mj42584/myna-debian/releases/latest),
puis, dans le dossier de téléchargement :

```bash
sudo apt install ./myna_*.deb ./myna-whisper_*.deb ./gnome-shell-extension-myna_*.deb
```

Puis, pour chaque utilisateur (rien n'est activé d'office : la dictation ouvre
le micro) :

```bash
myna-whisper-fetch-model base                      # tiny, base ou small (≈ 150 Mo pour base)
systemctl --user enable --now myna-whisper.service myna.service
myna-settings set language "'fr'"                  # sinon Whisper devine la langue à chaque dictée
myna-desktop --install-shortcut '<Super>d'         # raccourci GNOME : appui = début/fin
gnome-extensions enable myna-shell@canonical.com   # après une reconnexion
```

Sans langue réglée, Whisper la détecte sur chaque dictée et se trompe parfois
sur les phrases courtes (russe ou espagnol au lieu du français lors du test
sur un compte neuf).

- Réglages du moteur (modèle, type de calcul…) : copier
  `/usr/share/doc/myna-whisper/examples/whisper.conf` dans
  `~/.config/myna/whisper.conf`, puis `systemctl --user restart myna-whisper`.
- Réglages de dictation (langue, mode, sons…) : `myna-settings`, par ex.
  `myna-settings set language "'fr'"` ; pris en compte à la volée.
- Diagnostic : `myna-status`, `journalctl --user -u myna -u myna-whisper`.

### Mettre à jour

Les paquets suivent les releases de l'amont (voir « Mettre à jour l'amont »).
Depuis un clone de ce dépôt :

```bash
scripts/install-latest.sh
```

Le script télécharge la dernière release, l'installe avec `sudo apt install`
après confirmation et redémarre les services utilisateur actifs.

### Désinstaller

```bash
systemctl --user disable --now myna.service myna-whisper.service   # pour chaque utilisateur, avant
sudo apt purge myna myna-whisper gnome-shell-extension-myna
```

`apt purge` ne laisse aucun fichier système, mais ne touche pas aux dossiers
personnels ni aux sessions ouvertes :

- les services utilisateur déjà lancés continuent de tourner jusqu'à la
  déconnexion (d'où le `disable --now` préalable) ;
- restent dans le dossier personnel : les modèles (`~/.local/share/myna`),
  `~/.config/myna/whisper.conf` s'il a été créé, les réglages de dictation
  (keyfile GSettings), les liens d'activation dans
  `~/.config/systemd/user/*.wants/` si `disable` n'a pas été fait, et le
  raccourci GNOME (Paramètres → Clavier → Raccourcis personnalisés, ou
  `dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/myna/`
  puis retirer son chemin de la clé `custom-keybindings`).

### Limites connues

- Moteur Whisper CPU seulement (pas de GPU, pas de Parakeet ni des autres
  moteurs de l'amont).
- `myna-whisper` est lié au Python 3.13 de trixie (roues PyPI) : à reconstruire
  si Debian change de version de Python.
- Myna Settings n'est pas fourni (frontal de snapd) : réglages en ligne de
  commande seulement.
- Testé sur une seule machine (Debian 13, GNOME 48 Wayland, amd64) ; arm64
  déclaré mais jamais construit.
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
- Publication : `build.yml` publie la release sur un tag `debian/*` poussé, ou
  sur `main` quand la version du changelog n'a pas encore de tag (il le crée).
  Texte : `packaging-notes/release-<tag>.md`.

## Récupérer le dépôt

```bash
git clone --recurse-submodules https://github.com/mj42584/myna-debian
```

Pour un clone existant : `git submodule update --init`.

## Mettre à jour l'amont

Presque automatique. L'amont publie une release GitHub une fois ses snaps sur
edge ; les paquets suivent ces releases.

1. **Détection** (quotidienne, `.github/workflows/watch-upstream.yml`) :
   `scripts/check-upstream.sh` compare la dernière release publiée de l'amont
   au commit épinglé.
2. **Préparation** : `scripts/update-upstream.sh <ref>` déplace le
   sous-module, ajoute l'entrée `<version>+deb13~1` aux trois
   `debian/changelog`, met à jour « Amont épinglé » dans les deux README,
   écrit les notes de release dans `packaging-notes/`, vérifie les patches
   quilt (fuzz 0) et écrit un rapport dans `build/update-report.md` : alertes
   ciblées (toolchain Rust, Python, CTranslate2, modèles, nouveaux moteurs,
   contrat moteur ↔ démon) et diff des chemins de `scripts/watched-paths`
   (tirés de `AUDIT.md`).
3. **Pull request** : le workflow pousse la branche `amont/<ref>`, ouvre une PR
   dont le corps est le rapport (brouillon « ⚠ patch cassé » si un patch ne
   s'applique plus) et lance `build.yml` sur la branche.
4. **Relecture et merge** : lire les alertes et le diff, merger. Le
   `build.yml` de `main` crée le tag et publie la release.
5. **Installation** : `scripts/install-latest.sh`.

Prérequis du workflow : *Settings → Actions → General → Allow GitHub Actions
to create and approve pull requests*. Lancement à la main sur une ref donnée :
`gh workflow run watch-upstream.yml -f ref=origin/main`.

À la main, sans GitHub :

```bash
scripts/check-upstream.sh                    # affiche le nouveau tag s'il y en a un
scripts/update-upstream.sh --build v0.3.4    # code 3 : patch cassé ; 4 : échec de construction
less build/update-report.md
git add -A upstream packages README.md README.fr.md packaging-notes
git commit -m "amont : passage à v0.3.4"
```

Patch cassé : le rafraîchir dans `build/<paquet>` avec quilt (`quilt push -f`,
corriger, `quilt refresh`), le recopier dans `packages/<paquet>/debian/patches/`
et le commiter sur la branche de la PR.

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
scripts/check-upstream.sh     y a-t-il une release amont plus récente ?
scripts/update-upstream.sh    passe à une nouvelle ref amont, vérifie les patches, rapport
scripts/watched-paths         chemins amont relus à chaque mise à jour (tirés de AUDIT.md)
scripts/install-latest.sh     installe la dernière release de ces paquets
packaging-notes/              notes publiées avec chaque release
AUDIT.md                      dépendances au snap et leur remplacement
.github/workflows/build.yml   compilation dans debian:trixie, release sur les tags debian/* ou sur main
.github/workflows/watch-upstream.yml  veille quotidienne de l'amont, ouvre la PR de mise à jour
```
