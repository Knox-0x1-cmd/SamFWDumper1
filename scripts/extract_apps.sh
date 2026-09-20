#!/bin/bash
# =============================================================================
# SamFW Apps Extractor - Extract specific app folders from Samsung firmware
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

# Target folders to extract
APP_FOLDERS="SketchBook"
PRIVAPP_FOLDERS="BixbyInterpreter SamsungGallery2018"
ETC_FOLDERS="ailasso ailassomatting inpainting objectremoval reflectionremoval shadowremoval style_transfer"
MEDIA_FILES="bootsamsung.qmg bootsamsungloop.qmg shutdown.qmg"
LIB64_FILES="libobjectcapture.arcsoft.so libobjectcapture_jni.arcsoft.so"
FRAMEWORK_JARS="framework.jar knoxsdk.jar samsungkeystoreutils.jar services.jar ssrm.jar"

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
    local tools=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "debugfs" "lz4")
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

# =============================================================================
# Helper Functions
# =============================================================================
safe_debugfs_ls() {
    local img="$1"
    local path="$2"
    debugfs -R "ls ${path}" "${img}" 2>/dev/null | grep -q .
}

safe_debugfs_stat() {
    local img="$1"
    local path="$2"
    debugfs -R "stat ${path}" "${img}" 2>/dev/null | grep -q "Type: regular"
}

safe_debugfs_dump() {
    local img="$1"
    local src="$2"
    local dest="$3"
    debugfs -R "dump ${src} ${dest}" "${img}" 2>/dev/null
}

safe_debugfs_rdump() {
    local img="$1"
    local src="$2"
    local dest="$3"
    debugfs -R "rdump ${src} ${dest}" "${img}" 2>/dev/null
}

# =============================================================================
# Main Functions
# =============================================================================
print_banner() {
    echo "═══════════════════════════════════════"
    echo "   Samsung Firmware Apps Extractor v${SCRIPT_VERSION}"
    echo "═══════════════════════════════════════"
    echo
}

parse_arguments() {
    URL="${1:-}"
    COMPRESSION_LEVEL="${2:-0}"

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

check_all_tools() {
    local tools=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "debugfs" "lz4" "e2fsprogs")
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

safe_debugfs_ls() {
    debugfs -R "ls ${2}" "${1}" 2>/dev/null | grep -q .
}

safe_debugfs_stat() {
    debugfs -R "stat ${2}" "${1}" 2>/dev/null | grep -q "Type: regular"
}

safe_debugfs_dump() {
    debugfs -R "dump ${2} ${3}" "${1}" 2>/dev/null
}

safe_debugfs_rdump() {
    debugfs -R "rdump ${2} ${3}" "${1}" 2>/dev/null
}

download_firmware() {
    log_step "1/6" "Downloading firmware..."
    
    wget -q --no-check-certificate --content-disposition "${URL}"
    ZIP_FILE=$(ls -t *.zip 2>/dev/null | head -1)
    [[ -f "${ZIP_FILE}" ]] || { log_error "Download failed"; exit 1; }
    FILESIZE=$(stat -c%s "${ZIP_FILE}")
    [[ "${FILESIZE}" -eq 0 ]] && { log_error "Empty file"; exit 1; }
    log_success "Downloaded: $(numfmt --to=iec ${FILESIZE})"
}

extract_firmware_info() {
    CSC_CODE=$(echo "${ZIP_FILE}" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z]{3}$' | grep -v -E '^(COM|SAM|FAC)$' | head -1)
    AP_CODE=$(echo "${ZIP_FILE}" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z][A-Z0-9]{11,}$' | head -1)
    echo "${CSC_CODE}" > csc_code.txt
    echo "${AP_CODE}" > ap_code.txt
    log_info "Firmware: ${AP_CODE} | CSC: ${CSC_CODE}"
}

extract_zip() {
    log_step "2/6" "Extracting ZIP..."
    unzip -o "${ZIP_FILE}" >/dev/null 2>&1
    rm -f "${ZIP_FILE}"
    log_success "Done"
}

extract_ap() {
    log_step "3/6" "Extracting AP..."
    AP_FILE=$(find . -name "AP_*.tar.md5" -o -name "AP_*.tar" | head -1)
    [[ -z "${AP_FILE}" ]] && { log_error "AP file not found"; exit 1; }
    tar -xf "${AP_FILE}" >/dev/null 2>&1
    rm -f "${AP_FILE}"
    log_success "Done"
}

extract_super_and_system() {
    log_step "4/6" "Getting system.img..."
    
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
        SYSTEM_IMG=$(find super_dump -name "system.img" -o -name "system_a.img" | head -1)
    else
        SYSTEM_IMG=$(find . -maxdepth 1 -name "system.img.lz4" -o -name "system.img" | head -1)
        if [[ "${SYSTEM_IMG}" == *.lz4 ]]; then
            lz4 -d "${SYSTEM_IMG}" "system_raw.img" 2>/dev/null
            SYSTEM_IMG="system_raw.img"
        fi
        if [[ -n "${SYSTEM_IMG}" ]] && file "${SYSTEM_IMG}" 2>/dev/null | grep -q "sparse"; then
            simg2img "${SYSTEM_IMG}" "system_unsparse.img" 2>/dev/null
            SYSTEM_IMG="system_unsparse.img"
        fi
    fi

    [[ -z "${SYSTEM_IMG}" || ! -f "${SYSTEM_IMG}" ]] && { log_error "system.img not found"; exit 1; }
    log_success "system.img ready"
}

extract_system_contents() {
    log_step "5/6" "Extracting system.img..."
    mkdir -p system_extracted
    
    if tools/erofs-utils/extract.erofs -i "${SYSTEM_IMG}" -x -o system_extracted/ >/dev/null 2>&1; then
        log_success "Extracted via erofs"
    else
        log_warning "erofs failed - trying debugfs..."
        extract_via_debugfs
    fi
}

extract_via_debugfs() {
    # Extract app folders
    for FOLDER in ${APP_FOLDERS}; do
        for TARGET in "app/${FOLDER}" "system/app/${FOLDER}"; do
            if safe_debugfs_ls "${SYSTEM_IMG}" "${TARGET}"; then
                mkdir -p "system_extracted/app/${FOLDER}"
                safe_debugfs_rdump "${SYSTEM_IMG}" "${TARGET}" "system_extracted/app/${FOLDER}"
                break
            fi
        done
    done
    
    # Extract priv-app folders
    for FOLDER in ${PRIVAPP_FOLDERS}; do
        for TARGET in "priv-app/${FOLDER}" "system/priv-app/${FOLDER}"; do
            if safe_debugfs_ls "${SYSTEM_IMG}" "${TARGET}"; then
                mkdir -p "system_extracted/priv-app/${FOLDER}"
                safe_debugfs_rdump "${SYSTEM_IMG}" "${TARGET}" "system_extracted/priv-app/${FOLDER}"
                break
            fi
        done
    done
    
    # Extract etc folders
    for FOLDER in ${ETC_FOLDERS}; do
        for TARGET in "etc/${FOLDER}" "system/etc/${FOLDER}"; do
            if safe_debugfs_ls "${SYSTEM_IMG}" "${TARGET}"; then
                mkdir -p "system_extracted/etc/${FOLDER}"
                safe_debugfs_rdump "${SYSTEM_IMG}" "${TARGET}" "system_extracted/etc/${FOLDER}"
                break
            fi
        done
    done
    
    # Extract media files
    for FILE in ${MEDIA_FILES}; do
        for SRC in "media/${FILE}" "system/media/${FILE}"; do
            if safe_debugfs_stat "${SYSTEM_IMG}" "${SRC}"; then
                mkdir -p "system_extracted/media"
                safe_debugfs_dump "${SYSTEM_IMG}" "${SRC}" "system_extracted/media/${FILE}"
                break
            fi
        done
    done
    
    # Extract lib64 files
    for FILE in ${LIB64_FILES}; do
        for SRC in "lib64/${FILE}" "system/lib64/${FILE}"; do
            if safe_debugfs_stat "${SYSTEM_IMG}" "${SRC}"; then
                mkdir -p "system_extracted/lib64"
                safe_debugfs_dump "${SYSTEM_IMG}" "${SRC}" "system_extracted/lib64/${FILE}"
                break
            fi
        done
    done
    
    # Extract framework JARs
    for JAR in ${FRAMEWORK_JARS}; do
        for SRC in "framework/${JAR}" "system/framework/${JAR}"; do
            if safe_debugfs_stat "${SYSTEM_IMG}" "${SRC}"; then
                mkdir -p "system_extracted/framework"
                safe_debugfs_dump "${SYSTEM_IMG}" "${SRC}" "system_extracted/framework/${JAR}"
                break
            fi
        done
    done
}

copy_extracted_files() {
    log_step "6/6" "Copying targets..."
    
    mkdir -p "output/Apps/system/app" "output/Apps/system/priv-app" "output/Apps/system/etc" "output/Apps/system/lib64" "output/Apps/system/framework"
    
    # Copy app folders
    for FOLDER in ${APP_FOLDERS}; do
        local FOUND=false
        for BASE in \
            "system_extracted/app/${FOLDER}" \
            "system_extracted/system/app/${FOLDER}" \
            "system_extracted/system_a/app/${FOLDER}" \
            "system_extracted/system/system/app/${FOLDER}" \
            "system_extracted/system_a/system/app/${FOLDER}"; do
        if [[ -d "${BASE}" ]]; then
            cp -r "${BASE}" "output/Apps/system/app/${FOLDER}"
            log_success "    ✓ app/${FOLDER}"
            FOUND=true
            break
        fi
        done
        ${FOUND} || log_warning "  ❌ ${FOLDER} not found"
    done
    
    # Copy priv-app folders
    for FOLDER in ${PRIVAPP_FOLDERS}; do
        local FOUND=false
        for BASE in \
            "system_extracted/priv-app/${FOLDER}" \
            "system_extracted/system/priv-app/${FOLDER}" \
            "system_extracted/system_a/priv-app/${FOLDER}" \
            "system_extracted/system/system/priv-app/${FOLDER}" \
            "system_extracted/system_a/system/priv-app/${FOLDER}"; do
        if [[ -d "${BASE}" ]]; then
            cp -r "${BASE}" "output/Apps/system/priv-app/${FOLDER}"
            log_success "    ✓ priv-app/${FOLDER}"
            FOUND=true
            break
        fi
        done
        ${FOUND} || log_warning "  ❌ ${FOLDER} not found"
    done
    
    # Copy etc folders
    for FOLDER in ${ETC_FOLDERS}; do
        local FOUND=false
        for BASE in \
            "system_extracted/etc/${FOLDER}" \
            "system_extracted/system/etc/${FOLDER}" \
            "system_extracted/system_a/etc/${FOLDER}" \
            "system_extracted/system/system/etc/${FOLDER}" \
            "system_extracted/system_a/system/etc/${FOLDER}"; do
        if [[ -d "${BASE}" ]]; then
            cp -r "${BASE}" "output/Apps/system/etc/${FOLDER}"
            log_success "    ✓ etc/${FOLDER}"
            FOUND=true
            break
        fi
        done
        ${FOUND} || log_warning "  ❌ ${FOLDER} not found"
    done
    
    # Copy media files
    for FILE in ${MEDIA_FILES}; do
        local FILE_FOUND=false
        for BASE in \
            "system_extracted/media/${FILE}" \
            "system_extracted/system/media/${FILE}" \
            "system_extracted/system_a/media/${FILE}" \
            "system_extracted/system/system/media/${FILE}" \
            "system_extracted/system_a/system/media/${FILE}"; do
        if [[ -f "${BASE}" ]]; then
            cp "${BASE}" "output/Apps/system/media/${FILE}"
            log_success "    ✓ media/${FILE}"
            FILE_FOUND=true
            break
        fi
        done
        ${FILE_FOUND} || log_warning "  ❌ ${FILE} not found"
    done
    
    # Copy lib64 files
    for FILE in ${LIB64_FILES}; do
        local FILE_FOUND=false
        for BASE in \
            "system_extracted/lib64/${FILE}" \
            "system_extracted/system/lib64/${FILE}" \
            "system_extracted/system_a/lib64/${FILE}" \
            "system_extracted/system/system/lib64/${FILE}" \
            "system_extracted/system_a/system/lib64/${FILE}"; do
        if [[ -f "${BASE}" ]]; then
            cp "${BASE}" "output/Apps/system/lib64/${FILE}"
            log_success "    ✓ lib64/${FILE}"
            FILE_FOUND=true
            break
        fi
        done
        ${FILE_FOUND} || log_warning "  ❌ ${FILE} not found"
    done
    
    # Copy framework JARs
    for JAR in ${FRAMEWORK_JARS}; do
        local JAR_FOUND=false
        for BASE in \
            "system_extracted/framework/${JAR}" \
            "system_extracted/system/framework/${JAR}" \
            "system_extracted/system_a/framework/${JAR}" \
            "system_extracted/system/system/framework/${JAR}" \
            "system_extracted/system_a/system/framework/${JAR}"; do
        if [[ -f "${BASE}" ]]; then
            cp "${BASE}" "output/Apps/system/framework/${JAR}"
            log_success "    ✓ framework/${JAR}"
            JAR_FOUND=true
            break
        fi
        done
        ${JAR_FOUND} || log_warning "  ❌ ${JAR} not found"
    done
    
    rm -rf system_extracted super_dump *.img
}

package_output() {
    log_info "Packaging..."
    cd output
    if [[ "${COMPRESSION_LEVEL}" != "0" ]]; then
        tar -cf - "Apps" | xz ${XZ_FLAGS} -T0 2>/dev/null > "Apps.tar.xz"
        rm -rf "Apps"
        log_success "    ✓ Apps.tar.xz"
    else
        zip -r "Apps.zip" "Apps" >/dev/null 2>&1
        rm -rf "Apps"
        log_success "    ✓ Apps.zip"
    fi
}

show_results() {
    echo ""; echo "═══════════════════════════════════════"
    FILE_COUNT=$(ls -1 2>/dev/null | wc -l)
    [[ "${FILE_COUNT}" -eq 0 ]] && { log_error "Nothing extracted!"; exit 1; }
    TOTAL_SIZE=$(du -sh . | cut -f1)
    log_success "Extracted ${FILE_COUNT} items"
    log_info "Total size: ${TOTAL_SIZE}"
    ls -lh
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
    extract_system_contents
    copy_extracted_files
    package_output
    show_results
}

main "$@"