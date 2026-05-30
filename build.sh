#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="Release"
RID=""

if [ $# -gt 0 ]; then
  RID="$1"
fi

if [ $# -gt 1 ]; then
  CONFIGURATION="$2"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj"

if [ ! -f "$PROJECT_PATH" ]; then
  echo "Project file not found: $PROJECT_PATH" >&2
  exit 1
fi

if [ -z "$RID" ]; then
  if [ "$(uname -s)" = "Linux" ]; then
    RID="linux-x64"
  elif [ "$(uname -s)" = "Darwin" ]; then
    RID="osx-x64"
  else
    echo "Please provide a runtime identifier as the first argument." >&2
    exit 1
  fi
fi

DIST_FOLDER="$SCRIPT_DIR/dist/$RID"

rm -rf "$DIST_FOLDER"
mkdir -p "$DIST_FOLDER"

dotnet publish "$PROJECT_PATH" -c "$CONFIGURATION" -r "$RID" -p:SelfContained=false -o "$DIST_FOLDER"

echo "Publish complete. Output available in '$DIST_FOLDER'."
