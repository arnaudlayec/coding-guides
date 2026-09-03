#!/usr/bin/env python3
"""
Vérification d'une sauvegarde de photos iPhone -> Ubuntu, puis nettoyage des
.mov redondants (Live Photos) quand le .jpeg correspondant existe déjà.

Usage:
    python3 check_and_dedupe_iphone_backup.py scan
    python3 check_and_dedupe_iphone_backup.py hash-check --sample 30
    python3 check_and_dedupe_iphone_backup.py dedupe --dry-run
    python3 check_and_dedupe_iphone_backup.py dedupe --apply
    python3 check_and_dedupe_iphone_backup.py all --sample 30 --dry-run

Notes importantes :
- La comparaison de hash n'a de sens QUE si le fichier a exactement la même
  extension des deux côtés (ex: .MOV <-> .mov, .JPG <-> .jpg). Si ton outil
  de sauvegarde a converti du HEIC (iPhone) vers du JPEG (Ubuntu), les octets
  seront différents même si l'image est identique visuellement : dans ce cas
  le hash NE PEUT PAS matcher, ce n'est pas une anomalie. Le script ne
  compare donc que les paires où l'extension est identique des deux côtés
  (typiquement les .MOV, et les .JPG des photos plus anciennes déjà en JPEG
  sur l'iPhone).
- La vérification de "complétude" se fait par nom de fichier sans extension
  (le "stem"), pour être robuste aux conversions HEIC->JPEG.
"""

import argparse
import glob
import hashlib
import os
import random
import sys
from collections import defaultdict

BACKUP_ROOT = "/home/arnaud/Pictures/iPhone"
IPHONE_GPHOTO_URI = "gphoto2://Apple_Inc._iPhone_00008110000131E83C83401E/"

IMAGE_EXTS = {".jpg", ".jpeg", ".heic", ".png"}
VIDEO_EXTS = {".mov", ".mp4"}


def find_iphone_mount():
    """Retrouve le point de montage GVFS correspondant à l'URI gphoto2 donné.
    Sous Nautilus/GVFS, un chemin gphoto2://HOST/ est monté sous
    /run/user/<uid>/gvfs/gphoto2:host=HOST/
    """
    host = IPHONE_GPHOTO_URI.replace("gphoto2://", "").rstrip("/")
    uid = os.getuid()
    pattern = f"/run/user/{uid}/gvfs/gphoto2:host={host}*"
    matches = glob.glob(pattern)
    if not matches:
        # essai plus permissif, au cas où le nom d'hôte serait légèrement différent
        pattern2 = f"/run/user/{uid}/gvfs/gphoto2:host=*iPhone*"
        matches = glob.glob(pattern2)
    if not matches:
        print(f"[!] Impossible de trouver le montage GVFS pour {IPHONE_GPHOTO_URI}")
        print(f"    Vérifie que l'iPhone est monté (ouvre-le une fois dans Nautilus)")
        print(f"    puis regarde le contenu de /run/user/{uid}/gvfs/")
        sys.exit(1)
    return matches[0]


def index_tree(root):
    """Parcourt récursivement un répertoire et retourne un index :
    stem_upper -> liste de dicts {path, size, ext}
    """
    index = defaultdict(list)
    total_files = 0
    for dirpath, dirnames, filenames in os.walk(root):
        for name in filenames:
            full_path = os.path.join(dirpath, name)
            stem, ext = os.path.splitext(name)
            ext = ext.lower()
            try:
                size = os.path.getsize(full_path)
            except OSError as e:
                print(f"[!] Impossible de lire la taille de {full_path}: {e}")
                continue
            index[stem.upper()].append({"path": full_path, "size": size, "ext": ext})
            total_files += 1
    return index, total_files


def cmd_scan(args):
    print("== Scan de l'iPhone ==")
    iphone_mount = find_iphone_mount()
    print(f"Point de montage détecté : {iphone_mount}")
    iphone_index, iphone_total = index_tree(iphone_mount)
    print(f"{iphone_total} fichiers trouvés sur l'iPhone.")

    print("\n== Scan de la sauvegarde Ubuntu ==")
    backup_index, backup_total = index_tree(BACKUP_ROOT)
    print(f"{backup_total} fichiers trouvés dans {BACKUP_ROOT}.")

    print("\n== Vérification de complétude (par nom sans extension) ==")
    missing = []
    for stem, entries in iphone_index.items():
        if stem not in backup_index:
            missing.append(entries)
        else:
            n_iphone = len(entries)
            n_backup = len(backup_index[stem])
            if n_backup < n_iphone:
                missing.append(entries)

    if not missing:
        print("OK : chaque fichier de l'iPhone semble avoir une contrepartie dans la sauvegarde.")
    else:
        print(f"/!\\ {len(missing)} fichier(s)/groupe(s) de l'iPhone semblent absents de la sauvegarde :")
        for entries in missing:
            for e in entries:
                print(f"   - {e['path']} ({e['size']} octets)")

    print("\nRésumé :")
    print(f"  Fichiers iPhone : {iphone_total}")
    print(f"  Fichiers backup : {backup_total}")
    print(f"  Groupes potentiellement manquants : {len(missing)}")
    print("\nCe scan est indicatif : la comparaison se fait par nom de fichier,")
    print("pas par contenu. Utilise 'hash-check' pour vérifier l'intégrité binaire")
    print("des fichiers dont l'extension n'a pas changé entre l'iPhone et Ubuntu.")


def build_exact_match_pairs(iphone_index, backup_index):
    """Retourne les paires (iphone_entry, backup_entry) où le nom de fichier
    ET l'extension sont identiques des deux côtés (donc comparaison de hash
    valide)."""
    pairs = []
    for stem, iphone_entries in iphone_index.items():
        backup_entries = backup_index.get(stem, [])
        for ie in iphone_entries:
            for be in backup_entries:
                if ie["ext"] == be["ext"]:
                    pairs.append((ie, be))
    return pairs


def sha256_of(path, chunk_size=1024 * 1024):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def cmd_hash_check(args):
    iphone_mount = find_iphone_mount()
    print(f"Point de montage iPhone : {iphone_mount}")
    iphone_index, _ = index_tree(iphone_mount)
    backup_index, _ = index_tree(BACKUP_ROOT)

    pairs = build_exact_match_pairs(iphone_index, backup_index)
    print(f"{len(pairs)} paire(s) avec extension identique des deux côtés (comparaison de hash possible).")
    if not pairs:
        print("Aucune paire comparable trouvée (probablement parce que tout a été")
        print("converti HEIC->JPEG). Rien à comparer par hash dans ce cas.")
        return

    sample_size = min(args.sample, len(pairs))
    sample = random.sample(pairs, sample_size)
    print(f"Vérification d'un échantillon aléatoire de {sample_size} fichier(s)...\n")

    mismatches = []
    for ie, be in sample:
        if ie["size"] != be["size"]:
            mismatches.append((ie, be, "taille différente"))
            print(f"[MISMATCH taille] {ie['path']} vs {be['path']}")
            continue
        try:
            h1 = sha256_of(ie["path"])
        except OSError as e:
            print(f"[!] Erreur de lecture iPhone {ie['path']}: {e}")
            continue
        h2 = sha256_of(be["path"])
        if h1 != h2:
            mismatches.append((ie, be, "hash différent"))
            print(f"[MISMATCH hash] {ie['path']} vs {be['path']}")
        else:
            print(f"[OK] {os.path.basename(be['path'])}")

    print(f"\nRésultat : {sample_size - len(mismatches)}/{sample_size} identiques.")
    if mismatches:
        print(f"/!\\ {len(mismatches)} anomalie(s) détectée(s), voir ci-dessus.")
    else:
        print("Aucune anomalie détectée sur l'échantillon testé.")


def cmd_dedupe(args):
    print(f"== Recherche des .mov redondants dans {find_iphone_mount()} ==")
    backup_index, _ = index_tree(find_iphone_mount())

    to_delete = []
    for stem, entries in backup_index.items():
        images = [e for e in entries if e["ext"] in IMAGE_EXTS]
        videos = [e for e in entries if e["ext"] in VIDEO_EXTS]
        if images and videos:
            to_delete.extend(videos)

    if not to_delete:
        print("Aucun .mov/.mp4 avec un .jpeg correspondant trouvé.")
        return

    total_size = sum(e["size"] for e in to_delete)
    print(f"{len(to_delete)} fichier(s) vidéo à supprimer (photo correspondante conservée).")
    print(f"Espace récupérable : {total_size / (1024**3):.2f} Go\n")

    for e in to_delete:
        print(f"  {'[SUPPRIMÉ]' if args.apply else '[À supprimer]'} {e['path']} ({e['size']/1e6:.1f} Mo)")

    if not args.apply:
        print("\nMode dry-run (par défaut) : rien n'a été supprimé.")
        print("Relance avec --apply pour supprimer réellement ces fichiers.")
        return

    print("\nSuppression en cours...")
    errors = 0
    for e in to_delete:
        try:
            os.remove(e["path"])
        except OSError as ex:
            errors += 1
            print(f"[!] Erreur en supprimant {e['path']}: {ex}")
    print(f"Terminé. {len(to_delete) - errors}/{len(to_delete)} fichiers supprimés.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("scan", help="Compare les fichiers iPhone vs sauvegarde Ubuntu (par nom)")

    p_hash = sub.add_parser("hash-check", help="Compare des hash sur un échantillon de fichiers identiques (même extension)")
    p_hash.add_argument("--sample", type=int, default=20, help="Nombre de fichiers à vérifier (défaut: 20)")

    p_dedupe = sub.add_parser("dedupe", help="Supprime les .mov quand un .jpeg correspondant existe")
    group = p_dedupe.add_mutually_exclusive_group()
    group.add_argument("--dry-run", dest="apply", action="store_false", help="Simulation seulement (défaut)")
    group.add_argument("--apply", dest="apply", action="store_true", help="Supprime réellement les fichiers")
    p_dedupe.set_defaults(apply=False)

    p_all = sub.add_parser("all", help="Enchaîne scan + hash-check + dedupe (dry-run par défaut)")
    p_all.add_argument("--sample", type=int, default=20)
    group2 = p_all.add_mutually_exclusive_group()
    group2.add_argument("--dry-run", dest="apply", action="store_false")
    group2.add_argument("--apply", dest="apply", action="store_true")
    p_all.set_defaults(apply=False)

    args = parser.parse_args()

    if args.command == "scan":
        cmd_scan(args)
    elif args.command == "hash-check":
        cmd_hash_check(args)
    elif args.command == "dedupe":
        cmd_dedupe(args)
    elif args.command == "all":
        cmd_scan(args)
        print("\n" + "=" * 60 + "\n")
        cmd_hash_check(args)
        print("\n" + "=" * 60 + "\n")
        cmd_dedupe(args)


if __name__ == "__main__":
    main()
