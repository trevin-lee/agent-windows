#!/bin/zsh
# Build Movewin.app (and the movewin command) into build/.
#   scripts/build-app.sh            build
#   scripts/build-app.sh --install  also copy the app to ~/Applications and movewin to ~/.local/bin
#
# Signs with your Apple Development certificate (override with SIGN_IDENTITY) so the
# Accessibility permission survives rebuilds; an ad-hoc signature would need it granted again
# after every build.
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release
app=build/Movewin.app
rm -rf $app
mkdir -p $app/Contents/MacOS
cp .build/release/MovewinApp $app/Contents/MacOS/Movewin
cp .build/release/movewin build/movewin
cat > $app/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.trevinlee.movewin</string>
    <key>CFBundleName</key><string>Movewin</string>
    <key>CFBundleExecutable</key><string>Movewin</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleURLTypes</key>
    <array><dict>
        <key>CFBundleURLName</key><string>com.trevinlee.movewin</string>
        <key>CFBundleURLSchemes</key><array><string>movewin</string></array>
    </dict></array>
</dict>
</plist>
EOF

identity=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}
codesign --force --options runtime --sign "${identity:--}" $app
codesign --force --sign "${identity:--}" build/movewin
echo "built $app (signed by ${identity:-ad hoc})"

if [[ ${1:-} == --install ]]; then
    pkill -x Movewin || true
    mkdir -p ~/Applications ~/.local/bin
    rm -rf ~/Applications/Movewin.app
    cp -R $app ~/Applications/
    cp build/movewin ~/.local/bin/movewin
    open ~/Applications/Movewin.app
    echo "installed ~/Applications/Movewin.app and ~/.local/bin/movewin"
fi
