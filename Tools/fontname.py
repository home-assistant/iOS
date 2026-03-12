#!/usr/bin/env python3

# ==========================================================================
# fontname.py
# Copyright 2019 Christopher Simpkins
# MIT License
#
# Dependencies:
#   1) Python 3.6+ interpreter
#   2) fonttools Python library (https://github.com/fonttools/fonttools)
#         - install with `pip3 install fonttools`
#
# Usage:
#   python3 fontname.py [FONT FAMILY NAME] [FONT PATH 1] <FONT PATH ...>
#
# Notes:
#   Use quotes around font family name arguments that include spaces
# ===========================================================================

import sys
import os

from fontTools import ttLib


def main(argv):
    # command argument tests
    print(" ")
    if len(argv) < 2:
        sys.stderr.write(
            f"[fontname.py] ERROR: you did not include enough arguments to the script.{os.linesep}"
        )
        sys.stderr.write(
            f"Usage: python3 fontname.py [FONT FAMILY NAME] [FONT PATH 1] <FONT PATH ...>{os.linesep}"
        )
        sys.exit(1)

    # begin parsing command line arguments
    try:
        font_name = str(argv[0])  # the first argument is the new typeface name
    except Exception as e:
        sys.stderr.write(
            f"[fontname.py] ERROR: Unable to convert argument to string. {e}{os.linesep}"
        )
        sys.exit(1)

    # all remaining arguments on command line are file paths to fonts
    font_path_list = argv[1:]

    # iterate through all paths provided on command line and rename to `font_name` defined by user
    for font_path in font_path_list:
        # test for existence of font file on requested file path
        if not file_exists(font_path):
            sys.stderr.write(
                f"[fontname.py] ERROR: the path '{font_path}' does not appear to be a valid file path.{os.linesep}"
            )
            sys.exit(1)

        tt = ttLib.TTFont(font_path)
        namerecord_list = tt["name"].names

        style = ""

        # determine font style for this file path from name record nameID 2
        for record in namerecord_list:
            if record.nameID == 2:
                style = str(record)
                break

        # test that a style name was found in the OpenType tables of the font
        if len(style) == 0:
            sys.stderr.write(
                f"[fontname.py] Unable to detect the font style from the OpenType name table in '{font_path}'. {os.linesep}"
            )
            sys.stderr.write("Unable to complete execution of the script.")
            sys.exit(1)
        else:
            # used for the Postscript name in the name table (no spaces allowed)
            postscript_font_name = font_name.replace(" ", "")
            # font family name
            nameID1_string = font_name
            nameID16_string = font_name
            # full font name
            nameID4_string = f"{font_name} {style}"
            # Postscript name
            # - no spaces allowed in family name or the PostScript suffix. should be dash delimited
            nameID6_string = f"{postscript_font_name}-{style.replace(' ', '')}"
            # nameID6_string = postscript_font_name + "-" + style.replace(" ", "")

            # modify the opentype table data in memory with updated values
            for record in namerecord_list:
                if record.nameID == 1:
                    record.string = nameID1_string
                elif record.nameID == 4:
                    record.string = nameID4_string
                elif record.nameID == 6:
                    record.string = nameID6_string
                elif record.nameID == 16:
                    record.string = nameID16_string

        # write changes to the font file
        try:
            tt.save(font_path)
            print(f"[OK] Updated '{font_path}' with the name '{nameID4_string}'")
        except Exception as e:
            sys.stderr.write(
                f"[fontname.py] ERROR: unable to write new name to OpenType name table for '{font_path}'. {os.linesep}"
            )
            sys.stderr.write(f"{e}{os.linesep}")
            sys.exit(1)


# Utilities


def file_exists(filepath):
    """Tests for existence of a file on the string filepath"""
    return os.path.exists(filepath) and os.path.isfile(filepath)


if __name__ == "__main__":
    main(sys.argv[1:])
