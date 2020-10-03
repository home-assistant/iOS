#!/bin/bash
for filename in *.png; do
  sips -Z 120x120 "$filename" --out "../../Sources/App/Resources/Alternate Icons/${filename%.png}@2x.png"
  sips -Z 180x180 "$filename" --out "../../Sources/App/Resources/Alternate Icons/${filename%.png}@3x.png"

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
