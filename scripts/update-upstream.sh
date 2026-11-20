#!/bin/bash
# Passe l'amont épinglé à une nouvelle ref et prépare tout ce qui en dépend :
# sous-module, debian/changelog des trois paquets (nouvelle version, ~1),
# sections « Pinned upstream » / « Amont épinglé » des README, notes de release
# (packaging-notes/), vérification des patches quilt et rapport de relecture
# dans build/update-report.md. Ne commite rien.
#
# Usage : scripts/update-upstream.sh [--build] <ref>
#   ref      : tag (v0.3.4), commit ou origin/main de canonical/myna
#   --build  : construit aussi les paquets (scripts/build.sh all)
#
# Codes retour : 0 tout va bien ; 3 un patch ne s'applique plus ; 4 la
# construction a échoué ; 1/2 erreur ou usage. Avec 3 ou 4, les fichiers sont
# quand même préparés et le rapport dit ce qui casse.
#
# Mainteneur des nouvelles entrées : celui de l'entrée précédente du changelog,
# sauf si DEBFULLNAME/DEBEMAIL sont définis.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
up="$root/upstream"
packages=(myna myna-whisper gnome-shell-extension-myna)
report="$root/build/update-report.md"
watched_diff="$root/build/update-watched.diff"
report_diff_lines=400   # lignes du diff des chemins surveillés reprises dans le rapport

die() { echo "$*" >&2; exit 1; }
usage() { echo "usage : $0 [--build] <ref>" >&2; exit 2; }

build=false
ref=
for a in "$@"; do
    case "$a" in
        --build) build=true ;;
        -*) usage ;;
        *) [ -z "$ref" ] || usage; ref="$a" ;;
    esac
done
[ -n "$ref" ] || usage
[ -e "$up/.git" ] || die "sous-module absent : git submodule update --init"
git -C "$root" diff --quiet && git -C "$root" diff --cached --quiet ||
    die "copie de travail modifiée : commiter ou mettre de côté d'abord"

# --- État actuel -----------------------------------------------------------
old_sha="$(git -C "$up" rev-parse HEAD)"
old_desc="$(git -C "$up" describe)"
old_date="$(git -C "$up" log -1 --format=%cs HEAD)"
old_deb="$(dpkg-parsechangelog -l "$root/packages/myna/debian/changelog" -S Version)"

git -C "$up" fetch -q --tags origin
new_sha="$(git -C "$up" rev-parse --verify --quiet "$ref^{commit}")" || die "ref inconnue dans l'amont : $ref"
[ "$new_sha" != "$old_sha" ] || die "l'amont est déjà sur $ref ($old_desc)"
descendant=true
git -C "$up" merge-base --is-ancestor "$old_sha" "$new_sha" || descendant=false

git -C "$up" checkout -q --detach "$new_sha"
new_desc="$(git -C "$up" describe)"
new_date="$(git -C "$up" log -1 --format=%cs HEAD)"
new_ver="$(bash "$up/dev/version.sh")"
case "$new_ver" in 0+git.*) die "tags de l'amont absents : git -C upstream fetch --tags --unshallow" ;; esac
new_deb="$new_ver+deb13~1"
old_short="$(git -C "$up" rev-parse --short=8 "$old_sha")"
new_short="$(git -C "$up" rev-parse --short=8 "$new_sha")"
echo "==> amont : $old_desc → $new_desc ($new_deb)"

# --- debian/changelog ------------------------------------------------------
maint="$(dpkg-parsechangelog -l "$root/packages/myna/debian/changelog" -S Maintainer)"
export DEBFULLNAME="${DEBFULLNAME:-${maint% <*}}"
export DEBEMAIL="${DEBEMAIL:-$(sed 's/.*<\(.*\)>.*/\1/' <<< "$maint")}"
for p in "${packages[@]}"; do
    dch --changelog "$root/packages/$p/debian/changelog" --check-dirname-level 0 \
        --newversion "$new_deb" --distribution trixie --force-distribution \
        "Nouvelle version amont $new_desc ($new_short)."
done

# --- README : sections « Pinned upstream » / « Amont épinglé » -------------
python3 -I - "$root" "$old_sha" "$new_sha" "$old_desc" "$new_desc" \
    "$old_date" "$new_date" "$old_deb" "$new_deb" <<'EOF'
import sys
root, old_sha, new_sha, old_desc, new_desc, old_date, new_date, old_deb, new_deb = sys.argv[1:]
fr = lambda d: "/".join(reversed(d.split("-")))
tag = lambda v: v.replace("~", "_")
for name, date in (("README.md", lambda d: d), ("README.fr.md", fr)):
    path = f"{root}/{name}"
    text = orig = open(path, encoding="utf-8").read()
    for a, b in ((f"`{old_sha}` ({date(old_date)})", f"`{new_sha}` ({date(new_date)})"),
                 (f"`{old_desc}`", f"`{new_desc}`"),
                 (f"`{old_deb}`", f"`{new_deb}`"),
                 (f"`debian/{tag(old_deb)}`", f"`debian/{tag(new_deb)}`")):
        if a not in text:
            print(f"{name} : « {a} » introuvable, à mettre à jour à la main", file=sys.stderr)
        text = text.replace(a, b)
    if text != orig:
        open(path, "w", encoding="utf-8").write(text)
EOF

# --- Notes de release ------------------------------------------------------
notes_dir="$root/packaging-notes"
old_notes="$notes_dir/release-${old_deb//\~/_}.md"
new_notes="$notes_dir/release-${new_deb//\~/_}.md"
if [ -f "$old_notes" ]; then
    # « v0.3.3-4-gea14d428 » s'écrit « v0.3.3-4 » dans les notes.
    sed -e "s/${old_deb//./\\.}/$new_deb/g" \
        -e "s/\`${old_short}\`/\`${new_short}\`/g" \
        -e "s/\`${old_desc%-g*}\`/\`${new_desc%-g*}\`/g" \
        "$old_notes" > "$new_notes"
else
    echo "notes précédentes absentes ($old_notes) : $new_notes non créé" >&2
fi

# --- Patches quilt ---------------------------------------------------------
mkdir -p "$root/build"
patch_status=0
patch_report=""
for p in "${packages[@]}"; do
    series="$root/packages/$p/debian/patches/series"
    [ -s "$series" ] || continue
    tmp="$(mktemp -d "$root/build/.patches.XXXXXX")"
    git -C "$up" archive HEAD | tar -x -C "$tmp"
    cp -a "$root/packages/$p/debian" "$tmp/debian"
    # Fuzz 0, comme dpkg-source : un patch qui ne s'applique qu'avec du flou
    # échouerait à la construction.
    if out="$(cd "$tmp" && QUILT_PATCHES=debian/patches quilt push -a --fuzz=0 2>&1)"; then
        patch_report+="- \`$p\` : ✅ $(grep -c . "$series") patch(es) appliqué(s)"$'\n'
        grep -q "offset" <<< "$out" && patch_report+="  (avec décalage de lignes, à rafraîchir un jour)"$'\n'
    else
        patch_status=3
        patch_report+="- \`$p\` : ❌ **échec**"$'\n\n''```'$'\n'"$out"$'\n''```'$'\n'
        echo "$p : un patch ne s'applique plus" >&2
    fi
    rm -rf "$tmp"
done

# --- Alertes ciblées -------------------------------------------------------
show() { git -C "$up" show "$1:$2" 2>/dev/null || true; }
lockver() {   # version d'un paquet Python dans server/uv.lock
    show "$1" server/uv.lock | awk -v n="name = \"$2\"" '$0 == n { getline; gsub(/version = |"/, ""); print; exit }'
}
changed() { ! git -C "$up" diff --quiet "$old_sha" "$new_sha" -- "$@"; }
alerts=""
alert() { alerts+="- ⚠️ $*"$'\n'; }

if changed client/rust-toolchain.toml; then
    alert "Toolchain Rust : $(show "$old_sha" client/rust-toolchain.toml | grep -m1 channel) → $(show "$new_sha" client/rust-toolchain.toml | grep -m1 channel) (rustup suit tout seul, vérifier que la CI passe)"
fi
rp_old="$(show "$old_sha" server/pyproject.toml | grep -m1 requires-python || true)"
rp_new="$(show "$new_sha" server/pyproject.toml | grep -m1 requires-python || true)"
[ "$rp_old" = "$rp_new" ] || alert "Python demandé : \`$rp_old\` → \`$rp_new\` (trixie : 3.13)"
for dep in ctranslate2 faster-whisper; do
    a="$(lockver "$old_sha" "$dep")"; b="$(lockver "$new_sha" "$dep")"
    [ "$a" = "$b" ] || alert "\`$dep\` : ${a:-absent} → ${b:-absent} (roues PyPI pour Python 3.13 ?)"
done
models_old="$(git -C "$up" ls-tree --name-only "$old_sha" whisper-snap/models/ | xargs -rn1 basename | sort)"
models_new="$(git -C "$up" ls-tree --name-only "$new_sha" whisper-snap/models/ | xargs -rn1 basename | sort)"
[ "$models_old" = "$models_new" ] || alert "Modèles Whisper : $(echo $models_old) → $(echo $models_new)"
changed whisper-snap/models/ && alert "\`whisper-snap/models/\` a changé (URL, \`MODEL_COMPUTE_TYPE\`…) : vérifier \`myna-whisper-fetch-model\` et le lanceur"
snaps_old="$(git -C "$up" ls-tree -d --name-only "$old_sha" | grep -- '-snap$' || true)"
snaps_new="$(git -C "$up" ls-tree -d --name-only "$new_sha" | grep -- '-snap$' || true)"
[ "$snaps_old" = "$snaps_new" ] || alert "Snaps de l'amont : $(echo $snaps_old) → $(echo $snaps_new) (nouveau moteur ? non empaqueté)"
changed myna-snap/snap/snapcraft.yaml whisper-snap/snap/snapcraft.yaml &&
    alert "La recette \`snapcraft.yaml\` de \`myna\` ou de \`myna-whisper\` a changé : relire l'environnement et les services (voir AUDIT.md)"
changed client/myna-orchestrator/src/backend/share.rs server/src/myna/server/provider_env.py &&
    alert "Le contrat moteur ↔ démon (\`provider.env\`, socket) a changé : tester une dictée"
$descendant || alert "La nouvelle ref ne descend pas de l'ancienne ($old_short) : retour en arrière ou historique réécrit"

# --- Chemins surveillés ----------------------------------------------------
mapfile -t watched < <(grep -v '^\s*\(#\|$\)' "$root/scripts/watched-paths")
git -C "$up" diff "$old_sha" "$new_sha" -- "${watched[@]}" > "$watched_diff"
watched_stat="$(git -C "$up" diff --stat=100 "$old_sha" "$new_sha" -- "${watched[@]}")"

# --- Construction facultative ----------------------------------------------
build_report="non lancée (\`--build\`)"
build_status=0
if $build; then
    if [ "$patch_status" -ne 0 ]; then
        build_report="sautée : patch cassé"
    elif "$root/scripts/build.sh" all; then
        build_report="✅ réussie (\`build/<paquet>/*.deb\`)"
    else
        build_status=4
        build_report="❌ échec, voir la sortie de \`scripts/build.sh all\`"
    fi
fi

# --- Rapport ---------------------------------------------------------------
release_notes=""
if [ "$new_desc" = "$(git -C "$up" describe --exact-match 2>/dev/null || true)" ]; then
    release_notes="$(curl -fsSL "https://api.github.com/repos/canonical/myna/releases/tags/$new_desc" 2>/dev/null |
        python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("body") or "")' 2>/dev/null || true)"
fi
commits="$(git -C "$up" log --oneline --no-merges "$old_sha..$new_sha" | head -n 200)"
diff_lines="$(wc -l < "$watched_diff")"

{
    echo "## Amont : \`$old_desc\` → \`$new_desc\`"
    echo
    echo "- Paquets : \`$old_deb\` → \`$new_deb\`"
    echo "- Commit : [\`$new_short\`](https://github.com/canonical/myna/commit/$new_sha) du $new_date"
    [ -n "$release_notes" ] && echo "- Release amont : <https://github.com/canonical/myna/releases/tag/$new_desc>"
    echo
    echo "### Alertes"
    echo
    if [ -n "$alerts" ]; then printf '%s' "$alerts"; else echo "Aucune."; fi
    echo
    echo "### Patches"
    echo
    if [ -n "$patch_report" ]; then printf '%s' "$patch_report"; else echo "Aucun."; fi
    echo
    echo "### Construction"
    echo
    echo "$build_report"
    echo
    echo "### Chemins surveillés (\`scripts/watched-paths\`)"
    echo
    if [ -s "$watched_diff" ]; then
        echo '```'
        echo "$watched_stat"
        echo '```'
        echo
        echo "<details><summary>Diff ($diff_lines lignes$([ "$diff_lines" -gt "$report_diff_lines" ] && echo ", tronqué à $report_diff_lines"))</summary>"
        echo
        echo '```diff'
        head -n "$report_diff_lines" "$watched_diff"
        echo '```'
        echo
        echo "</details>"
    else
        echo "Aucun changement."
    fi
    echo
    if [ -n "$release_notes" ]; then
        echo "<details><summary>Notes de la release amont</summary>"
        echo
        echo "$release_notes"
        echo
        echo "</details>"
        echo
    fi
    echo "<details><summary>Commits amont ($(grep -c . <<< "$commits"))</summary>"
    echo
    echo '```'
    echo "$commits"
    echo '```'
    echo
    echo "</details>"
    echo
    echo "### À faire avant de merger"
    echo
    echo "- [ ] relire les alertes et le diff des chemins surveillés"
    echo "- [ ] relire \`packaging-notes/release-${new_deb//\~/_}.md\`"
    echo "- [ ] après installation : une dictée, l'indicateur, \`myna-status\`"
} > "$report"

echo "==> rapport : $report"
echo "==> fichiers modifiés (non commités) :"
git -C "$root" status --short
exit $(( patch_status ? patch_status : build_status ))
