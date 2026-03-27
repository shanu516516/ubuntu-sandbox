#!/bin/bash
set -e

CONTAINER="ubuntu-sandbox"

usage() {
  echo "Usage:"
  echo "  Copy IN:  $0 in  <host-path> <container-path>"
  echo "  Copy OUT: $0 out <container-path> <host-path>"
  exit 1
}

[ $# -lt 3 ] && usage

DIRECTION="$1"
SRC="$2"
DST="$3"

if [ "$DIRECTION" = "in" ]; then
  echo "Copying '$SRC' → container:'$DST'"
  read -p "Confirm? (y/N): " confirm
  [ "$confirm" = "y" ] || { echo "Cancelled."; exit 0; }
  docker cp "$SRC" "$CONTAINER:$DST"
  echo "Done."

elif [ "$DIRECTION" = "out" ]; then
  echo "⚠  WARNING: Copying files OUT of the sandbox to your host machine."
  echo "   Source: container:$SRC"
  echo "   Destination: $DST"
  echo ""
  echo "   Only do this if you trust the file."
  read -p "Type 'yes' to confirm: " confirm
  [ "$confirm" = "yes" ] || { echo "Cancelled."; exit 0; }
  docker cp "$CONTAINER:$SRC" "$DST"
  echo "Done."

else
  usage
fi
