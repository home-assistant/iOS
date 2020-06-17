#!/bin/bash
# This script is needed to update MDI to latest and install it in such a way that it works with Iconic.
# Just run this script and it should handle everything.
# You do need enough of a Python environment setup to be able to pip install things.

pushd `dirname $0`

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

# Get the MDI TTF
# versions >=5.0 do not work with the version of SwiftGen in Iconic
# for a version that works with Iconic, replace master with c8ed1f706deb089e05cb46655a786210991f1e92
# this will migrate to a newer Iconic after https://github.com/SwiftGen/SwiftGen/pull/638
echo "Downloading the latest MaterialDesignIcons TTF"
curl -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/master/fonts/materialdesignicons-webfont.ttf
echo "Downloaded the latest MaterialDesignIcons TTF"

# Rename file
echo "Renaming TTF from materialdesignicons-webfont.ttf to MaterialDesignIcons.ttf"
mv materialdesignicons-webfont.ttf MaterialDesignIcons.ttf

# Change font name to be MaterialDesignIcons so it works with Iconic.
echo "Changing font name to MaterialDesignIcons"
python3 fontname.py MaterialDesignIcons MaterialDesignIcons.ttf

echo "Successfully built MaterialDesignIcons.ttf"

popd
