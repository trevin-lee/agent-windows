#!/bin/zsh
# End-to-end check on a real window: open a test window, snap it with `tilespace snap`, and check
# that it lands where tilespace said it would. Moves only its own window, but it does take focus,
# so it's meant for CI (a macOS runner) more than a desk.
#
# Needs Accessibility access for whatever runs it (on a Mac: the terminal app).
set -euo pipefail
cd "${0:A:h}/../.."

swift build -c release --product tilespace
tilespace=.build/release/tilespace
mkdir -p build
swiftc -O Tests/Integration/TestWindow.swift -o build/TestWindow
cat > build/trusted.swift <<'EOF'
import ApplicationServices
exit(AXIsProcessTrusted() ? 0 : 1)
EOF
swiftc build/trusted.swift -o build/trusted
if ! build/trusted; then
    echo "no Accessibility access: allow the app running this in System Settings > Privacy & Security > Accessibility"
    exit 1
fi

frame=$(mktemp)
build/TestWindow $frame &
pid=$!
trap "kill $pid 2>/dev/null" EXIT
sleep 2

failed=0
for action in left-half right-half top-half bottom-half top-left bottom-right \
              first-third center-third last-third first-two-thirds center-two-thirds last-two-thirds \
              maximize smaller larger center maximize-height; do
    # prints e.g. "left-half: 0,25 720x875"
    said=$($tilespace snap $action "tilespace test")
    sleep 0.5
    want=(${(s: :)${${said#*: }/,/ }/x/ })
    got=(${(s: :)$(<$frame)})
    ok=1
    for i in 1 2 3 4; do (( ${want[i]} - ${got[i]} > 2 || ${got[i]} - ${want[i]} > 2 )) && ok=0; done
    if (( ok )); then echo "ok    $said"
    else echo "FAIL  $said, but the window is at ${got[1]},${got[2]} ${got[3]}x${got[4]}"; failed=1; fi
done

# the menu-bar app starts and keeps running
build_app=.build/release/TileSpaceApp
swift build -c release --product TileSpaceApp
$build_app & app=$!
sleep 3
if kill -0 $app 2>/dev/null; then echo "ok    menu-bar app runs"; kill $app
else echo "FAIL  menu-bar app exited"; failed=1; fi

exit $failed
