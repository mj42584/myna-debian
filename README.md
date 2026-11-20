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
| 1     | Préparation de la machine                 | à faire    |
| 2     | Audit des dépendances au snap (`AUDIT.md`)| à faire    |
| 3     | Compilation du client sans snap           | à faire    |
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

Prérequis : voir la phase 1 (liste complète à venir). Le client demande
Rust 1.99.0 (`upstream/client/rust-toolchain.toml`) alors que trixie fournit
la 1.85 : il faut rustup.

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
