# Audit des dépendances au snap

Commit amont audité : `ea14d428` (`v0.3.3-4`). Chemins relatifs à `upstream/`.
Les tests (`tests/`, `#[cfg(test)]`, fichiers `.po`) sont exclus.

## Synthèse

- **Le chemin de dictation ne demande a priori aucun patch.** Le démon accepte
  déjà `--backend-dir <dir>` (ou `--socket <chemin>`) et le serveur
  `--socket <chemin> --share-provider`. Le snap ne fait que passer
  `$SNAP_DATA/backend` en argument depuis un script d'enrobage. Il suffit de
  pointer les deux sur `$XDG_RUNTIME_DIR/myna/` et de définir `SNAP_NAME` /
  `SNAP_INSTANCE_NAME` dans l'environnement du moteur (exigés pour écrire
  `provider.env`).
- **Deux points demanderont sans doute un patch** :
  1. l'extension GNOME lance l'indicateur par `snap run myna.hud` (contournable
     sans patch par `MYNA_HUD_BINARY`) ;
  2. le magasin de réglages retombe sur `~/snap/myna/common/.config/...` quand
     `GSETTINGS_BACKEND=keyfile` n'est pas défini (fonctionne tel quel, mais
     chemin trompeur).
- **Myna Settings (`myna-config`) est un frontal de snapd** : installation des
  modèles, choix du moteur, configuration (`modelctl`) et assistant passent par
  snapd et `pkexec snap`. Sans snapd, seuls les réglages de dictation, le
  raccourci et le diagnostic peuvent servir. Gros chantier, à trancher avant la
  phase 6 (voir « Décisions à prendre »).
- La variable `MYNA_BACKEND_DIR` envisagée dans la mission est inutile :
  `--backend-dir` existe déjà.

## Organisation cible en natif

```
$XDG_RUNTIME_DIR/myna/                 ← --backend-dir du démon
└── whisper/                           ← un sous-dossier par moteur
    ├── myna.sock                      ← --socket du moteur
    └── provider.env                   ← écrit par --share-provider
        SNAP_NAME=myna-whisper
        SNAP_INSTANCE_NAME=myna-whisper
        UNIX_SOCKET=myna.sock
${XDG_DATA_HOME:-~/.local/share}/myna/models/<taille>/   ← modèles (MODEL_DIR)
${XDG_CONFIG_HOME:-~/.config}/glib-2.0/settings/keyfile  ← réglages (GSettings keyfile)
```

Le client relit `provider.env` à chaque appui sur le raccourci : le moteur peut
démarrer après le démon, être redémarré ou changé sans relancer le démon.

## Dépendances dans le code

| Fichier:ligne | Dépendance | Effet en natif | Remplacement | Patch ? |
|---|---|---|---|---|
| `client/myna-orchestrator/src/backend/share.rs:145-227` | lit `<dir>/*/provider.env`, exige `SNAP_NAME` et `UNIX_SOCKET` (relatif, dans le partage) | fonctionne avec n'importe quel dossier ; le test de point de montage (`/proc/self/mountinfo`, l. 238) ne joue que pour un sous-dossier vide | `--backend-dir $XDG_RUNTIME_DIR/myna` | non |
| `myna-snap/scripts/myna-daemon` | `--backend-dir "$SNAP_DATA/backend"`, ou `--socket "$MYNA_BACKEND_SOCKET"` ; `--language "$MYNA_LANGUAGE"` | script propre au snap | `ExecStart=` du service `myna.service` | non (pas installé) |
| `myna-snap/scripts/myna-runtime-links` | lien `$XDG_RUNTIME_DIR/pipewire-0` vers le socket hôte | inutile (pas d'espace de noms) | rien | non |
| `myna-snap/scripts/myna-status` | `--status --backend-dir "$SNAP_DATA/backend"` | script propre au snap | `myna-desktop --status --backend-dir $XDG_RUNTIME_DIR/myna` (petit script `myna-status` dans le paquet) | non |
| `myna-snap/scripts/myna-config` | enrobe `gsettings` avec le schéma Myna | utile : `gsettings` seul lirait dconf, pas le keyfile | script équivalent `GSETTINGS_BACKEND=keyfile gsettings …` | non |
| `client/myna-core/src/settings.rs:305-322` (`store_path`) | sans `GSETTINGS_BACKEND=keyfile`, magasin dans `$SNAP_USER_COMMON` ou à défaut `~/snap/myna/common/.config/glib-2.0/settings/keyfile` | fonctionne mais crée `~/snap/myna/` ; tous les processus (démon, HUD, Myna Settings) s'accordent sur ce chemin | soit exporter `GSETTINGS_BACKEND=keyfile` partout (service, `.desktop`, extension), soit patcher le repli vers `~/.config` hors snap | **probable** (une ligne) |
| `client/myna-desktop/src/bin/myna-desktop.rs:808-817` (`toggle_command`) | `/snap/bin/<instance>.toggle` si `SNAP_INSTANCE_NAME` est défini | sinon `<exe> --toggle` : correct en natif | rien | non |
| `client/myna-desktop/src/bin/myna-desktop.rs:1026-1027` | message de `--status` si le dossier commence par `/var/snap/` | jamais déclenché | rien | non |
| `client/myna-desktop/src/inject/ibus.rs:263-275` | ajoute `$SNAP_REAL_HOME/.config/ibus/bus` aux dossiers candidats | variable absente, ignorée ; `XDG_CONFIG_HOME` et `HOME` suffisent | rien | non |
| `server/src/myna/server/provider_env.py:37-47` | `--share-provider` exige `SNAP_NAME` et `SNAP_INSTANCE_NAME` | échec au démarrage sinon | `Environment=SNAP_NAME=myna-whisper SNAP_INSTANCE_NAME=myna-whisper` dans `myna-whisper.service` | non |
| `server/src/myna/server/lifecycle.py:166` | sous snap, ne lit que le cgroup propre | hors snap, remonte jusqu'à la racine du cgroup : comportement voulu | rien | non |
| `server/src/myna/core/transport_ws.py:265-268` | activation par socket systemd (`LISTEN_FDS`) prise en charge | possibilité, pas une dépendance | piste pour `myna-whisper.socket` plus tard | non |
| `extensions/myna-shell/resolve.js:27-66` | lance l'indicateur par `snap run myna.hud` ; seule autre voie : `MYNA_HUD_BINARY` | sans snapd, `source: 'missing'` → pas d'indicateur | soit `MYNA_HUD_BINARY=/usr/bin/myna-hud` via `/usr/lib/environment.d/` (gnome-shell tourne sous systemd utilisateur), soit patch : essayer `/usr/bin/myna-hud` avant `snap` | **probable** (proposable en amont) |
| `client/myna-config/src/**` (`adapters/snapd_client.rs`, `snap_backend.rs`, `system_configurator.rs`, `onboarding*.rs`, `snap_install.rs`, `active_backend.rs`…) | snapd REST (`/run/snapd.socket`), `snap run <moteur>.modelctl`, `pkexec myna-config --apply-plan/--set-up` | modèles, moteur, assistant inutilisables ; à vérifier : l'appli démarre-t-elle sans snapd ? | voir « Décisions à prendre » | **oui, ou empaquetage partiel** |
| `client/myna-config/src/shortcut.rs:11` | raccourci = `gdbus call … com.canonical.Myna.Dictation.Toggle` | indépendant du snap, fonctionne | rien | non |

## Variables d'environnement définies par les snaps

### Snap `myna` (`myna-snap/snap/snapcraft.yaml`)

| Variable | Ligne | Valeur dans le snap | Utile en natif ? | Remplacement |
|---|---|---|---|---|
| `SPA_PLUGIN_DIR` | 26 | `$SNAP/usr/lib/<triplet>/spa-0.2` | non | défaut compilé de la libpipewire Debian |
| `PIPEWIRE_MODULE_DIR` | 27 | `$SNAP/usr/lib/<triplet>/pipewire-0.3` | non | idem |
| `PIPEWIRE_CONFIG_DIR` | 28 | `$SNAP/usr/share/pipewire` (contient le dépôt `client.conf.d/10-myna-rt.conf`) | non | facultatif : installer `myna-snap/pipewire/usr/share/pipewire/client.conf.d/10-myna-rt.conf` dans `/usr/share/pipewire/client.conf.d/` (module `rt`, `ifexists nofail`) ; s'applique alors à tous les clients PipeWire, donc à évaluer |
| `GSETTINGS_SCHEMA_DIR` | 35 | `$SNAP/usr/share/glib-2.0/schemas` | non | schéma dans `/usr/share/glib-2.0/schemas/` (compilé par le trigger de `libglib2.0`) |
| `GSETTINGS_BACKEND` | 64 | `keyfile` (apps `myna`, `toggle`, `status`, `config`, `testbed`) | **oui**, sauf patch de `store_path` | `Environment=` du service + scripts d'enrobage |
| `XDG_CONFIG_HOME` | 65 | `$SNAP_USER_COMMON/.config` | non | défaut XDG (`~/.config`) |
| `XDG_DATA_DIRS` | 66 | préfixe `$SNAP/usr/share` (traductions, schéma) | non | `/usr/share` |
| `XDG_CONFIG_HOME` (`install-shortcut`) | 145 | `$SNAP_REAL_HOME/.config` | non | défaut |
| `NO_AT_BRIDGE` (`hud`) | 42 | `1` | à vérifier | le snap coupe l'accessibilité du HUD ; garder par prudence dans le lanceur de `myna-hud` ? |
| extension `gnome` (`hud`) | 40 | runtime GNOME du snap | non | bibliothèques Debian |

Le service utilisateur du snap : `daemon: simple`, `daemon-scope: user`,
`refresh-mode: restart` → `myna.service` en `Type=simple`, `Restart=on-failure`.

### Snap `myna-whisper` (`whisper-snap/snap/snapcraft.yaml`, hooks, `engines/cpu/server`)

| Élément | Où | Rôle | Remplacement natif |
|---|---|---|---|
| `SNAP_COMPONENTS` | snapcraft.yaml:22 | racine des composants (modèles) | inutile |
| `MODEL_DIR` | `models/*/model.yaml` (`$SNAP_COMPONENTS/model-<taille>`) | dossier du modèle CTranslate2 | `~/.local/share/myna/models/<taille>` |
| `MODEL_COMPUTE_TYPE` | `models/*/model.yaml` (`base` : `float32`) | type de calcul mesuré par modèle | reporter la valeur de chaque `model.yaml` dans le lanceur |
| `MODEL_BATCH_CONDITION_ON_PREVIOUS_TEXT`, `MODEL_BATCH_VAD_FILTER` | `models/large-*/model.yaml` | politique de décodage des gros modèles | idem (seulement pour `large-*`) |
| `modelctl get ws.unix-socket` | `engines/cpu/server:3`, hooks `install`/`post-refresh` (`$SNAP_COMMON/share/provider/myna.sock`) | chemin du socket | `$XDG_RUNTIME_DIR/myna/whisper/myna.sock` |
| `modelctl get sleep-idle-seconds` | `engines/cpu/server:4`, hook `install` (`300`) | déchargement du modèle après inactivité | `--sleep-idle-seconds 300` |
| `modelctl get compute-type` | `engines/cpu/server:11` (`auto`) | forçage du type de calcul | variable d'environnement facultative, défaut `auto` → `MODEL_COMPUTE_TYPE` |
| `modelctl get streaming` | `engines/cpu/server:22`, hook `install` (`false`) | mode flux | `--streaming` facultatif, défaut non |
| `modelctl use-engine`, `cuda_probe` | hooks `install`, `connect-plug-hardware-observe`, `post-refresh` | choix CPU/CUDA | CPU seulement pour commencer |
| `modelctl run -- $SNAP/engines/$engine/server` | `scripts/server.sh` | exporte l'environnement du modèle actif puis lance le moteur | lanceur `myna-whisper-server` qui lit la taille choisie dans un fichier de configuration et reproduit les arguments de `engines/cpu/server` |
| slot `provider` (content) | snapcraft.yaml, `source.write: $SNAP_COMMON/share/provider` | partage du socket vers le client | dossier commun `$XDG_RUNTIME_DIR/myna/whisper` |

Le moteur du snap tourne en **service système** (`daemon: simple`, sans
`daemon-scope`) ; en natif, un **service utilisateur** suffit et évite tout
problème de droits sur `$XDG_RUNTIME_DIR`.

Arguments à reproduire (`engines/cpu/server`) :
`myna-server --socket <s> --share-provider --model <MODEL_DIR> --device cpu
--compute-type <type> --sleep-idle-seconds 300 --idle-action unload
[--streaming] [politique batch]`.

Le snap élague `onnxruntime`, `google`, `protobuf` et `flatbuffers` du venv CPU
(`dev/prune-runtime.sh`) : à reproduire pour réduire `/opt/myna-whisper`.

## Myna Settings et son empaquetage (`myna-config-deb/debian/`)

- `Build-Depends` : `blueprint-compiler (>= 0.12)`, `cargo`/`rustc (>= 1.85)`
  (le rustc de la distribution ; trixie a 1.85.1 : à vérifier en phase 6),
  `appstream`, `xvfb` et `dbus-daemon` pour les tests. La compilation est
  `--offline` sur un dossier `vendor/` produit par `myna-config-deb/build-source.sh`.
- `Depends: snapd, pkexec, libglib2.0-bin` → retirer `snapd`.
- `install` : livre **aussi** le schéma GSettings et l'extension GNOME →
  conflit de fichiers avec les paquets `myna` et `gnome-shell-extension-myna`
  prévus. À répartir : schéma dans `myna`, extension dans
  `gnome-shell-extension-myna`, `myna-config` dépend de `myna`.
- `team-ppa.sources`, `postinst` (migration de la source PPA) et le test
  `ppa-transition` : à retirer.
- `myna-hud-host` et `etc/xdg/autostart/com.canonical.Myna.HudHost.desktop` :
  pour Xfce et Plasma seulement (`OnlyShowIn=XFCE;KDE;`) ; garder ou retirer.
- Politique polkit `com.canonical.Myna.Config.policy` : ne sert qu'aux commandes
  `snap` en root ; inutile sans snapd.
- Test `extension` : vérifie que `shell-version` contient la version de
  gnome-shell de la distribution ; `metadata.json` déclare 46 à 51, **48 est
  couvert**.

## Raccourci et GNOME 48

Le raccourci n'utilise pas le portail GlobalShortcuts : `--install-shortcut` et
Myna Settings écrivent un raccourci personnalisé GNOME (media-keys) qui appelle
`Toggle` sur `com.canonical.Myna.Dictation` (`gdbus`) ou `myna-desktop --toggle`.
Cela devrait marcher sous GNOME 48 ; GlobalShortcuts n'est cité que dans la
documentation (`client/.kb/desktop-integration.md`,
`client/myna-config/docs/onboarding.md`).

## Divers

- Le binaire « `myna-cli` » s'appelle en fait **`myna-testbed`** (crate
  `myna-cli`).
- Le snap compile gtk4-layer-shell 1.3.0 avec meson ; trixie fournit la 1.0.4
  (phase 3).
- Traductions : `myna-desktop/po` et `myna-orchestrator/po` compilées en
  `<domaine>.mo` sous `/usr/share/locale` (snapcraft.yaml, partie `client`).

## Décisions à prendre

1. ~~**Réglages**~~ : tranché en phase 5, patch
   `packages/myna/debian/patches/0001-settings-native-store.patch` (exporter
   `GSETTINGS_BACKEND=keyfile` aurait dû valoir pour toute la session, HUD
   lancé par gnome-shell compris, et sortir toutes les applis GNOME de dconf).
2. ~~**Indicateur**~~ : tranché en phase 5, patch
   `packages/gnome-shell-extension-myna/debian/patches/0001-hud-native-binary.patch`
   (repli `/usr/bin/myna-hud` après l'override et snap ; propre à Debian,
   l'amont refuse explicitement ce repli dans `resolve.js`).
3. **Myna Settings** : (a) l'empaqueter tel quel et accepter que les pages
   modèle/assistant échouent ; (b) le patcher pour masquer ce qui dépend de
   snapd ; (c) le reporter et documenter `myna-config`-le-script
   (`gsettings`) + `--install-shortcut`. Recommandation : (c) pour une
   première version, puis voir si (b) est raisonnable.

## Constats de la phase 3

- **Myna Settings sans snapd** (testé le 20/11/2026, binaire de
  `build/target/release`) : l'appli démarre, mais
  `onboarding::needs_onboarding` conclut que Myna n'est pas installé
  (`snapd transport error: connect /run/snapd.socket`) et n'affiche que
  l'assistant. « Installer » prépare `snap set system experimental.user-daemons`,
  `snap install myna myna-parakeet`, `snap connect`, puis échoue :
  `privileged configuration failed: cannot run snap`, **après** une demande de
  mot de passe polkit (l'utilisateur s'est authentifié : `pkexec` a bien lancé
  `myna-config --set-up` en root, qui n'a pas trouvé `snap`). Les pages de réglages ne
  sont pas atteignables. Une option (a) est donc exclue ; reste (b) ou (c).
- gtk4-layer-shell : le crate `gtk4-layer-shell-sys` 0.5.2 demande
  `gtk4-layer-shell-0 >= 1` (1.3 seulement avec la fonctionnalité `v1_3`, non
  activée). La 1.0.4 de trixie suffit ; inutile sous GNOME (Mutter n'a pas
  wlr-layer-shell), l'hôte `--host layer-shell` vise KWin.
## Constats de la phase 4

- `uv sync --locked --extra whisper --no-dev` avec le Python 3.13.5 de Debian :
  24 paquets, tous en roues binaires (aucune compilation) ; `ctranslate2` 4.8.0,
  `faster-whisper` 1.2.1, `numpy` 2.5.3, `onnxruntime` 1.27.0. Venv : 381 Mo,
  dont `onnxruntime` 52 Mo, que le snap élague pour le moteur CPU.
- Moteur lancé hors snap (`scripts/run-whisper.sh base`) : socket et
  `provider.env` créés dans `$XDG_RUNTIME_DIR/myna/whisper/`, `myna-desktop
  --status` voit `myna-whisper` / `whisper-base`, `myna-testbed --clip` transcrit
  `tests/spread/adapter-smoke/fixture.wav` correctement (≈ 6 s, chargement
  compris). **Aucun patch nécessaire.**
- `provider.env` reste après l'arrêt du moteur (voulu par l'amont : identité
  statique, la présence du socket fait foi).
- Les dépôts Systran ne contiennent pas `preprocessor_config.json` ; inutile
  pour faster-whisper.

## Divers (phase 3)

- Version rapportée par les binaires sans `client/.version` :
  `0.3.3+git4.ea14d428` (`dev/version.sh` : nombre de commits depuis le tag, pas
  une date).

## Constats de la phase 5 (dictée de bout en bout, 20/11/2026)

Session : `scripts/dev-session.sh base` (moteur + démon depuis `build/`, client
compilé depuis l'amont patché), raccourci `<Super>d` posé par
`myna-desktop --install-shortcut` (raccourci personnalisé GNOME → `--toggle`).

- **Dictée** : texte français injecté par IBus dans gedit et dans la barre
  d'adresse de Firefox ; accents, ponctuation et espaces corrects ; langue
  détectée par Whisper (fr, 0,98-0,99) ; transcription ≈ 2 s après l'arrêt.
- **Sans extension** : notification + son à chaque début de dictée.
- **Avec l'extension** (copiée dans `~/.local/share/gnome-shell/extensions/`,
  activée après reconnexion) : pilule en bas de l'écran, suivant le niveau de
  la voix ; l'extension démarre et arrête l'indicateur avec le démon, qui
  compte 2 clients enregistrés (extension et HUD).
- **GNOME 48** : rien à contourner ; le raccourci n'utilise plus GlobalShortcuts
  côté amont.
- **Non testé** : le repli `/usr/bin/myna-hud` du patch (l'indicateur a été
  lancé par `MYNA_HUD_BINARY`, défini dans
  `~/.config/environment.d/50-myna-dev.conf`, à supprimer une fois le paquet
  installé) ; le mode flux (`--streaming`).
