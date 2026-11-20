# myna-debian

Native `.deb` packages of [Myna](https://github.com/canonical/myna), Canonical's
offline voice dictation tool, for **Debian 13 (trixie)** with GNOME on Wayland.
No snapd, no sandbox, minimal changes to the upstream code.

Press a shortcut, speak, and the text is typed into the focused application.
Speech recognition runs locally (Whisper on the CPU); nothing leaves the
machine.

> **Unofficial.** This project is not affiliated with or endorsed by Canonical.
> Upstream only supports Myna as snaps on Ubuntu Desktop; please report
> problems with these packages [here](https://github.com/mj42584/myna-debian/issues), not upstream.
> Tested on a single machine (Debian 13, GNOME 48 Wayland, amd64). Updates
> follow upstream on a best-effort basis, with no guarantee.

Version française : [README.fr.md](README.fr.md). Design notes (French):
[AUDIT.md](AUDIT.md).

## Packages

| Package                      | Contents |
|------------------------------|----------|
| `myna`                       | dictation daemon `myna-desktop` (user service `myna.service`), indicator `myna-hud`, `myna-testbed`, `myna-settings` (settings), `myna-status`, GSettings schema, translations |
| `myna-whisper`               | CPU Whisper engine (faster-whisper / CTranslate2, private Python runtime in `/usr/lib/myna-whisper`), user service `myna-whisper.service`, `myna-whisper-fetch-model`; no model included |
| `gnome-shell-extension-myna` | on-screen indicator at the bottom of the screen (extension `myna-shell@canonical.com`) |

**Myna Settings is not packaged**: the upstream app is a front end to snapd
(model installation, engine choice, setup wizard) and cannot get past its
wizard without snapd. Settings are changed with `myna-settings` and the
shortcut with `myna-desktop --install-shortcut`.

## Install

Download the three `.deb` files from the [latest release](https://github.com/mj42584/myna-debian/releases/latest),
then, in the download directory:

```bash
sudo apt install ./myna_*.deb ./myna-whisper_*.deb ./gnome-shell-extension-myna_*.deb
```

Then, as each user who wants dictation (nothing is enabled by default, since
dictation opens the microphone):

```bash
myna-whisper-fetch-model base                      # tiny, base or small (≈ 150 MB for base)
systemctl --user enable --now myna-whisper.service myna.service
myna-settings set language "'en'"                  # your language: 'fr', 'de'…
myna-desktop --install-shortcut '<Super>d'         # GNOME shortcut: press to start, press to stop
```

Log out and back in, then enable the indicator:

```bash
gnome-extensions enable myna-shell@canonical.com
```

Press <kbd>Super</kbd>+<kbd>D</kbd>, speak, press it again: the text appears in
the focused window (through IBus, which must be running, as it is by default on
GNOME). Without the extension, a notification is shown instead of the
indicator.

Set the language: when it is unset, Whisper guesses it for every utterance and
sometimes gets short sentences wrong.

### Settings and diagnostics

- Engine settings (model, compute type…): copy
  `/usr/share/doc/myna-whisper/examples/whisper.conf` to
  `~/.config/myna/whisper.conf`, then `systemctl --user restart myna-whisper`.
- Dictation settings (language, mode, sounds…): `myna-settings`, e.g.
  `myna-settings set language "'fr'"`; applied immediately.
- Diagnostics: `myna-status`, `journalctl --user -u myna -u myna-whisper`.

### Uninstall

```bash
systemctl --user disable --now myna.service myna-whisper.service   # as each user, first
sudo apt purge myna myna-whisper gnome-shell-extension-myna
```

`apt purge` removes every system file but does not touch home directories or
running sessions:

- user services that are already running keep running until logout (hence the
  `disable --now` first);
- left in the home directory: models (`~/.local/share/myna`),
  `~/.config/myna/whisper.conf` if created, dictation settings (GSettings
  keyfile), the enable links in `~/.config/systemd/user/*.wants/` if `disable`
  was skipped, and the GNOME shortcut (Settings → Keyboard → Custom Shortcuts).

### Known limitations

- CPU Whisper engine only (no GPU, no Parakeet or other upstream engines).
- Myna Settings is not available (see above).
- `myna-whisper` is tied to trixie's Python 3.13 (PyPI wheels): it must be
  rebuilt if Debian changes its Python version.
- amd64 only so far: arm64 is declared but has never been built.
- Not Debian Policy compliant: Rust comes from rustup, and the Rust and Python
  dependencies are downloaded during the build.

## Changes to upstream

Upstream is used as is, pinned as a git submodule. The only changes are two
quilt patches, applied at build time:

- `packages/myna/debian/patches/0001-settings-native-store.patch`: outside a
  snap, store dictation settings in the user's own config directory.
- `packages/gnome-shell-extension-myna/debian/patches/0001-hud-native-binary.patch`:
  let the extension start `/usr/bin/myna-hud` when the snap is absent.

The snap plumbing (service definitions, socket location, engine discovery) is
replaced by the packaging itself: the engine listens on
`$XDG_RUNTIME_DIR/myna/whisper/`, where the daemon finds it.

## Pinned upstream

- Repository: <https://github.com/canonical/myna>, submodule `upstream/`
- Commit: `ea14d428775d1af435e641b083a6440947fa795e` (2026-11-19), i.e.
  `v0.3.3-4-gea14d428`

## Versions and tags

Package version: `<upstream version>+deb13~<n>`. The upstream version follows
`upstream/dev/version.sh` (`X.Y.Z` on a tag, otherwise
`X.Y.Z+git<commits since the tag>.<sha>`), the one the binaries report.

- Current pinned commit: `0.3.3+git4.ea14d428+deb13~1`
- Tags: `debian/<version>` with `~` replaced by `_` (git does not allow `~`
  in ref names, DEP-14 convention), e.g. `debian/0.3.3+git4.ea14d428+deb13_1`.
  Pushing a tag builds the packages on GitHub and publishes them as a release.

## Build from source

### Requirements (Debian 13)

```bash
sudo apt install build-essential devscripts debhelper quilt pkgconf \
  libgtk-4-dev libadwaita-1-dev libpipewire-0.3-dev libclang-dev \
  libwayland-dev wayland-protocols libegl-dev libepoxy-dev libgl1-mesa-dev \
  libglib2.0-dev libglib2.0-dev-bin libgtk4-layer-shell-dev gettext lintian curl git
```

The client needs Rust 1.99.0 (`upstream/client/rust-toolchain.toml`) while
trixie ships 1.85: install rustup with the official script (not Debian's
`rustup` package, which conflicts with `cargo` and `rustc`). The right
toolchain is picked up automatically in `upstream/client/`.

```bash
curl --proto '=https' -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
. ~/.cargo/env
(cd upstream/client && rustup show && cargo --version)   # must show 1.99.0
```

`~/.cargo/bin` must come before `/usr/bin` in `PATH`, otherwise Debian's cargo
(1.85) is used. The Whisper engine also needs [uv](https://docs.astral.sh/uv/).

### Build the packages

```bash
git clone --recurse-submodules https://github.com/mj42584/myna-debian
cd myna-debian
scripts/build.sh all            # or: myna, myna-whisper, gnome-shell-extension-myna
```

The `.deb` files land in `build/<package>/`, with the lintian report. Network
access is needed (Rust crates, PyPI wheels). `debian/changelog` must carry the
version given by `upstream/dev/version.sh`, otherwise the script stops.

### Development without packages

`scripts/dev-session.sh`, `scripts/run-whisper.sh` and `scripts/fetch-model.sh`
run the engine and the daemon straight from `build/`; see
[README.fr.md](README.fr.md) for details.

## Updating upstream

```bash
git -C upstream fetch origin
git -C upstream checkout <new-commit>
git add upstream
```

Then:

1. update "Pinned upstream" and the `debian/changelog` files (new version, `~1`);
2. check that the patches still apply: `quilt push -a` in each `build/<package>`;
3. review changes to `myna-snap/`, `whisper-snap/` and `client/` that touch the
   paths listed in `AUDIT.md`;
4. commit, rebuild, test dictation, then tag.

## Layout

```
upstream/                     canonical/myna submodule (never modified directly)
packages/<package>/debian/    packaging; upstream changes in debian/patches/ (quilt)
scripts/build.sh              assembles build/<package> and runs debuild
scripts/fetch-model.sh        downloads a Whisper model (development)
scripts/run-whisper.sh        runs the engine from build/venv-whisper (development)
scripts/dev-session.sh        engine + daemon from build/, to test without packages
AUDIT.md                      snap dependencies and their replacements (French)
packaging-notes/              release notes published with each tag
.github/workflows/build.yml   build in debian:trixie, release on debian/* tags
```

## License

AGPL-3.0-or-later, like upstream. See [LICENSE](LICENSE). Licenses of the
bundled Rust crates and Python packages are listed in each package's
`/usr/share/doc/<package>/`.
