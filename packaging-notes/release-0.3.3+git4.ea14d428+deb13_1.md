Native Debian 13 (trixie) packages of [Myna](https://github.com/canonical/myna) offline voice dictation, built from upstream commit `ea14d428` (`v0.3.3-4`). No snapd needed.

**Unofficial**, not affiliated with Canonical. Tested on Debian 13, GNOME 48 Wayland, amd64.

## Files

- `myna_…_amd64.deb`: dictation daemon, indicator, command-line tools
- `myna-whisper_…_amd64.deb`: CPU Whisper engine (no model included)
- `gnome-shell-extension-myna_…_all.deb`: on-screen indicator for GNOME Shell

GitHub replaces `~` with `.` in the file names; the package version is `0.3.3+git4.ea14d428+deb13~1`.

## Install

```bash
sudo apt install ./myna_*.deb ./myna-whisper_*.deb ./gnome-shell-extension-myna_*.deb
```

Then, as each user:

```bash
myna-whisper-fetch-model base
systemctl --user enable --now myna-whisper.service myna.service
myna-settings set language "'en'"          # your language: 'fr', 'de'…
myna-desktop --install-shortcut '<Super>d'
```

Log out and back in, run `gnome-extensions enable myna-shell@canonical.com`, then press <kbd>Super</kbd>+<kbd>D</kbd> to start and stop dictation.

## Known limitations

- CPU Whisper engine only (no GPU, no other upstream engines).
- Myna Settings is not included (it depends on snapd): use `myna-settings` and `myna-desktop --install-shortcut`.
- `apt purge` does not stop user services that are already running: run `systemctl --user disable --now myna.service myna-whisper.service` first.

Full instructions: [README](https://github.com/mj42584/myna-debian#readme).
