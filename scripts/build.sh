#!/bin/bash
# Assemble build/<paquet>/<paquet>-<version>/ à partir de upstream/ (commit
# épinglé, sans les fichiers non suivis) et de packages/<paquet>/debian, puis
# lance debuild. Les .deb sont produits dans build/<paquet>/.
#
# Usage : scripts/build.sh <paquet>|all [options debuild supplémentaires]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
packages=(myna myna-whisper gnome-shell-extension-myna)

usage() {
    echo "usage : $0 {$(IFS='|'; echo "${packages[*]}")|all} [options debuild]" >&2
    exit 2
}

# Version amont, calculée par l'amont lui-même : X.Y.Z sur un tag, sinon
# X.Y.Z+git<commits depuis le tag>.<sha>. Exige les tags de l'amont (pas de
# clone superficiel du sous-module).
upstream_version() {
    local v
    v="$(bash "$root/upstream/dev/version.sh")"
    case "$v" in
        0+git.*) echo "tags de l'amont absents : git -C upstream fetch --tags --unshallow" >&2; exit 1 ;;
    esac
    echo "$v"
}

build_one() {
    local pkg="$1"; shift
    local debdir="$root/packages/$pkg/debian"
    [ -d "$debdir" ] || { echo "paquet inconnu : $pkg" >&2; usage; }
    if [ ! -f "$debdir/control" ]; then
        echo "$pkg : pas de debian/control" >&2
        exit 1
    fi

    local version srcdir debversion
    version="$(upstream_version)"
    debversion="$(dpkg-parsechangelog -l "$debdir/changelog" -S Version)"
    if [ "${debversion%+deb13~*}" != "$version" ]; then
        echo "$pkg : debian/changelog ($debversion) ne correspond pas à l'amont ($version)" >&2
        exit 1
    fi
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
    # cargo 1.85 de Debian au lieu de la toolchain rustup (1.99.0), et ne
    # trouverait pas uv (~/.local/bin).
    (cd "$srcdir" && debuild --prepend-path="${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.local/bin" \
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
