#!/bin/bash
# This script is needed to update MDI to latest and install it in such a way that it works with Iconic.
# Just run this script and it should handle everything.
# You do need enough of a Python environment setup to be able to pip install things.

pushd `dirname $0` >/dev/null

# updating this also requires updating MaterialDesignIcons.swift if SwiftGen hasn't been updated to generate it yet
MDI_COMMIT=57a8b3a30c24637bbfaec1485e7f045556e98f8c
MDI_VERSION=5.5.55

if [[ -f MaterialDesignIcons.ttf && -f MaterialDesignIcons-$MDI_VERSION.ttf ]]; then
	echo "MaterialDesignIcons up to date"
	exit
fi

# Ensure fonttools is installed
echo "Ensuring fonttools is installed via pip"
pip3 install --user fonttools

if [ ! -f fontname.py ]; then
  # Download the fontname script
  echo "Downloading the fontname script"
  curl -O --silent https://raw.githubusercontent.com/chrissimpkins/fontname.py/master/fontname.py
  echo "Downloaded the fontname script"
else
  echo "fontname.py is already downloaded"
fi

echo "Downloading the latest MaterialDesignIcons TTF"
curl -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/$MDI_COMMIT/fonts/materialdesignicons-webfont.ttf
echo "Downloaded the latest MaterialDesignIcons TTF"

# Rename file
echo "Renaming TTF from materialdesignicons-webfont.ttf to MaterialDesignIcons.ttf"
mv materialdesignicons-webfont.ttf MaterialDesignIcons-$MDI_VERSION.ttf

# Change font name to be MaterialDesignIcons so it works with Iconic.
echo "Changing font name to MaterialDesignIcons"
python3 fontname.py MaterialDesignIcons MaterialDesignIcons-$MDI_VERSION.ttf

echo "Successfully built MaterialDesignIcons.ttf"
ln MaterialDesignIcons-$MDI_VERSION.ttf MaterialDesignIcons.ttf

popd
