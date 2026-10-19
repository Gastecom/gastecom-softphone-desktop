#!/bin/bash
set -e

IDENTITY="$1"
APP="$2"
ENTITLEMENTS="$3"
EXE="$4"

SIGN=(codesign --force --timestamp --options runtime,library -s "$IDENTITY")

find "$APP" \( -name "*.dylib" -o -name "*.so" \) -exec "${SIGN[@]}" {} \;
find "$APP/Contents/Frameworks" -maxdepth 1 -name "*.framework" -exec "${SIGN[@]}" {} \;

for f in "$APP/Contents/MacOS/"*; do
	if [ -f "$f" ]; then
		"${SIGN[@]}" "$f"
	fi
done

"${SIGN[@]}" --entitlements "$ENTITLEMENTS" "$APP/Contents/MacOS/$EXE"
"${SIGN[@]}" --entitlements "$ENTITLEMENTS" "$APP"
