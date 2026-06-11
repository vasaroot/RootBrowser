#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEV_PREFIX="$SCRIPT_DIR/.dev-prefix"
PKG_DIR="$DEV_PREFIX/usr/lib/x86_64-linux-gnu/pkgconfig"

# One-time setup: extract deb packages into .dev-prefix/ inside the project
if [ ! -f "$PKG_DIR/webkit2gtk-4.1.pc" ]; then
  echo ">> First-time setup: extracting dev packages into .dev-prefix/ ..."
  mkdir -p "$DEV_PREFIX" /tmp/_rb_debs

  packages=(
    libwebkit2gtk-4.1-dev libjavascriptcoregtk-4.1-dev
    librsvg2-dev libayatana-appindicator3-dev
    libsoup-3.0-dev libglib2.0-dev
    libsqlite3-dev libpsl-dev
    libkrb5-dev libnghttp2-dev
    libbrotli-dev libsysprof-capture-4-dev
  )

  cd /tmp/_rb_debs
  apt-get download "${packages[@]}"
  for f in *.deb; do
    dpkg-deb -x "$f" "$DEV_PREFIX/"
  done
  cd "$SCRIPT_DIR"

  # krb5-gssapi.pc is a dangling symlink in the deb — create the real file
  mkdir -p "$PKG_DIR/mit-krb5"
  cat > "$PKG_DIR/mit-krb5/krb5-gssapi.pc" << 'EOF'
prefix=/usr
libdir=${prefix}/lib/x86_64-linux-gnu
includedir=${prefix}/include
Name: krb5-gssapi
Description: Kerberos 5 GSSAPI
Version: 1.21.3
Libs: -L${libdir} -lgssapi_krb5
Cflags: -I${includedir}
EOF

  # .so symlinks (linker needs lib*.so, runtime only ships lib*.so.0)
  for lib in webkit2gtk-4.1 soup-3.0 javascriptcoregtk-4.1; do
    actual=$(ls /usr/lib/x86_64-linux-gnu/lib${lib}.so.* 2>/dev/null \
      | grep -v '\.[0-9]\+\.' | head -1)
    [ -n "$actual" ] && ln -sf "$actual" \
      "$DEV_PREFIX/usr/lib/x86_64-linux-gnu/lib${lib}.so"
  done

  rm -rf /tmp/_rb_debs
  echo ">> Setup complete."
fi

# Build environment
export PKG_CONFIG_PATH="$PKG_DIR:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
export CFLAGS="-I$DEV_PREFIX/usr/include"
export CXXFLAGS="-I$DEV_PREFIX/usr/include"
export RUSTFLAGS="-L $DEV_PREFIX/usr/lib/x86_64-linux-gnu -L /usr/lib/x86_64-linux-gnu"

# Rust
source "$HOME/.cargo/env" 2>/dev/null || true

# Node / pnpm via nvm
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

cd "$SCRIPT_DIR"

# Free port 1420 if a stale process holds it
fuser -k 1420/tcp 2>/dev/null || true

exec pnpm tauri dev
