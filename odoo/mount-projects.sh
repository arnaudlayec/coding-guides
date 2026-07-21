#!/usr/bin/env bash
set -euo pipefail

# Dossier racine contenant __src__ et tous les dossiers projets
ROOT="/home/arnaud/dev/odoo/18.0"

SRC_DIR="$ROOT/__src__"
PROJECTS=("aiguebelle" "envie" "flavigny" "goldservice" "demo")
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
