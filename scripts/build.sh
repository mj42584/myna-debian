#!/bin/bash
# Assemble build/<paquet>/<paquet>-<version>/ à partir de upstream/ (commit
# épinglé, sans les fichiers non suivis) et de packages/<paquet>/debian, puis
# lance debuild. Les .deb sont produits dans build/<paquet>/.
#
# Usage : scripts/build.sh <paquet>|all [options debuild supplémentaires]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
packages=(myna myna-whisper myna-config gnome-shell-extension-myna)

usage() {
    echo "usage : $0 {$(IFS='|'; echo "${packages[*]}")|all} [options debuild]" >&2
    exit 2
}

# Version amont au format de upstream/dev/version.sh, avec la date du commit
# pour qu'elle croisse dans le temps : X.Y.Z ou X.Y.Z+git<AAAAMMJJ>.<sha>.
upstream_version() {
    local tag sha date
    tag="$(git -C "$root/upstream" describe --tags --abbrev=0 --match 'v[0-9]*')"
    sha="$(git -C "$root/upstream" rev-parse --short=7 HEAD)"
    if [ "$(git -C "$root/upstream" rev-parse "$tag^{commit}")" = "$(git -C "$root/upstream" rev-parse HEAD)" ]; then
        echo "${tag#v}"
    else
        date="$(git -C "$root/upstream" show -s --format=%cd --date=format:%Y%m%d HEAD)"
        echo "${tag#v}+git${date}.${sha}"
    fi
}

build_one() {
    local pkg="$1"; shift
    local debdir="$root/packages/$pkg/debian"
    [ -d "$debdir" ] || { echo "paquet inconnu : $pkg" >&2; usage; }
    if [ ! -f "$debdir/control" ]; then
        echo "$pkg : pas encore de debian/control, ignoré (empaquetage en phase 6)" >&2
        return 0
    fi

    local version srcdir
    version="$(upstream_version)"
    srcdir="$root/build/$pkg/$pkg-$version"

    rm -rf "$root/build/$pkg"
    mkdir -p "$srcdir"
    # git archive : uniquement le contenu suivi du commit épinglé.
    git -C "$root/upstream" archive --format=tar HEAD | tar -x -C "$srcdir"
    cp -a "$debdir" "$srcdir/debian"
    rm -f "$srcdir/debian/.gitkeep"
    # Le client lit sa version ici (upstream/.kb/versioning.md).
    echo "$version" > "$srcdir/client/.version"

    echo "==> $pkg $version"
    # debuild remet le PATH à zéro : sans --prepend-path, il prendrait le
    # cargo 1.85 de Debian au lieu de la toolchain rustup (1.99.0).
    (cd "$srcdir" && debuild --prepend-path="${CARGO_HOME:-$HOME/.cargo}/bin" \
        --no-lintian -us -uc -b "$@")
    lintian --info "$root/build/$pkg"/*.changes || true
}

[ $# -ge 1 ] || usage
target="$1"; shift

if [ ! -e "$root/upstream/.git" ]; then
    echo "sous-module absent : git submodule update --init" >&2
    exit 1
fi

if [ "$target" = all ]; then
    for p in "${packages[@]}"; do build_one "$p" "$@"; done
else
    build_one "$target" "$@"
fi
