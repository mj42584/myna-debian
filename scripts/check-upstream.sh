#!/bin/bash
# Dit si l'amont a publié une release plus récente que le commit épinglé.
#
# Référence : la dernière release *publiée* de canonical/myna (les brouillons
# sont exclus). L'amont ne la publie qu'une fois les snaps sur edge et le PPA
# à la bonne version (upstream/.kb/releasing.md), elle correspond donc à la
# sortie du snap.
#
# Sortie : le tag de la nouvelle release sur stdout, rien si le commit épinglé
# la contient déjà. Code retour non nul seulement en cas d'erreur.
#
# Usage : scripts/check-upstream.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
repo=canonical/myna

[ -e "$root/upstream/.git" ] || { echo "sous-module absent : git submodule update --init" >&2; exit 1; }

latest="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$repo/releases/latest" |
    python3 -I -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
[ -n "$latest" ] || { echo "release introuvable sur $repo" >&2; exit 1; }

git -C "$root/upstream" fetch -q --tags origin
pinned="$(git -C "$root/upstream" describe --tags)"

if git -C "$root/upstream" merge-base --is-ancestor "$latest" HEAD; then
    echo "à jour : $latest est contenu dans le commit épinglé ($pinned)" >&2
else
    echo "nouvelle release amont : $latest (épinglé : $pinned)" >&2
    echo "$latest"
fi
