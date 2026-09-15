#!/bin/bash
# 编译 Dev Server 监视器为原生 .app
set -e
cd "$(dirname "$0")"

APP="DevServerMonitor.app"
echo "编译中..."
xcrun swiftc -O -o DevServerMonitor main.swift

mkdir -p "$APP/Contents/MacOS"
cp DevServerMonitor "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DevServerMonitor</string>
    <key>CFBundleDisplayName</key>
    <string>Dev Server 监视器</string>
    <key>CFBundleIdentifier</key>
    <string>local.devserver.monitor</string>
    <key>CFBundleExecutable</key>
    <string>DevServerMonitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
echo "完成: $(pwd)/$APP  (双击即可运行)"
