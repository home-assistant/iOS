#!/bin/bash
# This script is needed to update MDI to latest and install it in such a way that it works with Iconic.
# Just run this script and it should handle everything.
# You do need enough of a Python environment setup to be able to pip install things.

cd Tools

# Ensure fonttools is installed
echo "Ensuring fonttools is installed via pip"
pip install fonttools

if [ ! -f fontname.py ]; then
  # Download the fontname script
  echo "Downloading the fontname script"
  curl -O --silent https://raw.githubusercontent.com/chrissimpkins/fontname.py/master/fontname.py
  echo "Downloaded the fontname script"
else
  echo "fontname.py is already downloaded"
fi

# Get the latest MDI TTF
echo "Downloading the latest MaterialDesignIcons TTF"
curl -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/master/fonts/materialdesignicons-webfont.ttf
echo "Downloaded the latest MaterialDesignIcons TTF"

# Rename file
echo "Renaming TTF from materialdesignicons-webfont.ttf to MaterialDesignIcons.ttf"
mv materialdesignicons-webfont.ttf MaterialDesignIcons.ttf

# Change font name to be MaterialDesignIcons so it works with Iconic.
echo "Changing font name to MaterialDesignIcons"
python fontname.py MaterialDesignIcons MaterialDesignIcons.ttf

echo "Successfully built MaterialDesignIcons.ttf"
