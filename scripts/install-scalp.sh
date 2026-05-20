#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-latest}"
REPO="scal-p-labs/SCAL-P"

detect_os_arch() {
  local os arch

  os=$(uname -s | tr '[:upper:]' '[:lower:]')

  case "$os" in
    mingw*|cygwin*|msys*)
      os="windows"
      ;;
    linux|darwin)
      ;;
    *)
      echo "Error: unsupported OS: $os"
      exit 1
      ;;
  esac

  arch=$(uname -m)

  case "$arch" in
    x86_64|amd64)
      arch="amd64"
      ;;
    aarch64|arm64)
      arch="arm64"
      ;;
    *)
      echo "Error: unsupported architecture: $arch"
      exit 1
      ;;
  esac

  echo "$os $arch"
}

resolve_latest_version() {
  local token="${GH_TOKEN:-}"
  local api_url="https://api.github.com/repos/$REPO/releases/latest"

  if [ -n "$token" ]; then
    curl -sL -H "Authorization: Bearer $token" "$api_url"
  else
    curl -sL "$api_url"
  fi | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)",/\1/'
}

read -r os arch <<< "$(detect_os_arch)"

if [ "$VERSION" = "latest" ]; then
  echo "Resolving latest release..."
  VERSION=$(resolve_latest_version)
  if [ -z "$VERSION" ]; then
    echo "Error: failed to resolve latest version"
    exit 1
  fi
  echo "Latest release: $VERSION"
fi

if [ "$os" = "windows" ]; then
  ext="zip"
  asset="scalp_${VERSION}_${os}_${arch}.zip"
else
  ext="tar.gz"
  asset="scalp_${VERSION}_${os}_${arch}.tar.gz"
fi

url="https://github.com/$REPO/releases/download/$VERSION/$asset"

tmpdir="/tmp/scalp-install"
mkdir -p "$tmpdir"

echo "Downloading $asset..."
curl -sL "$url" -o "$tmpdir/$asset"

if [ "$ext" = "zip" ]; then
  unzip -o "$tmpdir/$asset" -d "$tmpdir"
else
  tar xzf "$tmpdir/$asset" -C "$tmpdir"
fi

echo "$tmpdir" >> "$GITHUB_PATH"
echo "SCAL-P $VERSION installed successfully ($os/$arch)"
