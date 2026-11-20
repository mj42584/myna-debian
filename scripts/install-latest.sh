#!/bin/bash
# Installe ou met à jour les paquets depuis la dernière release GitHub de ce
# dépôt, puis redémarre les services utilisateur (le postinst ne peut pas le
# faire pour chaque session).
#
# Usage : scripts/install-latest.sh [-y]
#   -y : ne pas demander confirmation avant sudo apt install
# Variable : MYNA_DEBIAN_REPO (défaut : mj42584/myna-debian)
set -euo pipefail

repo="${MYNA_DEBIAN_REPO:-mj42584/myna-debian}"
yes=false
[ "${1:-}" = -y ] && yes=true

json="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$repo/releases/latest")"
mapfile -t release < <(python3 -I -c '
import json, sys
r = json.load(sys.stdin)
print(r["tag_name"])
for a in r["assets"]:
    if a["name"].endswith(".deb"):
        print(a["browser_download_url"])' <<< "$json")
tag="${release[0]}"
urls=("${release[@]:1}")
[ "${#urls[@]}" -gt 0 ] || { echo "aucun .deb dans la release $tag" >&2; exit 1; }

# debian/0.3.3+git4.ea14d428+deb13_1 → 0.3.3+git4.ea14d428+deb13~1
new="${tag#debian/}"; new="${new%_*}~${new##*_}"
installed="$(dpkg-query -W -f '${Version}' myna 2>/dev/null || true)"
echo "Release : $tag"
echo "Installé : ${installed:-aucun}  →  disponible : $new"
if [ -n "$installed" ] && dpkg --compare-versions "$installed" ge "$new"; then
    echo "Déjà à jour."
    exit 0
fi

dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
chmod 755 "$dir"   # lisible par l'utilisateur _apt
for u in "${urls[@]}"; do
    echo "  ${u##*/}"
    curl -fsSL -o "$dir/${u##*/}" "$u"
done

if ! $yes; then
    read -rp "Installer avec sudo apt install ? [o/N] " r
    case "$r" in [oOyY]*) ;; *) echo "Abandon."; exit 0 ;; esac
fi
sudo apt install "$dir"/*.deb

# Redémarre seulement les services déjà actifs.
systemctl --user try-restart myna-whisper.service myna.service || true
echo "==> $new installé. Si l'extension GNOME a changé : se déconnecter puis se reconnecter."
