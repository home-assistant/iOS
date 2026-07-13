#!/bin/bash
# This script updates MDI and installs it in such a way that it works with Iconic.
# Run with no arguments to (re)generate the currently pinned version.
# Run with --bump to update the pins below to the latest MaterialDesignIcons release
# and regenerate. This is what the weekly workflow uses.
# You do need enough of a Python environment setup to be able to pip install things.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SELF="$DIR/$(basename "$0")"

pushd "$DIR" >/dev/null

# helper tool
FONT_RENAME_COMMIT=77734a1a165d25c8c83b2201c15e268da4a107b6

# updating this requires re-executing swiftgen to pick up the new names
# failing to keep the MDI and SVG versions in-sync will produce problems, as we use the SVG's JSON for codepoints
MDI_COMMIT=081279cbda3e72e34a2c2a445a4a92dffa1e0314
SVG_COMMIT=d022f3ecd4bf33d588b145dd59bb11eac7a23c46
MDI_VERSION=7.1.96

BUMP=0
if [ "${1:-}" = "--bump" ]; then
	BUMP=1
fi

# Query the GitHub API, authenticating with GITHUB_TOKEN when it is available.
# Unauthenticated requests share a 60/hour per-IP limit that CI runners routinely
# exhaust, which returns an error body that parses to an empty result.
gh_api() {
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl --silent -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
	else
		curl --silent "$@"
	fi
}

echo "Checking for latest..."

LATEST=$(gh_api https://api.github.com/repos/Templarian/MaterialDesign-Webfont/tags | sed -n -e 's/.*"name": "v\([^"]*\)".*/\1/p' | head -1)
echo "Latest available: $LATEST; currently pinned: $MDI_VERSION"

if [ "$BUMP" -eq 1 ]; then
	if [ -z "$LATEST" ]; then
		echo "Could not determine the latest version; aborting."
		exit 1
	fi
	if [ "$LATEST" = "$MDI_VERSION" ]; then
		echo "Already on the latest version; nothing to do."
		exit 0
	fi

	echo "Resolving commit for MaterialDesign-Webfont v$LATEST..."
	MDI_COMMIT=$(gh_api https://api.github.com/repos/Templarian/MaterialDesign-Webfont/commits/v$LATEST | sed -n -e 's/.*"sha": *"\([^"]*\)".*/\1/p' | head -1)

	echo "Resolving commit for MaterialDesign-SVG v$LATEST..."
	SVG_COMMIT=$(gh_api https://api.github.com/repos/Templarian/MaterialDesign-SVG/commits/v$LATEST | sed -n -e 's/.*"sha": *"\([^"]*\)".*/\1/p' | head -1)

	if [ -z "$MDI_COMMIT" ] || [ -z "$SVG_COMMIT" ]; then
		echo "Could not resolve matching commits for v$LATEST in both repositories; aborting."
		exit 1
	fi

	MDI_VERSION=$LATEST
	echo "Bumping to $MDI_VERSION (webfont $MDI_COMMIT, svg $SVG_COMMIT)"
else
	if [ -n "$LATEST" ] && [ "$LATEST" != "$MDI_VERSION" ]; then
		echo "A newer version ($LATEST) is available; run with --bump to update."
	fi
	if [[ \
			-f MaterialDesignIcons.ttf && \
			-f MaterialDesignIcons-$MDI_VERSION.ttf && \
			-f MaterialDesignIcons.json && \
			-f MaterialDesignIcons-$MDI_VERSION.json ]]; then
		echo "Up-to-date"
		exit
	fi
fi

echo "Ensuring fonttools is installed via pip..."
pip3 install --user fonttools

if [ ! -f fontname-$FONT_RENAME_COMMIT.py ]; then
  echo "Downloading the fontname script..."
  curl --fail --location -O --silent https://raw.githubusercontent.com/chrissimpkins/fontname.py/77734a1a165d25c8c83b2201c15e268da4a107b6/fontname.py >fontname-$FONT_RENAME_COMMIT.py
else
  echo "fontname.py is already downloaded"
fi

echo "Downloading the MaterialDesignIcons TTF..."
curl --fail --location -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/$MDI_COMMIT/fonts/materialdesignicons-webfont.ttf

echo "Downloading the MaterialDesignIcons JSON..."
curl --fail --location -O --silent https://raw.githubusercontent.com/Templarian/MaterialDesign-SVG/$SVG_COMMIT/meta.json

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
Tools/build_tool swiftgen
popd

popd

if [ "$BUMP" -eq 1 ]; then
	echo "Updating pinned versions in $SELF..."
	sed \
		-e "s/^MDI_COMMIT=.*/MDI_COMMIT=$MDI_COMMIT/" \
		-e "s/^SVG_COMMIT=.*/SVG_COMMIT=$SVG_COMMIT/" \
		-e "s/^MDI_VERSION=.*/MDI_VERSION=$MDI_VERSION/" \
		"$SELF" >"$SELF.new"
	chmod +x "$SELF.new"
	mv "$SELF.new" "$SELF"
fi
