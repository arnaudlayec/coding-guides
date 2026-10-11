#!/usr/bin/env bash
set -euo pipefail

# Usage: ./mount-projects.sh [version]
# Ex:    ./mount-projects.sh        # toutes les versions
#        ./mount-projects.sh 18.0   # une seule version

# Projets par version (séparés par des espaces)
declare -A PROJECTS_BY_VERSION=(
  [16.0]="aluval apileau"
  [17.0]="ibjb"
  [18.0]="aiguebelle envie flavigny goldservice demo dilicom ibjb"
  [19.0]="training"
)

SUBDIRS=("src" "external-src")

mount_version() {
  local version="$1"
  # Dossier racine contenant __src__ et tous les dossiers projets, par version
  local root="/home/arnaud/dev/odoo/$version"
  local src_dir="$root/__src__"
  local projects

  if [ -z "${PROJECTS_BY_VERSION[$version]+x}" ]; then
    echo "⚠️  Version '$version' inconnue, pas de liste de projets définie." >&2
    return 1
  fi
  read -ra projects <<< "${PROJECTS_BY_VERSION[$version]}"

  echo "=== $version ==="
  for project in "${projects[@]}"; do
    local project_odoo_dir="$root/$project/odoo"

    if [ ! -d "$project_odoo_dir" ]; then
      echo "⚠️  $project_odoo_dir n'existe pas, on saute."
      continue
    fi

    for sub in "${SUBDIRS[@]}"; do
      local src="$src_dir/$sub"
      local target="$project_odoo_dir/$sub"

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
}

if [ $# -gt 0 ]; then
  mount_version "$1"
else
  for version in $(printf '%s\n' "${!PROJECTS_BY_VERSION[@]}" | sort -V); do
    mount_version "$version"
  done
fi

echo "Terminé."
