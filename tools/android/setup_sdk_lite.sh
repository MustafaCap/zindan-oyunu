#!/usr/bin/env bash
# Android SDK'nın indirilemediği ortamlar (ör. Claude Code bulut oturumu: dl.google.com kapalı) için Godot'nun APK
# dışa aktarmasına yetecek en küçük "SDK": platform-tools/adb (boş) ve build-tools/35.0.0/apksigner (ApkSignerLite:
# Maven Central'daki apksig ile imzalar). Godot yalnızca bu ikisinin varlığına bakar; hazır APK şablonuyla derlerken
# Gradle ve gerçek SDK gerekmez. Normal bir bilgisayarda bunun yerine Android Studio / komut satırı araçları kurulur
# (docs/GELISTIRME.md > Android).
#
# Kullanım: tools/android/setup_sdk_lite.sh [SDK_KLASÖRÜ]   (varsayılan: ~/Android/Sdk, Godot'nun varsayılan yolu)
set -euo pipefail

SDK="${1:-$HOME/Android/Sdk}"
HERE="$(cd "$(dirname "$0")" && pwd)"
APKSIG_URL="https://repo1.maven.org/maven2/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar"

mkdir -p "$SDK/platform-tools" "$SDK/build-tools/35.0.0/lib"
LIB="$SDK/build-tools/35.0.0/lib"

[ -f "$LIB/apksig.jar" ] || curl -sSL -o "$LIB/apksig.jar" "$APKSIG_URL"
javac -d "$LIB" -cp "$LIB/apksig.jar" "$HERE/ApkSignerLite.java"

cat > "$SDK/build-tools/35.0.0/apksigner" <<EOF
#!/usr/bin/env bash
exec java --add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED --add-exports java.base/sun.security.util=ALL-UNNAMED -cp "$LIB:$LIB/apksig.jar" ApkSignerLite "\$@"
EOF
chmod +x "$SDK/build-tools/35.0.0/apksigner"

# adb yalnızca "cihaza yükle" düğmesi için; dışa aktarma çalıştırmaz
cat > "$SDK/platform-tools/adb" <<'EOF'
#!/usr/bin/env bash
echo "adb yok (Android SDK lite)" >&2
exit 1
EOF
chmod +x "$SDK/platform-tools/adb"

echo "Android SDK lite hazır: $SDK"
