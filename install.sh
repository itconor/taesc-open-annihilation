#!/usr/bin/env bash
# Installs TA: Escalation (TAESC) as an Open Annihilation mod, on macOS and Linux.
#
# Put the TAESC download (TAESC_GOLD_10_2_0_FULL.rar from
# https://taesc.tauniverse.com) in the same folder as this script and run it.
# It unpacks TAESC's own archives, adds this repository's oamod.yaml, and puts
# the result in Open Annihilation's Mods folder. Without a download beside it,
# it looks for TAESC installed in CrossOver, Wine, Bottles or Lutris. It never
# deletes anything: a mod already installed under the same name is moved to a
# backup first.
#
#   ./install.sh                       use the TAESC download beside this script
#   ./install.sh --source PATH         PATH is a TAESC .rar/.zip/.7z or a TAESC folder
#   ./install.sh --package taesc.oamod build a .oamod package instead of installing
#   ./install.sh --mods-dir DIR        install into DIR instead of the usual Mods folder
#   ./install.sh --help
set -euo pipefail

TESTED_VERSION="10.2.0"
MOD_ID="taesc"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="$HERE/mod/oamod.yaml"

SOURCE=""
MODS_DIR=""
PACKAGE=""

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --source)   SOURCE="${2:?--source needs a path}"; shift 2 ;;
    --mods-dir) MODS_DIR="${2:?--mods-dir needs a path}"; shift 2 ;;
    --package)  PACKAGE="${2:?--package needs a file name}"; shift 2 ;;
    -h|--help)  usage ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

[ -f "$PROFILE" ] || die "mod/oamod.yaml is missing next to this script"

# ---------------------------------------------------------------- where things are
OS="$(uname -s)"

documents_dir() {
  if [ "$OS" = "Linux" ] && command -v xdg-user-dir >/dev/null 2>&1; then
    local d; d="$(xdg-user-dir DOCUMENTS 2>/dev/null || true)"
    if [ -n "$d" ] && [ "$d" != "$HOME" ]; then printf '%s' "$d"; return; fi
  fi
  printf '%s' "$HOME/Documents"
}

oa_binary() {
  local c
  for c in \
    "/Applications/Open Annihilation.app/Contents/MacOS/open-annihilation" \
    "$HOME/Applications/Open Annihilation.app/Contents/MacOS/open-annihilation" \
    "$(command -v open-annihilation 2>/dev/null || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then printf '%s' "$c"; return; fi
  done
}

# Folders a TAESC install is usually found under.
search_roots() {
  local r
  for r in \
    "$HOME/Library/Application Support/CrossOver/Bottles" \
    "$HOME/.wine/drive_c" \
    "$HOME/Games" \
    "$HOME/.local/share/bottles/bottles" \
    "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles" \
    "$HOME/.local/share/lutris" \
    "$HOME/.steam/steam/steamapps/compatdata"; do
    [ -d "$r" ] && printf '%s\n' "$r"
  done
}

# Prints the folder that holds TAESC.gp3 under $1 (any case), or nothing.
find_taesc_in() {
  find "$1" -maxdepth 7 -type f -iname 'taesc.gp3' 2>/dev/null | head -n 1 | while read -r f; do dirname "$f"; done
}

# Unpacks archive $1 into folder $2 with whatever tool this machine has.
unpack() {
  local src="$1" dst="$2" lower
  lower="$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *.zip)
      if command -v unzip >/dev/null 2>&1 && unzip -q "$src" -d "$dst"; then return 0; fi ;;
    *.rar)
      if command -v unrar >/dev/null 2>&1 && unrar x -idq -o+ "$src" "$dst/" >/dev/null; then return 0; fi ;;
  esac
  if command -v bsdtar >/dev/null 2>&1 && bsdtar -xf "$src" -C "$dst" 2>/dev/null; then return 0; fi
  if command -v 7zz >/dev/null 2>&1 && 7zz x -y -o"$dst" "$src" >/dev/null; then return 0; fi
  if command -v 7z  >/dev/null 2>&1 && 7z  x -y -o"$dst" "$src" >/dev/null; then return 0; fi
  case "$lower" in
    *.rar) die "cannot unpack $src: this machine has no tool that reads RAR files. Install one (macOS: brew install libarchive; Debian/Ubuntu: sudo apt install libarchive-tools; Fedora: sudo dnf install bsdtar) or unpack it yourself and run: $0 --source /path/to/unpacked/folder" ;;
    *) die "cannot unpack $src" ;;
  esac
}

# A TAESC download (.rar, .zip or .7z with "taesc" in its name) in this
# script's folder, the newest by name, or nothing.
archive_beside_script() {
  find "$HERE" -maxdepth 1 -type f \( -iname '*taesc*.rar' -o -iname '*taesc*.zip' -o -iname '*taesc*.7z' \) 2>/dev/null | sort | tail -n 1
}

# ---------------------------------------------------------------- find TAESC
TAESC_DIR=""
if [ -z "$SOURCE" ]; then
  SOURCE="$(archive_beside_script)"
  [ -n "$SOURCE" ] && say "Found the TAESC download: $(basename "$SOURCE")"
fi
if [ -n "$SOURCE" ]; then
  [ -e "$SOURCE" ] || die "$SOURCE does not exist"
  if [ -d "$SOURCE" ]; then
    TAESC_DIR="$(find_taesc_in "$SOURCE")"
    [ -n "$TAESC_DIR" ] || die "no TAESC.gp3 under $SOURCE; is this a TAESC install?"
  else
    case "$(printf '%s' "$SOURCE" | tr '[:upper:]' '[:lower:]')" in
      *.exe) die "$SOURCE is a Windows installer. Run it (on Windows, or in CrossOver/Wine), then run this script again; it will find the installed copy." ;;
    esac
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/taesc-unpack.XXXXXX")"
    say "Unpacking it (about a minute) ..."
    unpack "$SOURCE" "$WORK"
    TAESC_DIR="$(find_taesc_in "$WORK")"
    [ -n "$TAESC_DIR" ] || die "no TAESC.gp3 in $SOURCE; is it the TAESC download?"
  fi
else
  say "No TAESC download beside this script; looking for an installed TAESC ..."
  while read -r root; do
    [ -n "$root" ] || continue
    TAESC_DIR="$(find_taesc_in "$root")"
    [ -n "$TAESC_DIR" ] && break
  done <<EOF
$(search_roots)
EOF
  if [ -z "$TAESC_DIR" ]; then
    say ""
    say "TAESC was not found."
    say ""
    say "  1. Download TAESC GOLD $TESTED_VERSION (TAESC_GOLD_10_2_0_FULL.rar) from https://taesc.tauniverse.com"
    say "  2. Put the file in this folder: $HERE"
    say "  3. Run this script again."
    exit 1
  fi
fi
say "TAESC found in: $TAESC_DIR"

# ---------------------------------------------------------------- version check
VERSION=""
for f in "$TAESC_DIR"/GOLD_*.txt "$TAESC_DIR"/gold_*.txt; do
  [ -f "$f" ] || continue
  VERSION="$(basename "$f" | sed -E 's/^[Gg][Oo][Ll][Dd]_([0-9]+)_([0-9]+)_([0-9]+)\..*/\1.\2.\3/')"
  break
done
if [ -z "$VERSION" ]; then
  INI="$(find "$TAESC_DIR" -maxdepth 1 -iname 'taesc.ini' | head -n 1)"
  [ -n "$INI" ] && VERSION="$(head -n 3 "$INI" | grep -oE 'v[0-9]+(\.[0-9]+)+' | head -n 1 | tr -d v || true)"
fi
if [ "$VERSION" = "$TESTED_VERSION" ]; then
  say "TAESC version: $VERSION"
else
  warn "this profile was made for TAESC $TESTED_VERSION; this install is ${VERSION:-of an unknown version}. It is installed anyway, but check it plays as it should."
fi

# ---------------------------------------------------------------- stage the mod
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/taesc-mod.XXXXXX")/$MOD_ID"
mkdir -p "$STAGE"

copy_one() {  # copy_one PATTERN -> copies every top-level file matching PATTERN (any case)
  local n=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    cp -p "$f" "$STAGE/"
    n=$((n + 1))
  done <<EOF
$(find "$TAESC_DIR" -maxdepth 1 -type f -iname "$1" | sort)
EOF
  printf '%s' "$n"
}

say "Copying TAESC's files ..."
[ "$(copy_one 'taesc.gp3')" = "1" ] || die "TAESC.gp3 could not be copied"
UFOS="$(copy_one '*esc*.ufo')"
[ "$UFOS" -ge 1 ] || die "no TAESC .ufo archives (T2ESC.ufo ...) next to TAESC.gp3"
copy_one 'tademo.ufo' >/dev/null
copy_one 'taesc.ini'  >/dev/null
copy_one 'gold_*.txt' >/dev/null
for d in Icon Music; do
  src="$(find "$TAESC_DIR" -maxdepth 1 -type d -iname "$d" | head -n 1)"
  if [ -n "$src" ]; then
    dst="$STAGE/$(printf '%s' "$d" | tr '[:upper:]' '[:lower:]')"
    [ "$d" = "Icon" ] && dst="$STAGE/Icon"
    cp -Rp "$src" "$dst"
  fi
done
cp "$PROFILE" "$STAGE/oamod.yaml"
say "  TAESC.gp3, $UFOS TAESC archives, TAESC.ini, Icon and music"

# ---------------------------------------------------------------- check with the engine
OA="$(oa_binary || true)"
if [ -n "$OA" ]; then
  if out="$("$OA" --print-profile --mod-dir "$STAGE" 2>&1)"; then
    say "Open Annihilation accepts the profile ($(printf '%s\n' "$out" | grep -m1 '^sha256-sim' || true))"
  else
    printf '%s\n' "$out" >&2
    die "Open Annihilation refused the profile (above)"
  fi
else
  warn "Open Annihilation not found, so the profile was not checked; it is checked when the game starts"
fi

# ---------------------------------------------------------------- package or install
if [ -n "$PACKAGE" ]; then
  case "$PACKAGE" in *.oamod) ;; *) PACKAGE="$PACKAGE.oamod" ;; esac
  case "$PACKAGE" in /*) ;; *) PACKAGE="$PWD/$PACKAGE" ;; esac
  [ -e "$PACKAGE" ] && die "$PACKAGE already exists; pick another name"
  command -v zip >/dev/null 2>&1 || die "zip is needed to build a package"
  ( cd "$(dirname "$STAGE")" && zip -q -r -X "$PACKAGE" "$MOD_ID" )
  say ""
  say "Built $PACKAGE"
  say "Open it with Open Annihilation (double-click it, or drag it onto the game's window) to install it."
  exit 0
fi

[ -n "$MODS_DIR" ] || MODS_DIR="$(documents_dir)/Open Annihilation/Mods"
mkdir -p "$MODS_DIR"
DEST="$MODS_DIR/$MOD_ID"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  # Backups go beside the Mods folder, not in it: the Library lists every
  # folder in Mods, and a backup there would show up as a second TAESC.
  BACKUPS="$(dirname "$MODS_DIR")/Mod backups"
  mkdir -p "$BACKUPS"
  BACKUP="$BACKUPS/$MOD_ID-$(date +%Y%m%d-%H%M%S)"
  mv "$DEST" "$BACKUP"
  say "An earlier copy was moved to $BACKUP (delete it yourself once you are happy)"
fi
mv "$STAGE" "$DEST"

say ""
say "Installed TA: Escalation in $DEST"
say ""
say "To play: open Open Annihilation, press OA on the main menu, choose TA: Escalation and"
say "press Play now. Core Contingency and Battle Tactics must be switched on: TAESC uses both."
