#!/bin/bash
# Session de test sans paquet : moteur Whisper + démon de dictée, depuis build/.
# Arrêt propre avec Ctrl+C. Journaux dans build/logs/.
#
# Prérequis : client compilé depuis build/dev/tree (amont + patches) dans
# build/target/release, venv build/venv-whisper, modèle téléchargé
# (scripts/fetch-model.sh <taille>).
#
# Usage : scripts/dev-session.sh [taille] [options myna-desktop]
#
# Le schéma GSettings est installé pour l'utilisateur dans
# ~/.local/share/glib-2.0/schemas/ (GLib y cherche aussi), pour que le HUD
# lancé par gnome-shell le trouve. Pour le retirer :
#   rm ~/.local/share/glib-2.0/schemas/com.canonical.Myna.Dictation.gschema.xml
#   glib-compile-schemas ~/.local/share/glib-2.0/schemas
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
size="${1:-base}"
[ $# -gt 0 ] && shift
bin="$root/build/target/release"
logs="$root/build/logs"
backend_dir="$XDG_RUNTIME_DIR/myna"
socket="$backend_dir/whisper/myna.sock"

[ -x "$bin/myna-desktop" ] || { echo "client non compilé : $bin/myna-desktop" >&2; exit 1; }

schemas="${XDG_DATA_HOME:-$HOME/.local/share}/glib-2.0/schemas"
mkdir -p "$schemas" "$logs"
install -m644 "$root/upstream/client/data/glib-2.0/schemas/com.canonical.Myna.Dictation.gschema.xml" "$schemas/"
glib-compile-schemas "$schemas"

stamp="$(date +%Y%m%d-%H%M%S)"
engine_log="$logs/whisper-$stamp.log"
daemon_log="$logs/myna-desktop-$stamp.log"

engine_pid=
cleanup() {
    [ -n "$engine_pid" ] && kill "$engine_pid" 2>/dev/null && wait "$engine_pid" 2>/dev/null
    echo "==> arrêté. Journaux : $engine_log, $daemon_log"
}
trap cleanup EXIT INT TERM

if pgrep -f "myna-server --socket $socket" >/dev/null; then
    echo "un moteur tourne déjà sur $socket : arrêtez-le d'abord" >&2; exit 1
fi
rm -f "$socket"

echo "==> moteur Whisper ($size), journal : $engine_log"
"$root/scripts/run-whisper.sh" "$size" >"$engine_log" 2>&1 &
engine_pid=$!
for _ in $(seq 1 60); do
    [ -S "$socket" ] && break
    kill -0 "$engine_pid" 2>/dev/null || { echo "le moteur s'est arrêté :" >&2; tail -20 "$engine_log" >&2; exit 1; }
    sleep 0.5
done
[ -S "$socket" ] || { echo "pas de socket après 30 s" >&2; exit 1; }

echo "==> démon myna-desktop, journal : $daemon_log (Ctrl+C pour tout arrêter)"
"$bin/myna-desktop" --backend-dir "$backend_dir" "$@" 2>&1 | tee "$daemon_log"
