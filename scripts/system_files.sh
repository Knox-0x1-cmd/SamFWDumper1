#!/bin/bash
# =============================================================================
# SamFWDumper - Universal Samsung Firmware System Files Extractor
# Copyright (C) 2026 Xiatsuma
# Licensed under PolyForm Noncommercial License 1.0.0
# https://polyformproject.org/licenses/noncommercial/1.0.0
# =============================================================================
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
readonly SCRIPT_VERSION="2.1.0"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Colors
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step() { echo -e "\n${BLUE}[$1]${NC} $2"; }

# Global variables
URL=""
COMPRESSION_LEVEL="0"
XZ_FLAGS="-0"
CLEANUP_FILES=()
CLEANUP_DIRS=()

# =============================================================================
# Utility Functions
# =============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step() { echo -e "\n${BLUE}[$1]${NC} $2"; }

cleanup_on_exit() {
    for file in "${CLEANUP_FILES[@]}"; do
        [[ -f "${file}" ]] && rm -f "${file}" 2>/dev/null || true
    done
    for dir in "${CLEANUP_DIRS[@]}"; do
        [[ -d "${dir}" ]] && rm -rf "${dir}" 2>/dev/null || true
    done
}

trap cleanup_on_exit EXIT INT TERM

register_cleanup_file() { CLEANUP_FILES+=("$1"); }
register_cleanup_dir() { CLEANUP_DIRS+=("$1"); }

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step() { echo -e "\n${BLUE}[$1]${NC} $2"; }

check_all_tools() {
    local tools=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "debugfs" "simg2img" "lpunpack" "lpdump" "lz4")
    local missing=0
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_error "Required tool '${tool}' not found"
            ((missing++))
        fi
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; exit 1; }
    log_success "All required tools available"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

cleanup_on_exit() {
    for file in "${CLEANUP_FILES[@]}"; do
        [[ -f "${file}" ]] && rm -f "${file}" 2>/dev/null || true
    done
    for dir in "${CLEANUP_DIRS[@]}"; do
        [[ -d "${dir}" ]] && rm -rf "${dir}" 2>/dev/null || true
    done
}

trap cleanup_on_exit EXIT INT TERM

register_cleanup_file() { CLEANUP_FILES+=("$1"); }
register_cleanup_dir() { CLEANUP_DIRS+=("$1"); }

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step() { echo -e "\n${BLUE}[$1]${NC} $2"; }

check_all_tools() {
    local tools=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "debugfs" "simg2img" "lpunpack" "lpdump" "lz4")
    local missing=0
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_error "Required tool '${tool}' not found"
            ((missing++))
        fi
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; exit 1; }
    log_success "All required tools available"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

cleanup_on_exit() {
    for file in "${CLEANUP_FILES[@]}"; do
        [[ -f "${file}" ]] && rm -f "${file}" 2>/dev/null || true
    done
    for dir in "${CLEANUP_DIRS[@]}"; do
        [[ -d "${dir}" ]] && rm -rf "${dir}" 2>/dev/null || true
    done
}

trap cleanup_on_exit EXIT INT TERM

register_cleanup_file() { CLEANUP_FILES+=("$1"); }
register_cleanup_dir() { CLEANUP_DIRS+=("$1"); }

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step() { echo -e "\n${BLUE}[$1]${NC} $2"; }

safe_debugfs_ls() { debugfs -R "ls ${2}" "${1}" 2>/dev/null | grep -q .; }
safe_debugfs_stat() { debugfs -R "stat ${2}" "${1}" 2>/dev/null | grep -q "Type: regular"; }
safe_debugfs_dump() { debugfs -R "dump ${2} ${3}" "${1}" 2>/dev/null; }
safe_debugfs_rdump() { debugfs -R "rdump ${2} ${3}" "${1}" 2>/dev/null; }

# =============================================================================
# Main Functions
# =============================================================================
print_banner() {
    echo "═══════════════════════════════════════"
    echo "   Universal Samsung Firmware Extractor v${SCRIPT_VERSION}"
    echo "═══════════════════════════════════════"
    echo
}

parse_arguments() {
    URL="${1:-}"
    COMPRESSION_LEVEL="${2:-0}"
    WANT_APP="${3:-false}"
    WANT_BIN="${4:-false}"
    WANT_CAMERADATA="${5:-false}"
    WANT_ETC="${6:-false}"
    WANT_LIB="${7:-false}"
    WANT_LIB64="${8:-false}"
    WANT_MEDIA="${9:-false}"
    WANT_PRIV_APP="${10:-false}"
    WANT_SAIV="${11:-false}"
    WANT_CONFIG="${12:-false}"
    WANT_SUPER_CONFIG="${13:-false}"
    WANT_BUILD_PROP="${14:-false}"
    WANT_FRAMEWORK_RRO="${15:-false}"
    WANT_PIT="${16:-false}"
    WANT_WALLPAPER_RES="${17:-false}"

    [[ -z "${URL}" ]] && { log_error "No URL provided"; exit 1; }
    [[ ! "${URL}" =~ ^https?:// ]] && { log_error "Invalid URL"; exit 1; }
    parse_compression "${COMPRESSION_LEVEL}"

    log_info "URL: ${URL}"
    log_info "Compression level: ${COMPRESSION_LEVEL}"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

# =============================================================================
# Helper Functions
# =============================================================================
safe_debugfs_ls() { debugfs -R "ls ${2}" "${1}" 2>/dev/null | grep -q .; }
safe_debugfs_stat() { debugfs -R "stat ${2}" "${1}" 2>/dev/null | grep -q "Type: regular"; }
safe_debugfs_dump() { debugfs -R "dump ${2} ${3}" "${1}" 2>/dev/null; }
safe_debugfs_rdump() { debugfs -R "rdump ${2} ${3}" "${1}" 2>/dev/null; }

# =============================================================================
# Main Functions
# =============================================================================
print_banner() {
    echo "═══════════════════════════════════════"
    echo "   Universal Samsung Firmware Extractor v${SCRIPT_VERSION}"
    echo "═══════════════════════════════════════"
    echo
}

parse_arguments() {
    URL="${1:-}"
    COMPRESSION_LEVEL="${2:-0}"
    WANT_APP="${3:-false}"
    WANT_BIN="${4:-false}"
    WANT_CAMERADATA="${5:-false}"
    WANT_ETC="${6:-false}"
    WANT_LIB="${7:-false}"
    WANT_LIB64="${8:-false}"
    WANT_MEDIA="${9:-false}"
    WANT_PRIV_APP="${10:-false}"
    WANT_SAIV="${11:-false}"
    WANT_CONFIG="${12:-false}"
    WANT_SUPER_CONFIG="${13:-false}"
    WANT_BUILD_PROP="${14:-false}"
    WANT_FRAMEWORK_RRO="${15:-false}"
    WANT_PIT="${16:-false}"
    WANT_WALLPAPER_RES="${17:-false}"

    [[ -z "${URL}" ]] && { log_error "No URL provided"; exit 1; }
    [[ ! "${URL}" =~ ^https?:// ]] && { log_error "Invalid URL"; exit 1; }
    parse_compression "${COMPRESSION_LEVEL}"

    log_info "URL: ${URL}"
    log_info "Compression level: ${COMPRESSION_LEVEL}"
    log_info "Targets: app=${WANT_APP} bin=${WANT_BIN} cameradata=${WANT_CAMERADATA} etc=${WANT_ETC} lib=${WANT_LIB} lib64=${WANT_LIB64} media=${WANT_MEDIA} priv_app=${WANT_PRIV_APP} saiv=${WANT_SAIV} config=${WANT_CONFIG} super_config=${WANT_SUPER_CONFIG} build_prop=${WANT_BUILD_PROP} framework_rro=${WANT_FRAMEWORK_RRO} pit=${WANT_PIT} wallpaper_res=${WANT_WALLPAPER_RES}"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

check_all_tools() {
    local tools=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "debugfs" "simg2img" "lpunpack" "lpdump" "lz4")
    local missing=0
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_error "Required tool '${tool}' not found"
            ((missing++))
        fi
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; exit 1; }
    log_success "All required tools available"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

safe_debugfs_ls() { debugfs -R "ls ${2}" "${1}" 2>/dev/null | grep -q .; }
safe_debugfs_stat() { debugfs -R "stat ${2}" "${1}" 2>/dev/null | grep -q "Type: regular"; }
safe_debugfs_dump() { debugfs -R "dump ${2} ${3}" "${1}" 2>/dev/null; }
safe_debugfs_rdump() { debugfs -R "rdump ${2} ${3}" "${1}" 2>/dev/null; }

# =============================================================================
# Main Functions
# =============================================================================
print_banner() {
    echo "═══════════════════════════════════════"
    echo "   Universal Samsung Firmware Extractor v${SCRIPT_VERSION}"
    echo "═══════════════════════════════════════"
    echo
}

parse_arguments() {
    URL="${1:-}"
    COMPRESSION_LEVEL="${2:-0}"
    WANT_APP="${3:-false}"
    WANT_BIN="${4:-false}"
    WANT_CAMERADATA="${5:-false}"
    WANT_ETC="${6:-false}"
    WANT_LIB="${7:-false}"
    WANT_LIB64="${8:-false}"
    WANT_MEDIA="${9:-false}"
    WANT_PRIV_APP="${10:-false}"
    WANT_SAIV="${11:-false}"
    WANT_CONFIG="${12:-false}"
    WANT_SUPER_CONFIG="${13:-false}"
    WANT_BUILD_PROP="${14:-false}"
    WANT_FRAMEWORK_RRO="${15:-false}"
    WANT_PIT="${16:-false}"
    WANT_WALLPAPER_RES="${17:-false}"

    [[ -z "${URL}" ]] && { log_error "No URL provided"; exit 1; }
    [[ ! "${URL}" =~ ^https?:// ]] && { log_error "Invalid URL"; exit 1; }
    parse_compression "${COMPRESSION_LEVEL}"

    log_info "URL: ${URL}"
    log_info "Compression level: ${COMPRESSION_LEVEL}"
    log_info "Targets: app=${WANT_APP} bin=${WANT_BIN} cameradata=${WANT_CAMERADATA} etc=${WANT_ETC} lib=${WANT_LIB} lib64=${WANT_LIB64} media=${WANT_MEDIA} priv_app=${WANT_PRIV_APP} saiv=${WANT_SAIV} config=${WANT_CONFIG} super_config=${WANT_SUPER_CONFIG} build_prop=${WANT_BUILD_PROP} framework_rro=${WANT_FRAMEWORK_RRO} pit=${WANT_PIT} wallpaper_res=${WANT_WALLPAPER_RES}"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

check_all_tools() {
    local tools=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "debugfs" "simg2img" "lpunpack" "lpdump" "lz4")
    local missing=0
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_error "Required tool '${tool}' not found"
            ((missing++))
        fi
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; exit 1; }
    log_success "All required tools available"
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (0)"; XZ_FLAGS="-0" ;;
    esac
}

safe_debugfs_ls() { debugfs -R "ls ${2}" "${1}" 2>/dev/null | grep -q .; }
safe_debugfs_stat() { debugfs -R "stat ${2}" "${1}" 2>/dev/null | grep -q "Type: regular"; }
safe_debugfs_dump() { debugfs -R "dump ${2} ${3}" "${1}" 2>/dev/null; }
safe_debugfs_rdump() { debugfs -R "rdump ${2} ${3}" "${1}" 2>/dev/null; }

# =============================================================================
# Main Functions
# =============================================================================
print_banner() {
    echo "═══════════════════════════════════════"
    echo "   Universal Samsung Firmware Extractor v${SCRIPT_VERSION}"
    echo "═══════════════════════════════════════"
    echo
}

# =============================================================================
# Main
# =============================================================================
main() {
    print_banner
    
    parse_arguments "$@"
    check_all_tools
    
    download_firmware
    extract_firmware_info
    extract_zip
    extract_ap
    extract_super_and_system
    extract_system_contents
    extract_targets
    package_output
    show_results
}

# =============================================================================
# Sub-functions (defined inline for simplicity)
# =============================================================================

download_firmware() {
    log_step "1/8" "Downloading firmware..."
    wget -q --no-check-certificate --content-disposition "${URL}"
    ZIP_FILE=$(ls -t *.zip 2>/dev/null | head -1)
    [[ -f "${ZIP_FILE}" ]] || { log_error "Download failed"; exit 1; }
    FILESIZE=$(stat -c%s "${ZIP_FILE}")
    [[ "${FILESIZE}" -eq 0 ]] && { log_error "Empty file"; exit 1; }
    log_success "Downloaded: $(numfmt --to=iec ${FILESIZE})"
    register_cleanup_file "${ZIP_FILE}"
}

extract_firmware_info() {
    CSC_CODE=$(echo "${ZIP_FILE}" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z]{3}$' | grep -v -E '^(COM|SAM|FAC)$' | head -1)
    AP_CODE=$(echo "${ZIP_FILE}" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z][A-Z0-9]{11,}$' | head -1)
    echo "${CSC_CODE}" > csc_code.txt
    echo "${AP_CODE}" > ap_code.txt
    log_info "Firmware: ${AP_CODE} | CSC: ${CSC_CODE}"
    register_cleanup_file "csc_code.txt"
    register_cleanup_file "ap_code.txt"
}

extract_zip() {
    log_step "2/8" "Extracting ZIP..."
    unzip -o "${ZIP_FILE}" >/dev/null 2>&1
    rm -f "${ZIP_FILE}"
    log_success "Done"
}

extract_ap() {
    log_step "3/8" "Extracting AP..."
    AP_FILE=$(find . -name "AP_*.tar.md5" -o -name "AP_*.tar" | head -1)
    [[ -z "${AP_FILE}" ]] && { log_error "AP file not found"; exit 1; }
    tar -xf "${AP_FILE}" >/dev/null 2>&1
    rm -f "${AP_FILE}"
    log_success "Done"
}

extract_super_and_system() {
    log_step "4/8" "Getting system.img and product.img..."
    
    SUPER_FILE=$(find . -maxdepth 1 -name "super.img*" -o -name "super.img" | head -1)
    if [[ -n "${SUPER_FILE}" ]]; then
        if [[ "${SUPER_FILE}" == *.lz4 ]]; then
            lz4 -d "${SUPER_FILE}" "super.img" 2>/dev/null
            SUPER_FILE="super.img"
        fi
        if file "${SUPER_FILE}" 2>/dev/null | grep -q "sparse"; then
            simg2img "${SUPER_FILE}" "super.raw.img" 2>/dev/null || tools/android-tools/simg2img "${SUPER_FILE}" "super.raw.img"
            SUPER_FILE="super.raw.img"
        fi
        mkdir -p super_dump
        tools/android-tools/lpunpack "${SUPER_FILE}" super_dump 2>/dev/null

        if [[ "${WANT_SUPER_CONFIG}" = "true" ]]; then
            if [[ -d "super_dump/configs" ]]; then
                cp -r "super_dump/configs" "output/super_config"
            elif [[ -d "super_dump/config" ]]; then
                cp -r "super_dump/config" "output/super_config"
            else
                mkdir -p "output/super_config"
                find super_dump -maxdepth 1 \( -name "*.cfg" -o -name "*_partition*" -o -name "misc_info*" \) -exec cp {} "output/super_config/" \; 2>/dev/null
                tools/android-tools/lpdump "${SUPER_FILE}" > "output/super_config/lpdump.txt" 2>/dev/null || true
            fi
            log_success "super config saved"
        fi

        SYSTEM_IMG=$(find super_dump -name "system.img" -o -name "system_a.img" | head -1)
        PRODUCT_IMG=$(find super_dump -name "product.img" -o -name "product_a.img" | head -1)
    else
        [[ "${WANT_SUPER_CONFIG}" = "true" ]] && log_warning "Legacy device - super config not available"
        SYSTEM_IMG=$(find . -maxdepth 1 -name "system.img.lz4" -o -name "system.img" | head -1)
        [[ "${SYSTEM_IMG}" == *.lz4 ]] && { lz4 -d "${SYSTEM_IMG}" "system_raw.img" 2>/dev/null; SYSTEM_IMG="system_raw.img"; }
        if [[ -n "${SYSTEM_IMG}" ]] && file "${SYSTEM_IMG}" 2>/dev/null | grep -q "sparse"; then
            simg2img "${SYSTEM_IMG}" "system_unsparse.img" 2>/dev/null
            SYSTEM_IMG="system_unsparse.img"
        fi
        PRODUCT_IMG=$(find . -maxdepth 1 -name "product.img.lz4" -o -name "product.img" | head -1)
        [[ "${PRODUCT_IMG}" == *.lz4 ]] && { lz4 -d "${PRODUCT_IMG}" "product_raw.img" 2>/dev/null; PRODUCT_IMG="product_raw.img"; }
        [[ -n "${PRODUCT_IMG}" ]] && file "${PRODUCT_IMG}" 2>/dev/null | grep -q "sparse" && { simg2img "${PRODUCT_IMG}" "product_unsparse.img" 2>/dev/null; PRODUCT_IMG="product_unsparse.img"; }
    fi

    if [[ "${WANT_FRAMEWORK_RRO}" = "true" ]]; then
        log_step "5/8" "Extracting framework RRO APK..."
        if [[ -z "${PRODUCT_IMG}" ]] || [[ ! -f "${PRODUCT_IMG}" ]]; then
            log_warning "product.img not found"
        else
            mkdir -p product_extracted
            RRO_FOUND=false

            tools/erofs-utils/extract.erofs -i "${PRODUCT_IMG}" -x -o product_extracted/ >/dev/null 2>&1 || {
                for SRC_PATH in "overlay" "product/overlay"; do
                    if safe_debugfs_ls "${PRODUCT_IMG}" "${SRC_PATH}"; then
                        mkdir -p "product_extracted/overlay"
                        safe_debugfs_rdump "${PRODUCT_IMG}" "${SRC_PATH}" "product_extracted/overlay"
                        break
                    fi
                done
            }

            for BASE in \
                "product_extracted/product_a/product/overlay" \
                "product_extracted/product_a/overlay" \
                "product_extracted/product_b/product/overlay" \
                "product_extracted/product_b/overlay" \
                "product_extracted/product/overlay" \
                "product_extracted/overlay" \
                "product_extracted/system/product/overlay"; do
                APK_SRC=$(find "${BASE}" -name "framework-res__*__auto_generated_rro_product.apk" 2>/dev/null | head -1)
                if [[ -n "${APK_SRC}" ]]; then
                    cp "${APK_SRC}" "output/$(basename "${APK_SRC}")"
                    log_success "    ✓ $(basename "${APK_SRC}")"
                    RRO_FOUND=true
                    break
                fi
            done
            ${RRO_FOUND} || log_warning "  ⚠️ framework-res RRO APK not found"
            rm -rf product_extracted
        fi
    else
        log_step "5/8" "Framework RRO extraction skipped"
    fi

    if [[ -z "${TARGETS}" ]] && [[ "${WANT_WALLPAPER_RES}" != "true" ]]; then
        log_step "6/8" "No system targets - skipping"
    else
        [[ -z "${SYSTEM_IMG}" || ! -f "${SYSTEM_IMG}" ]] && { log_error "system.img not found"; exit 1; }
        log_step "6/8" "Extracting system.img contents..."
        mkdir -p system_extracted

        SINGLE_FILES="build.prop floating_features.xml"

        if tools/erofs-utils/extract.erofs -i "${SYSTEM_IMG}" -x -o system_extracted/ >/dev/null 2>&1; then
            log_success "Extracted via erofs"
        else
            log_warning "erofs failed - trying debugfs..."
            DEBUGFS_TARGETS="${TARGETS}"
            [[ "${WANT_WALLPAPER_RES}" = "true" ]] && DEBUGFS_TARGETS="${DEBUGFS_TARGETS} priv-app/wallpaper-res"

            for TARGET in ${DEBUGFS_TARGETS}; do
                IS_FILE=false
                for SF in ${SINGLE_FILES}; do
                    [[ "${TARGET}" = "${SF}" ]] && IS_FILE=true && break
                done
                if ${IS_FILE}; then
                    FOUND=false
                    for SRC_PATH in "${TARGET}" "system/${TARGET}"; do
                        if safe_debugfs_stat "${SYSTEM_IMG}" "${SRC_PATH}"; then
                            safe_debugfs_dump "${SYSTEM_IMG}" "${SRC_PATH}" "system_extracted/${TARGET}"
                            FOUND=true
                            break
                        fi
                    done
                    ${FOUND} || log_warning "  ⚠️ ${TARGET} not found"
                else
                    FOUND=false
                    DEST_PARENT="system_extracted/$(dirname "${TARGET}")"
                    mkdir -p "${DEST_PARENT}"
                    for SRC_PATH in "${TARGET}" "system/${TARGET}"; do
                        if safe_debugfs_ls "${SYSTEM_IMG}" "${SRC_PATH}"; then
                            safe_debugfs_rdump "${SYSTEM_IMG}" "${SRC_PATH}" "${DEST_PARENT}"
                            FOUND=true
                            break
                        fi
                    done
                    ${FOUND} || log_warning "  ⚠️ ${TARGET} not found"
                fi
            done
        fi

        log_step "7/8" "Copying selected targets..."
        mkdir -p output

        if [[ "${WANT_WALLPAPER_RES}" = "true" ]]; then
            APK_FOUND=false
            for BASE in \
                "system_extracted/priv-app/wallpaper-res" \
                "system_extracted/system/priv-app/wallpaper-res" \
                "system_extracted/system_a/priv-app/wallpaper-res" \
                "system_extracted/system/system/priv-app/wallpaper-res" \
                "system_extracted/system_a/system/priv-app/wallpaper-res"; do
            APK_SRC="${BASE}/wallpaper-res.apk"
            if [[ -f "${APK_SRC}" ]]; then
                cp "${APK_SRC}" "output/wallpaper-res.apk"
                log_success "    ✓ wallpaper-res.apk"
                APK_FOUND=true
                break
            fi
            done
            ${APK_FOUND} || log_warning "  ⚠️ wallpaper-res.apk not found"
        fi

        TARGETS="${TARGETS} ${SINGLE_FILES}"
        for TARGET in ${TARGETS}; do
            if [[ -e "system_extracted/${TARGET}" ]]; then
                cp -r "system_extracted/${TARGET}" "output/"
                log_success "    ✓ ${TARGET}"
                continue
            fi
            for BASE in \
                "system_extracted/system" \
                "system_extracted/system_a" \
                "system_extracted/system/system" \
                "system_extracted/system_a/system"; do
            SRC="${BASE}/${TARGET}"
            if [[ -e "${SRC}" ]]; then
                cp -r "${SRC}" "output/"
                log_success "    ✓ ${TARGET}"
                break
            fi
            done
            [[ ! -e "output/${TARGET}" ]] && log_warning "  ⚠️ Not found: ${TARGET}"
        done

        rm -rf system_extracted
    fi

    rm -rf super_dump super.img super.raw.img system_unsparse.img product_raw.img product_unsparse.img system_raw.img

    log_step "8/8" "Packaging output..."
    for ITEM in output/*; do
        [[ -e "${ITEM}" ]] || continue
        NAME=$(basename "${ITEM}")
        if [[ -d "${ITEM}" ]]; then
            if [[ "${COMPRESSION_LEVEL}" != "0" ]]; then
                tar -cf - -C output "${NAME}" | xz ${XZ_FLAGS} -T0 2>/dev/null > "output/${NAME}.tar.xz" && rm -rf "${ITEM}"
                log_success "    ✓ ${NAME}.tar.xz"
            else
                tar -cf "output/${NAME}.tar" -C output "${NAME}" && rm -rf "${ITEM}"
                log_success "    ✓ ${NAME}.tar"
            fi
        elif [[ -f "${ITEM}" ]] && [[ "${COMPRESSION_LEVEL}" != "0" ]] && [[ "${ITEM}" != *.xz ]]; then
            xz ${XZ_FLAGS} -T0 "${ITEM}" 2>/dev/null && log_success "    ✓ ${NAME}.xz" || true
        fi
    done

    log_step "Done" "Results:"
    FILE_COUNT=$(ls -1 output 2>/dev/null | wc -l)
    [[ "${FILE_COUNT}" -eq 0 ]] && { log_error "Nothing extracted!"; exit 1; }
    TOTAL_SIZE=$(du -sh output | cut -f1)
    log_success "Extracted ${FILE_COUNT} items"
    log_info "Total size: ${TOTAL_SIZE}"
    echo ""; echo "Files:"; ls -lh output
    echo "═══════════════════════════════════════"
    log_success "Done!"
}

# =============================================================================
# Main
# =============================================================================
main() {
    print_banner
    parse_arguments "$@"
    check_all_tools
    download_firmware
    extract_firmware_info
    extract_zip
    extract_ap
    extract_super_and_system
    show_results
}

main "$@"