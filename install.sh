#!/bin/bash
set -e

# =========================
# CONFIG
# =========================

THEME_NAME="ohmywin.zsh-theme"
THEME_ID="ohmywin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
THEME_PATH="$SCRIPT_DIR/$THEME_NAME"

OMZ_DIR="$HOME/.oh-my-zsh"
ZSHRC="$HOME/.zshrc"
THEME_DIR="$OMZ_DIR/custom/themes"

# =========================
# ARG PARSING
# =========================

MODE="interactive"
AUTO_YES=0
ENABLE_BANNER=0

for arg in "$@"; do
    case "$arg" in
        --minimal) MODE="minimal" ;;
        --full) MODE="full" ;;
        --custom) MODE="custom" ;;
        --yes) AUTO_YES=1 ;;
        --help)
cat << EOF
OhMyWin Installer

--minimal   OMZ + Theme only
--full      Everything + banner enabled
--custom    Ask for everything
--yes       No prompts
EOF
exit 0
        ;;
    esac
done

# =========================
# HELPERS
# =========================

ask() {
    if [ "$AUTO_YES" -eq 1 ]; then
        return 0
    fi

    read -rp "$1 (y/n): " ans
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# =========================
# CHECKS
# =========================

check_zsh() {
    echo "[CHECK] Zsh..."
    command -v zsh >/dev/null 2>&1 || {
        echo "Zsh not found!"
        exit 1
    }
}

check_theme_file() {
    echo "[CHECK] Theme file..."
    [ -f "$THEME_PATH" ] || {
        echo "Theme file missing: $THEME_PATH"
        exit 1
    }
}

ensure_oh_my_zsh() {
    echo "[CHECK] Oh My Zsh..."

    if [ -d "$OMZ_DIR" ]; then
        return 0
    fi

    echo "Oh My Zsh not found."

    if ask "Install Oh My Zsh?"; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        exit 1
    fi
}

ensure_zshrc() {
    echo "[CHECK] .zshrc..."

    if [ -f "$ZSHRC" ]; then
        return 0
    fi

    if ask "Create default .zshrc?"; then
        cat > "$ZSHRC" << EOF
export ZSH="$OMZ_DIR"
ZSH_THEME="robbyrussell"
plugins=(git)
source \$ZSH/oh-my-zsh.sh
EOF
    else
        exit 1
    fi
}

# =========================
# INSTALL
# =========================

install_theme() {
    echo "[INSTALL] Theme..."
    mkdir -p "$THEME_DIR"
    cp "$THEME_PATH" "$THEME_DIR/"
}

backup_zshrc() {
    echo "[BACKUP] .zshrc..."

    [ -s "$ZSHRC" ] || return 0

    ts=$(date +%Y%m%d_%H%M%S)
    cp "$ZSHRC" "$HOME/.zshrc.backup.$ts"
}

patch_theme() {
    echo "[PATCH] Theme..."

    if grep -q '^ZSH_THEME=' "$ZSHRC"; then
        tmp=$(mktemp)

        awk -v theme="$THEME_ID" '
        {
            if ($0 ~ /^ZSH_THEME=/)
                print "ZSH_THEME=\"" theme "\""
            else
                print $0
        }' "$ZSHRC" > "$tmp" && mv "$tmp" "$ZSHRC"
    else
        echo "ZSH_THEME=\"$THEME_ID\"" >> "$ZSHRC"
    fi
}

# =========================
# BANNER (ZSH SAFE ONLY)
# =========================

setup_banner_inline() {
    echo "[PATCH] Banner..."

    if grep -q "^ohmywin_banner" "$ZSHRC"; then
        echo "Banner already exists."
        return
    fi

    cat >> "$ZSHRC" << 'EOF'

# =========================
# OhMyWin Banner
# =========================

ohmywin_banner_shown=0

ohmywin_banner() {
    if [ "$ohmywin_banner_shown" -eq 1 ]; then
        return
    fi
    ohmywin_banner_shown=1

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$PRETTY_NAME"
    elif command -v sw_vers >/dev/null 2>&1; then
        OS_NAME="macOS $(sw_vers -productVersion)"
    else
        OS_NAME="$(uname -s)"
    fi

    YEAR="$(date +%Y)"

    echo "$OS_NAME"
    echo "Copyright (c) $YEAR. All rights reserved."
}

ohmywin_banner
EOF
}

# =========================
# MODE LOGIC
# =========================

apply_mode() {
    case "$MODE" in
        minimal)
            ENABLE_BANNER=0
            ;;
        full)
            ENABLE_BANNER=1
            ;;
        custom|interactive)
            if ask "Enable startup banner?"; then
                ENABLE_BANNER=1
            fi
            ;;
    esac
}

# =========================
# MAIN
# =========================

main() {
    echo "=== OhMyWin Installer ==="

    check_zsh
    check_theme_file

    ensure_oh_my_zsh
    ensure_zshrc

    install_theme
    backup_zshrc
    patch_theme

    apply_mode

    if [ "$ENABLE_BANNER" -eq 1 ]; then
        setup_banner_inline
    fi

    echo "Done. Restart your terminal."
}

main