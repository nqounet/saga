#!/bin/bash
set -e

# SAGA (Swift AVIF Graphic Assistant) macOS .app packaging script

echo "==> Building SAGA in release mode..."
swift build -c release

# .app 構造のセットアップ
APP_NAME="Saga"
APP_DIR="${APP_NAME}.app"

echo "==> Packaging ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# バイナリのコピー
BUILD_BIN=".build/release/${APP_NAME}"
if [ ! -f "${BUILD_BIN}" ]; then
    echo "Error: Release binary not found at ${BUILD_BIN}"
    exit 1
fi
cp "${BUILD_BIN}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# リソースファイル (SPMリソース) のコピー
# Package.swift 内で定義された resources の成果物をコピーする
SPM_RESOURCES=$(find .build/release -name "${APP_NAME}_${APP_NAME}.resources" | head -n 1)
if [ -d "${SPM_RESOURCES}" ]; then
    echo "==> Embedding resources..."
    cp -R "${SPM_RESOURCES}/" "${APP_DIR}/Contents/Resources/"
fi

# Info.plist の生成
cat <<EOF > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.nqounet.saga</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# アプリアイコン (.icns) の生成
echo "==> Generating AppIcon.icns from logo..."
ICONSET_DIR="AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

SRC_IMAGE="Sources/Saga/Resources/AppIcon.jpg"

if [ -f "${SRC_IMAGE}" ]; then
    # 各サイズにリサイズ & PNG変換
    sips -s format png -z 16 16     "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null 2>&1
    sips -s format png -z 32 32     "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null 2>&1
    sips -s format png -z 32 32     "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null 2>&1
    sips -s format png -z 64 64     "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null 2>&1
    sips -s format png -z 128 128   "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null 2>&1
    sips -s format png -z 256 256   "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null 2>&1
    sips -s format png -z 256 256   "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null 2>&1
    sips -s format png -z 512 512   "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null 2>&1
    sips -s format png -z 512 512   "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null 2>&1
    sips -s format png -z 1024 1024 "${SRC_IMAGE}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null 2>&1

    # .icns へ変換
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
else
    echo "Warning: Source icon image not found at ${SRC_IMAGE}. Icon was not bundled."
fi

echo "==> Build Successful: ${APP_DIR} has been created."
