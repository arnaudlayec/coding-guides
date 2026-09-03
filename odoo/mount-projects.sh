#!/usr/bin/env bash
set -euo pipefail

# Usage: ./mount-projects.sh <version>
# Ex:    ./mount-projects.sh 18.0

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>  (ex: 16.0, 18.0, 19.0)" >&2
  exit 1
fi

# Dossier racine contenant __src__ et tous les dossiers projets, par version
ROOT="/home/arnaud/dev/odoo/$VERSION"

case "$VERSION" in
  16.0)
    PROJECTS=("aluval-dockyfied" "apileau")
    ;;
  18.0)
    PROJECTS=("aiguebelle" "envie" "flavigny" "goldservice" "demo")
    ;;
  19.0)
    PROJECTS=("training")
    ;;
  *)
    echo "⚠️  Version '$VERSION' inconnue, pas de liste de projets définie." >&2
    exit 1
    ;;
esac

SRC_DIR="$ROOT/__src__"
SUBDIRS=("src" "external-src")

for project in "${PROJECTS[@]}"; do
  project_odoo_dir="$ROOT/$project/odoo"

  if [ ! -d "$project_odoo_dir" ]; then
    echo "⚠️  $project_odoo_dir n'existe pas, on saute."
    continue
  fi

  for sub in "${SUBDIRS[@]}"; do
    src="$SRC_DIR/$sub"
    target="$project_odoo_dir/$sub"

    if [ ! -d "$src" ]; then
      echo "⚠️  Source manquante : $src, on saute."
      continue
    fi

    # Si déjà monté, ne rien refaire
    if mountpoint -q "$target" 2>/dev/null; then
      echo "✓ $target déjà monté."
      continue
    fi

    # Si c'est un symlink, on le retire pour le remplacer par un vrai dossier
    if [ -L "$target" ]; then
      echo "→ Suppression du symlink $target"
      rm "$target"
    fi

    mkdir -p "$target"
    mount --bind "$src" "$target"
    echo "✓ Monté $src -> $target"
  done
done

echo "Terminé."
