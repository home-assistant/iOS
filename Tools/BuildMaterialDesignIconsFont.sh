#!/bin/bash
# This script is needed to update MDI to latest and install it in such a way that it works with Iconic.
# Just run this script and it should handle everything.
# You do need enough of a Python environment setup to be able to pip install things.

set -euo pipefail

pushd `dirname $0` >/dev/null

# helper tool
FONT_RENAME_COMMIT=77734a1a165d25c8c83b2201c15e268da4a107b6

# updating this requires re-executing swiftgen to pick up the new names
# failing to keep the MDI and SVG versions in-sync will produce problems, as we use the SVG's JSON for codepoints
MDI_COMMIT=6b7bfd3c201c1185129e819e02dc2505dbb82994
SVG_COMMIT=e0f630048de499e2ed938b6374efffc7f752ce81
MDI_VERSION=7.0.96

echo "Checking for latest..."

LATEST=$(curl --silent https://api.github.com/repos/Templarian/MaterialDesign-Webfont/tags | sed -n -e 's/.*"name": "v\([^"]*\)".*/\1/p' | head -1)
echo "Latest available: $LATEST; latest supported: $MDI_VERSION"

if [[ 
		-f MaterialDesignIcons.ttf && \
		-f MaterialDesignIcons-$MDI_VERSION.ttf && \
		-f MaterialDesignIcons.json && \
		-f MaterialDesignIcons-$MDI_VERSION.json ]]; then
	if [ $LATEST != $MDI_VERSION ]; then
		echo "Out of date, but latest supported installed"
	else
		echo "Up-to-date"
	fi
	exit
fi

echo "Ensuring fonttools is installed via pip..."
pip3 install --user fonttools

if [ ! -f fontname-$FONT_RENAME_COMMIT.py ]; then
  echo "Downloading the fontname script..."
  curl -O --silent https://raw.githubusercontent.com/chrissimpkins/fontname.py/77734a1a165d25c8c83b2201c15e268da4a107b6/fontname.py >fontname-$FONT_RENAME_COMMIT.py
else
  echo "fontname.py is already downloaded"
fi

echo "Downloading the latest MaterialDesignIcons TTF..."
curl -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/$MDI_COMMIT/fonts/materialdesignicons-webfont.ttf

echo "Downloading the latest MaterialDesignIcons JSON..."
curl -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-SVG/$SVG_COMMIT/meta.json

echo "Renaming raw files..."
mv materialdesignicons-webfont.ttf MaterialDesignIcons-$MDI_VERSION.ttf
mv meta.json MaterialDesignIcons-$MDI_VERSION.json

echo "Changing font name..."
python3 fontname-$FONT_RENAME_COMMIT.py MaterialDesignIcons MaterialDesignIcons-$MDI_VERSION.ttf

echo "Creating links..."
ln -f MaterialDesignIcons-$MDI_VERSION.ttf MaterialDesignIcons.ttf
ln -f MaterialDesignIcons-$MDI_VERSION.json MaterialDesignIcons.json

echo "Successfully built MaterialDesignIcons at version $MDI_VERSION"
echo "Running Swiftgen..."

pushd ..
Pods/SwiftGen/bin/swiftgen
popd

popd
