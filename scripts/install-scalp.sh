#!/usr/bin/env bash
#
# install-scalp.sh — Download and install SCAL-P binary securely
#
# Downloads from GitHub releases, verifies SHA-512 checksums,
# extracts only the binary, and installs to a clean PATH directory.
#
# Usage: install-scalp.sh [version]

set -euo pipefail

VERSION="${1:-latest}"
REPO="CarlosEduJs/SCAL-P"
PROJECT="scalp"

# ── Logging helpers (GitHub Actions annotations) ──────────────────────────
info()  { echo "::notice:: $*"; }
warn()  { echo "::warning:: $*"; }
die()   { echo "::error:: $*" >&2; exit 1; }

TMPDIR=""
cleanup() { [ -n "$TMPDIR" ] && rm -rf "$TMPDIR"; }
trap cleanup EXIT

# ── Platform detection ────────────────────────────────────────────────────
detect_platform() {
  local os arch

  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    mingw*|cygwin*|msys*) os="windows" ;;
    linux|darwin) ;;
    *) die "unsupported OS: $os" ;;
  esac

  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "unsupported architecture: $arch" ;;
  esac

  printf '%s %s' "$os" "$arch"
}

read -r OS ARCH <<< "$(detect_platform)"
info "Platform: $OS/$ARCH"

# ── Version resolution (redirect-based, no JSON parsing) ──────────────────
if [ "$VERSION" = "latest" ]; then
  info "Resolving latest release..."
  redirect=$(curl -sfL -o /dev/null -w '%{redirect_url}' \
    "https://github.com/$REPO/releases/latest" 2>/dev/null) \
    || die "failed to resolve latest version"
  VERSION="${redirect##*/}"
  [ -n "$VERSION" ] || die "failed to extract version from redirect"
  info "Latest release: $VERSION"
fi

# ── Asset names ───────────────────────────────────────────────────────────
if [ "$OS" = "windows" ]; then
  ext="zip"
  binary_ext=".exe"
else
  ext="tar.gz"
  binary_ext=""
fi
ASSET="${PROJECT}_${VERSION}_${OS}_${ARCH}.${ext}"
BINARY="${PROJECT}${binary_ext}"
BASE_URL="https://github.com/$REPO/releases/download/$VERSION"

# ─── Download ─────────────────────────────────────────────────────────────
TMPDIR=$(mktemp -d) || die "failed to create temp directory"

info "Downloading $ASSET ..."
curl -fL -o "$TMPDIR/$ASSET" "$BASE_URL/$ASSET" \
  || die "download failed (HTTP error)"

# ── Integrity: reject HTML (GitHub error pages) via magic bytes ───────────
# gzip → 1f8b, zip → 504b
magic=$(head -c 4 "$TMPDIR/$ASSET" | od -A n -t x1 | tr -d ' \n')
case "$magic" in
  1f8b*) ;;  # gzip (tar.gz)
  504b*) ;;  # zip
  *) die "downloaded file is not a valid archive (magic: ${magic:0:8})" ;;
esac

# ── Checksum verification via SHA-512 ─────────────────────────────────────
verify_sha512() {
  local file="$1" expected="$2"
  local computed=""

  if   command -v sha512sum &>/dev/null; then
    computed=$(sha512sum "$file" | awk '{print $1}')
  elif command -v shasum &>/dev/null; then
    computed=$(shasum -a 512 "$file" | awk '{print $1}')
  elif command -v openssl &>/dev/null; then
    computed=$(openssl dgst -sha512 "$file" | awk '{print $NF}')
  else
    warn "no SHA-512 tool available; skipping checksum verification"
    return 0
  fi

  if [ "$computed" != "$expected" ]; then
    die "checksum mismatch: expected $expected, got $computed"
  fi
  info "Checksum verified"
}

if curl -fL -o "$TMPDIR/checksums.txt" "$BASE_URL/checksums.txt" 2>/dev/null; then
  expected=$(awk -v asset="$ASSET" '$2 == asset { print $1 }' "$TMPDIR/checksums.txt")
  if [ -n "$expected" ]; then
    verify_sha512 "$TMPDIR/$ASSET" "$expected"
  else
    warn "checksums.txt has no entry for $ASSET; skipping"
  fi
else
  info "checksums.txt not available for this release; skipping verification"
fi

# ── Extract ───────────────────────────────────────────────────────────────
info "Extracting ..."
mkdir -p "$TMPDIR/extract"
case "$ext" in
  zip) unzip -o "$TMPDIR/$ASSET" -d "$TMPDIR/extract" >/dev/null ;;
  *)   tar xzf "$TMPDIR/$ASSET" -C "$TMPDIR/extract" ;;
esac

# ── Install binary only ──────────────────────────────────────────────────
BIN_PATH=$(find "$TMPDIR/extract" -name "$BINARY" -type f | head -1)
[ -n "$BIN_PATH" ] || die "binary '$BINARY' not found in archive"

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"
install -m 755 "$BIN_PATH" "$INSTALL_DIR/$BINARY"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$INSTALL_DIR" >> "$GITHUB_PATH"
fi

info "$PROJECT $VERSION installed to $INSTALL_DIR/$BINARY ($OS/$ARCH)"
