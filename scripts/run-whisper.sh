#!/bin/bash
# Lance le moteur Whisper CPU hors snap, comme upstream/whisper-snap/engines/cpu/server
# sous `modelctl run`, avec le socket et provider.env dans $XDG_RUNTIME_DIR/myna/whisper/.
# Le démon le trouve avec `myna-desktop --backend-dir "$XDG_RUNTIME_DIR/myna"`.
#
# Usage : scripts/run-whisper.sh [taille] [options myna-server supplémentaires]
#   taille : tiny, base (défaut), small, large-v3, large-v3-turbo
#            (modèle téléchargé par scripts/fetch-model.sh)
#
# Variables (équivalents des clés modelctl du snap) :
#   MYNA_WHISPER_VENV          venv contenant myna-server (défaut : build/venv-whisper)
#   MYNA_WHISPER_COMPUTE_TYPE  compute-type (défaut : auto → MODEL_COMPUTE_TYPE du model.yaml)
#   MYNA_WHISPER_IDLE          sleep-idle-seconds (défaut : 300)
#   MYNA_WHISPER_STREAMING     true pour --streaming (défaut : false)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
size="${1:-base}"
[ $# -gt 0 ] && shift

yaml="$root/upstream/whisper-snap/models/$size/model.yaml"
[ -f "$yaml" ] || { echo "taille inconnue : $size" >&2; exit 2; }
model_dir="${XDG_DATA_HOME:-$HOME/.local/share}/myna/models/$size"
[ -f "$model_dir/model.bin" ] || {
    echo "modèle absent : $model_dir (scripts/fetch-model.sh $size)" >&2; exit 1; }

venv="${MYNA_WHISPER_VENV:-$root/build/venv-whisper}"
[ -x "$venv/bin/myna-server" ] || { echo "myna-server introuvable dans $venv" >&2; exit 1; }

: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR non défini}"
socket="$XDG_RUNTIME_DIR/myna/whisper/myna.sock"

# Variables MODEL_* du model.yaml (section environment:), comme modelctl les
# exporte : MODEL_COMPUTE_TYPE, MODEL_BATCH_*.
model_env() {
    sed -n "s/^  - $1=//p" "$yaml" | head -n1
}

compute_type="${MYNA_WHISPER_COMPUTE_TYPE:-auto}"
if [ "$compute_type" = auto ]; then
    compute_type="$(model_env MODEL_COMPUTE_TYPE)"
    compute_type="${compute_type:-default}"
fi

args=()
[ "${MYNA_WHISPER_STREAMING:-false}" = true ] && args+=(--streaming)
[ "$(model_env MODEL_BATCH_CONDITION_ON_PREVIOUS_TEXT)" = false ] &&
    args+=(--no-batch-condition-on-previous-text)
[ "$(model_env MODEL_BATCH_VAD_FILTER)" = true ] && args+=(--batch-vad-filter)

# --share-provider écrit provider.env à partir de l'identité du snap.
export SNAP_NAME=myna-whisper SNAP_INSTANCE_NAME=myna-whisper

exec "$venv/bin/myna-server" \
    --socket "$socket" \
    --share-provider \
    --model "$model_dir" \
    --device cpu \
    --compute-type "$compute_type" \
    --sleep-idle-seconds "${MYNA_WHISPER_IDLE:-300}" \
    --idle-action unload \
    "${args[@]}" \
    "$@"
