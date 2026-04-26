#!/usr/bin/env bash
# install.sh — Build and install OpenClaw from source
#
# Usage:
#   bash install.sh [BRANCH]
#
# Arguments:
#   BRANCH   Git branch to clone (default: main)
#
# What this script does:
#   1. Clones https://github.com/Cong-ty-TNHH-Th-H-GEO/auth-openclaw at BRANCH
#   2. Runs pnpm install + pnpm run build
#   3. Installs openclaw.mjs as the `openclaw` binary in PATH
#   4. Creates ~/.openclaw/.env from the repo's .env.example (if absent)

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/Cong-ty-TNHH-Th-H-GEO/auth-openclaw.git"
BRANCH="${1:-v2026.4.2-enterprise-auth}"
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="openclaw"
ENV_DIR="${HOME}/.openclaw"
ENV_FILE="${ENV_DIR}/.env"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
BOLD='\033[1m'
SUCCESS='\033[38;2;0;229;204m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;230;57;70m'
INFO='\033[38;2;136;146;176m'
NC='\033[0m'

log_info()    { echo -e "${INFO}  ${*}${NC}"; }
log_success() { echo -e "${SUCCESS}✔ ${*}${NC}"; }
log_warn()    { echo -e "${WARN}⚠ ${*}${NC}"; }
log_error()   { echo -e "${ERROR}✖ ${*}${NC}" >&2; }
log_header()  { echo -e "\n${BOLD}${*}${NC}"; }

die() {
    log_error "${*}"
    exit 1
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prerequisites() {
    log_header "Checking prerequisites…"

    command -v git  >/dev/null 2>&1 || die "git is required but not found."
    command -v node >/dev/null 2>&1 || die "node is required but not found (need Node 22+)."
    command -v pnpm >/dev/null 2>&1 || die "pnpm is required but not found. Install via: npm install -g pnpm"

    # Node version check (minimum 22.12)
    local node_major node_minor
    node_major="$(node -e 'process.stdout.write(String(process.versions.node.split(".")[0]))')"
    node_minor="$(node -e 'process.stdout.write(String(process.versions.node.split(".")[1]))')"
    if (( node_major < 22 )) || { (( node_major == 22 )) && (( node_minor < 12 )); }; then
        die "Node 22.12+ is required. Found: $(node --version)"
    fi

    log_success "All prerequisites satisfied (node $(node --version), pnpm $(pnpm --version))"
}

# ---------------------------------------------------------------------------
# Clone
# ---------------------------------------------------------------------------
clone_repo() {
    log_header "Cloning branch '${BRANCH}' from ${REPO_URL}…"

    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "${WORK_DIR}"' EXIT

    git clone --depth=1 --branch "${BRANCH}" "${REPO_URL}" "${WORK_DIR}"
    log_success "Cloned into ${WORK_DIR}"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build() {
    log_header "Installing dependencies and building…"

    cd "${WORK_DIR}"

    log_info "Running pnpm install…"
    pnpm install --frozen-lockfile

    log_info "Running pnpm run build…"
    pnpm run build

    log_success "Build complete"
}

# ---------------------------------------------------------------------------
# Install binary
# ---------------------------------------------------------------------------
install_binary() {
    log_header "Installing '${BINARY_NAME}' binary…"

    local src="${WORK_DIR}/openclaw.mjs"
    [[ -f "${src}" ]] || die "Expected ${src} to exist after build. Was the build step successful?"

    # Prefer ~/.local/bin; fall back to /usr/local/bin (requires sudo)
    local dest_dir="${INSTALL_DIR}"
    if ! mkdir -p "${dest_dir}" 2>/dev/null; then
        log_warn "Cannot write to ${dest_dir}. Trying /usr/local/bin (may need sudo)…"
        dest_dir="/usr/local/bin"
    fi

    local dest="${dest_dir}/${BINARY_NAME}"
    cp "${src}" "${dest}"
    chmod +x "${dest}"

    # Ensure the install dir is on PATH (warn if not)
    if ! echo ":${PATH}:" | grep -q ":${dest_dir}:"; then
        log_warn "${dest_dir} is not in your PATH."
        log_warn "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo -e "    ${BOLD}export PATH=\"${dest_dir}:\$PATH\"${NC}"
    fi

    log_success "Installed: ${dest}"
}

# ---------------------------------------------------------------------------
# Create .env
# ---------------------------------------------------------------------------
create_env() {
    log_header "Setting up ${ENV_FILE}…"

    mkdir -p "${ENV_DIR}"

    if [[ -f "${ENV_FILE}" ]]; then
        log_warn "${ENV_FILE} already exists — leaving it untouched."
        return
    fi

    local example="${WORK_DIR}/.env.example"
    if [[ -f "${example}" ]]; then
        cp "${example}" "${ENV_FILE}"
        chmod 600 "${ENV_FILE}"
        log_success "Created ${ENV_FILE} from .env.example"
        log_warn "Edit ${ENV_FILE} and fill in your secrets (API keys, tokens, etc.)."
    else
        # Fallback: write a minimal stub
        {
            echo "# OpenClaw environment configuration"
            echo "# See https://github.com/Cong-ty-TNHH-Th-H-GEO/auth-openclaw/.env.example for all options"
            echo ""
            echo "OPENCLAW_GATEWAY_TOKEN=change-me-to-a-long-random-token"
        } > "${ENV_FILE}"
        chmod 600 "${ENV_FILE}"
        log_success "Created minimal ${ENV_FILE}"
        log_warn "Edit ${ENV_FILE} and add your configuration."
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo -e "\n${BOLD}OpenClaw source installer${NC}"
    echo -e "${INFO}Branch: ${BRANCH}${NC}\n"

    check_prerequisites
    clone_repo
    build
    install_binary
    create_env

    echo -e "\n${SUCCESS}${BOLD}Installation complete!${NC}"
    echo -e "${INFO}Run ${BOLD}openclaw --help${NC}${INFO} to get started.${NC}\n"
}

main
