#!/usr/bin/env bash
# install-runner.sh
# Installs a GitHub Actions self-hosted runner on any Linux machine (x64, arm64, armv7).
#
# Usage:
#   ./scripts/install-runner.sh [OPTIONS]
#
# Options:
#   -u, --url      GitHub org or repo URL
#                  e.g. https://github.com/Hex-Solutions-SpA
#                       https://github.com/Hex-Solutions-SpA/Fyodor
#   -t, --token    Runner registration token
#                  Get it from: Settings > Actions > Runners > New self-hosted runner
#   -n, --name     Runner name (default: hostname)
#   -l, --labels   Comma-separated extra labels (e.g. zephyr,fyodor)
#   -d, --dir      Installation directory (default: ~/actions-runner)
#   -s, --service  Install and start as a systemd service after configuration
#   -h, --help     Show this help message
#
# Examples:
#   # Org-level runner with labels, installed as a service
#   ./scripts/install-runner.sh \
#     --url https://github.com/Hex-Solutions-SpA \
#     --token AXXXXXXXXXXXXXXXXXXXXX \
#     --labels zephyr,fyodor \
#     --service
#
#   # Repo-level runner, custom name and directory
#   ./scripts/install-runner.sh \
#     --url https://github.com/Hex-Solutions-SpA/Fyodor \
#     --token AXXXXXXXXXXXXXXXXXXXXX \
#     --name rpi-fyodor \
#     --labels zephyr,fyodor \
#     --dir /opt/actions-runner

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
RUNNER_URL=""
RUNNER_TOKEN=""
RUNNER_NAME="$(hostname)"
RUNNER_LABELS=""
INSTALL_DIR="${HOME}/actions-runner"
INSTALL_SERVICE=false

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)     RUNNER_URL="$2";    shift 2 ;;
        -t|--token)   RUNNER_TOKEN="$2";  shift 2 ;;
        -n|--name)    RUNNER_NAME="$2";   shift 2 ;;
        -l|--labels)  RUNNER_LABELS="$2"; shift 2 ;;
        -d|--dir)     INSTALL_DIR="$2";   shift 2 ;;
        -s|--service) INSTALL_SERVICE=true; shift ;;
        -h|--help)    usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "$RUNNER_URL" ]]   && { echo "Error: --url is required.";   exit 1; }
[[ -z "$RUNNER_TOKEN" ]] && { echo "Error: --token is required."; exit 1; }

# ── Detect architecture ───────────────────────────────────────────────────────
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)         RUNNER_ARCH="x64"   ;;
    aarch64)        RUNNER_ARCH="arm64" ;;
    armv7l|armv6l)  RUNNER_ARCH="arm"   ;;
    *)
        echo "Error: unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: ${ARCH} → runner arch: ${RUNNER_ARCH}"

# ── Get latest runner version ─────────────────────────────────────────────────
echo "Fetching latest runner version..."
RUNNER_VERSION="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/actions/runner/releases/latest \
    | grep '"tag_name"' \
    | sed 's/.*"v\([^"]*\)".*/\1/')"

echo "Latest runner version: ${RUNNER_VERSION}"

RUNNER_FILE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL_DL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_FILE}"

# ── Prepare install directory ─────────────────────────────────────────────────
if [[ -d "${INSTALL_DIR}" ]]; then
    echo "Directory ${INSTALL_DIR} already exists."
    read -rp "Continue and overwrite? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }
fi

mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# ── Download and verify ───────────────────────────────────────────────────────
echo "Downloading ${RUNNER_FILE}..."
curl -fsSL -O "${RUNNER_URL_DL}"
curl -fsSL -O "${RUNNER_URL_DL}.sha256"

echo "Verifying checksum..."
sha256sum -c "${RUNNER_FILE}.sha256" --ignore-missing 2>/dev/null \
    || { echo "Error: checksum verification failed."; exit 1; }

# ── Extract ───────────────────────────────────────────────────────────────────
echo "Extracting..."
tar xzf "${RUNNER_FILE}"
rm "${RUNNER_FILE}" "${RUNNER_FILE}.sha256"

# ── Install dependencies (runner's own script) ────────────────────────────────
echo "Installing runner dependencies..."
sudo ./bin/installdependencies.sh

# ── Configure ─────────────────────────────────────────────────────────────────
CONFIG_ARGS=(
    --url   "${RUNNER_URL}"
    --token "${RUNNER_TOKEN}"
    --name  "${RUNNER_NAME}"
    --unattended
)

[[ -n "${RUNNER_LABELS}" ]] && CONFIG_ARGS+=(--labels "${RUNNER_LABELS}")

echo "Configuring runner..."
./config.sh "${CONFIG_ARGS[@]}"

# ── Install as systemd service (optional) ─────────────────────────────────────
if [[ "${INSTALL_SERVICE}" == true ]]; then
    echo "Installing systemd service..."
    sudo ./svc.sh install
    sudo ./svc.sh start
    echo ""
    echo "Service installed and started."
    echo "Manage with:"
    echo "  sudo ./svc.sh status"
    echo "  sudo ./svc.sh stop"
    echo "  sudo ./svc.sh start"
else
    echo ""
    echo "Runner configured. To start it manually:"
    echo "  cd ${INSTALL_DIR} && ./run.sh"
    echo ""
    echo "Or install as a service (runs on boot):"
    echo "  cd ${INSTALL_DIR} && sudo ./svc.sh install && sudo ./svc.sh start"
fi

echo ""
echo "Done. Runner '${RUNNER_NAME}' is ready."
echo "Labels: ${RUNNER_LABELS:-none}"
