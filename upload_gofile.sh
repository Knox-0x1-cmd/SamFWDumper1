#!/bin/bash
# =============================================================================
# SamFWDumper - GoFile Upload Script
# Copyright (C) 2026 Xiatsuma
# Licensed under PolyForm Noncommercial License 1.0.0
# =============================================================================
set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

# Configuration
MAX_RETRIES=3
RETRY_DELAY=5
TIMEOUT=300

FILE="$1"
[[ -f "${FILE}" ]] || { echo "❌ File not found: ${FILE}" >&2; exit 1; }

FILESIZE=$(stat -c%s "${FILE}")
echo "[INFO] Uploading $(basename "${FILE}") ($(numfmt --to=iec ${FILESIZE}))..."

get_token() {
    local retries=0
    while [[ ${retries} -lt 3 ]]; do
        local response
        response=$(curl -s -X POST "https://api.gofile.io/accounts" --max-time 30)
        local token
        token=$(echo "${response}" | jq -r '.data.token' 2>/dev/null)
        [[ -n "${token}" && "${token}" != "null" ]] && { echo "${token}"; return 0; }
        ((retries++))
        sleep 2
    done
    return 1
}

get_server() {
    local token="$1"
    local retries=0
    while [[ ${retries} -lt 3 ]]; do
        local server
        server=$(curl -s "https://api.gofile.io/servers?token=${TOKEN}" --max-time 30 | jq -r '.data.servers[0].name' 2>/dev/null)
        [[ -n "${server}" && "${server}" != "null" ]] && { echo "${server}"; return 0; }
        ((retries++))
        sleep 2
    done
    return 1
}

upload_file() {
    local token="$1"
    local server="$2"
    local file="$3"
    
    local retries=0
    while [[ ${retries} -lt 3 ]]; do
        local response
        response=$(curl -s -X POST \
            -F "file=@${FILE}" \
            -F "token=${TOKEN}" \
            --max-time 300 \
            "https://${SERVER}.gofile.io/uploadFile")
        
        if echo "${response}" | grep -q '"status":"ok"'; then
            local download_url
            download_url=$(echo "${response}" | jq -r '.data.downloadPage')
            echo "${download_url}"
            return 0
        fi
        
        ((retries++))
        sleep 5
    done
    return 1
}

# Main
FILE="${1:-}"
[[ -f "${FILE}" ]] || { echo "❌ File not found: ${FILE}" >&2; exit 1; }

FILESIZE=$(stat -c%s "${FILE}")
echo "[INFO] Uploading $(basename "${FILE}") ($(numfmt --to=iec ${FILESIZE}))..."

# Get token
TOKEN=$(get_token) || { echo "❌ Failed to get GoFile token" >&2; exit 1; }
echo "[INFO] Got GoFile token"

# Get server
SERVER=$(get_server "${TOKEN}") || { echo "❌ Failed to get GoFile server" >&2; exit 1; }
echo "[INFO] Using server: ${SERVER}"

# Upload
DOWNLOAD_URL=$(upload_file "${TOKEN}" "${SERVER}" "${FILE}") || { echo "❌ Upload failed after 3 attempts" >&2; exit 1; }

echo "✅ Upload successful!"
echo "${DOWNLOAD_URL}"
echo "${DOWNLOAD_URL}" > download_url.txt
exit 0