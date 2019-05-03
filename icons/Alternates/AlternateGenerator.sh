#!/bin/bash
for filename in *.png; do
  convert "$filename" -resize 120x120 "../../HomeAssistant/Resources/Alternate Icons/${filename%.png}@2x.png"
  convert "$filename" -resize 180x180 "../../HomeAssistant/Resources/Alternate Icons/${filename%.png}@3x.png"

  echo "<key>${filename%.png}</key>
    <dict>
      <key>CFBundleIconFiles</key>
      <array>
        <string>${filename%.png}</string>
      </array>
      <key>UIPrerenderedIcon</key>
      <true/>
    </dict>"
done
