#!/usr/bin/env bash
set -euo pipefail

REPO="${SHANION_CLI_REPO:-htao-123/Shanion-releases}"
VERSION="${SHANION_CLI_VERSION:-latest}"
INSTALL_DIR="${SHANION_CLI_INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="${SHANION_CLI_BINARY_NAME:-shanion}"
PATH_MARKER="# Shanion CLI"

info() {
  printf '[shanion-cli] %s\n' "$1"
}

fail() {
  printf '[shanion-cli] %s\n' "$1" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}

detect_os() {
  case "$(uname -s)" in
    Darwin) printf 'macos' ;;
    Linux) printf 'linux' ;;
    *) fail "暂不支持当前系统：$(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf 'arm64' ;;
    x86_64|amd64) printf 'x64' ;;
    *) fail "暂不支持当前架构：$(uname -m)" ;;
  esac
}

download_url() {
  local os="$1"
  local arch="$2"
  local asset="shanion-cli-${os}-${arch}.tar.gz"
  if [ "$VERSION" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s' "$REPO" "$asset"
  else
    printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$VERSION" "$asset"
  fi
}

shell_profile() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh) printf '%s/.zshrc' "$HOME" ;;
    bash)
      if [ "$(uname -s)" = "Darwin" ]; then
        printf '%s/.bash_profile' "$HOME"
      else
        printf '%s/.bashrc' "$HOME"
      fi
      ;;
    fish) printf '%s/.config/fish/config.fish' "$HOME" ;;
    *) printf '%s/.profile' "$HOME" ;;
  esac
}

ensure_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return 0 ;;
  esac

  local profile
  profile="$(shell_profile)"
  mkdir -p "$(dirname "$profile")"
  touch "$profile"

  local path_line
  if [ "$(basename "${SHELL:-}")" = "fish" ]; then
    path_line="fish_add_path \"$INSTALL_DIR\""
  else
    path_line="export PATH=\"$INSTALL_DIR:\$PATH\""
  fi

  if grep -F "$PATH_MARKER" "$profile" >/dev/null 2>&1 &&
    grep -Fx "$path_line" "$profile" >/dev/null 2>&1; then
    info "$INSTALL_DIR 已写入 $profile；请重开终端后直接使用 shanion。"
    return 1
  fi

  if [ "$(basename "${SHELL:-}")" = "fish" ]; then
    {
      printf '\n%s\n' "$PATH_MARKER"
      printf '%s\n' "$path_line"
    } >>"$profile"
  else
    {
      printf '\n%s\n' "$PATH_MARKER"
      printf '%s\n' "$path_line"
    } >>"$profile"
  fi
  info "已把 $INSTALL_DIR 写入 $profile；请重开终端后直接使用 shanion。"
  return 1
}

main() {
  need_command curl
  need_command tar
  need_command install

  local os arch url temp_dir archive archive_entries
  os="$(detect_os)"
  arch="$(detect_arch)"
  url="$(download_url "$os" "$arch")"
  temp_dir="$(mktemp -d)"
  archive="$temp_dir/shanion-cli.tar.gz"

  trap 'rm -rf "$temp_dir"' EXIT

  info "下载 $url"
  curl -fL "$url" -o "$archive" || fail "下载失败。请确认 GitHub Release 已上传对应资产。"

  mkdir -p "$INSTALL_DIR"
  archive_entries="$(tar -tzf "$archive")"
  if [ "$(printf '%s\n' "$archive_entries" | wc -l | tr -d ' ')" != "1" ]; then
    fail "压缩包内容不符合预期。"
  fi
  if [ "$archive_entries" != "$BINARY_NAME" ]; then
    fail "压缩包内必须只包含 $BINARY_NAME。"
  fi
  tar -xzf "$archive" -C "$temp_dir"

  if [ ! -f "$temp_dir/$BINARY_NAME" ]; then
    fail "压缩包内没有找到 $BINARY_NAME 可执行文件。"
  fi

  install -m 0755 "$temp_dir/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
  local path_ready=0
  ensure_path || path_ready=1

  info "安装完成：$INSTALL_DIR/$BINARY_NAME"
  "$INSTALL_DIR/$BINARY_NAME" --help >/dev/null || fail "安装后自检失败。"
  if [ "$path_ready" -eq 0 ]; then
    info "现在可以使用：shanion note add --text \"第一条闪念\""
  else
    info "当前终端可先使用：$INSTALL_DIR/$BINARY_NAME note add --text \"第一条闪念\""
  fi
}

main "$@"
