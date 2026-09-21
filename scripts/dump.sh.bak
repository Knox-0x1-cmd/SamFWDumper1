#!/bin/bash
# =============================================================================
# SamFWDumper - Automated Samsung Firmware Extraction
# Copyright (C) 2026 Xiatsuma
# Licensed under PolyForm Noncommercial License 1.0.0
# https://polyformproject.org/licenses/noncommercial/1.0.0
#
# You may NOT use this file except in compliance with the License.
# Commercial use, removal of this header, or distribution without attribution
# is strictly prohibited. For permissions: https://github.com/Xiatsuma
# =============================================================================
set -euo pipefail

# =============================================================================
# Configuration & Constants
# =============================================================================
readonly SCRIPT_VERSION="2.1.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly REQUIRED_TOOLS=("wget" "unzip" "tar" "xz" "lz4" "numfmt" "find" "stat" "grep" "sed" "awk")
readonly OPTIONAL_TOOLS=("simg2img" "lpunpack" "lpdump" "debugfs" "xz" "lz4")
readonly SUPER_PARTS="system system_ext product vendor vendor_dlkm system_dlkm odm odm_dlkm"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
URL=""
COMPRESSION_LEVEL="6"
SELECTED_PARTITIONS=""
XZ_FLAGS="-6"
NEED_SUPER=false
CLEANUP_FILES=()
CLEANUP_DIRS=()
PROGRESS_PID=""

# =============================================================================
# Utility Functions
# =============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_step() { echo -e "\n${BLUE}[$1]${NC} $2"; }

show_progress() {
    local message="$1"
    echo -ne "\r${BLUE}[...]${NC} ${message}                    "
}

stop_progress() {
    echo -ne "\r${GREEN}[✓]${NC} Done!                                    \n"
}

cleanup_on_exit() {
    # Kill progress indicator if running
    if [[ -n "${PROGRESS_PID}" ]] && kill -0 "${PROGRESS_PID}" 2>/dev/null; then
        kill "${PROGRESS_PID}" 2>/dev/null || true
    fi

    # Clean up temporary files
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

check_tool() {
    local tool="$1"
    local required="${2:-true}"
    if ! command -v "${tool}" &>/dev/null; then
        if [[ "${required}" == "true" ]]; then
            log_error "Required tool '${tool}' not found"
            return 1
        else
            log_warning "Optional tool '${tool}' not found"
            return 1
        fi
    fi
    return 0
}

check_all_tools() {
    log_info "Checking required tools..."
    local missing=0
    for tool in "${REQUIRED_TOOLS[@]}"; do
        check_tool "${tool}" true || ((missing++))
    done
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        check_tool "${tool}" false || true
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; return 1; }
    log_success "All required tools available"
    return 0
}

validate_url() {
    local url="$1"
    [[ "${url}" =~ ^https?:// ]] || return 1
    [[ "${url}" =~ samfw\.com ]] || { log_warning "URL doesn't appear to be from samfw.com"; }
    return 0
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (6)"; XZ_FLAGS="-6" ;;
    esac
}

start_progress_spinner() {
    local message="$1"
    (
        local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while true; do
            printf "\r${BLUE}[%c]${NC} %s" "${spin:i++%${#spin}:1}" "${message}"
            sleep 0.1
        done
    ) &
    PROGRESS_PID=$!
}

stop_progress_spinner() {
    if [[ -n "${PROGRESS_PID}" ]] && kill -0 "${PROGRESS_PID}" 2>/dev/null; then
        kill "${PROGRESS_PID}" 2>/dev/null || true
        wait "${PROGRESS_PID}" 2>/dev/null || true
    fi
    PROGRESS_PID=""
}

cleanup_on_exit() {
    # Kill progress indicator if running
    if [[ -n "${PROGRESS_PID}" ]] && kill -0 "${PROGRESS_PID}" 2>/dev/null; then
        kill "${PROGRESS_PID}" 2>/dev/null || true
    fi

    # Clean up temporary files
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

check_tool() {
    local tool="$1"
    local required="${2:-true}"
    if ! command -v "${tool}" &>/dev/null; then
        if [[ "${required}" == "true" ]]; then
            log_error "Required tool '${tool}' not found"
            return 1
        else
            log_warning "Optional tool '${tool}' not found"
            return 1
        fi
    fi
    return 0
}

check_all_tools() {
    log_info "Checking required tools..."
    local missing=0
    for tool in "${REQUIRED_TOOLS[@]}"; do
        check_tool "${tool}" true || ((missing++))
    done
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        check_tool "${tool}" false || true
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; return 1; }
    log_success "All required tools available"
    return 0
}

validate_url() {
    local url="$1"
    [[ "${url}" =~ ^https?:// ]] || return 1
    [[ "${url}" =~ samfw\.com ]] || { log_warning "URL doesn't appear to be from samfw.com"; }
    return 0
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (6)"; XZ_FLAGS="-6" ;;
    esac
}

start_progress_spinner() {
    local message="$1"
    (
        local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while true; do
            printf "\r${BLUE}[%c]${NC} %s" "${spin:i++%${#spin}:1}" "${message}"
            sleep 0.1
        done
    ) &
    PROGRESS_PID=$!
}

stop_progress_spinner() {
    if [[ -n "${PROGRESS_PID}" ]] && kill -0 "${PROGRESS_PID}" 2>/dev/null; then
        kill "${PROGRESS_PID}" 2>/dev/null || true
        wait "${PROGRESS_PID}" 2>/dev/null || true
    fi
    PROGRESS_PID=""
}

cleanup_on_exit() {
    # Kill progress indicator if running
    if [[ -n "${PROGRESS_PID}" ]] && kill -0 "${PROGRESS_PID}" 2>/dev/null; then
        kill "${PROGRESS_PID}" 2>/dev/null || true
    fi

    # Clean up temporary files
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

check_tool() {
    local tool="$1"
    local required="${2:-true}"
    if ! command -v "${tool}" &>/dev/null; then
        if [[ "${required}" == "true" ]]; then
            log_error "Required tool '${tool}' not found"
            return 1
        else
            log_warning "Optional tool '${tool}' not found"
            return 1
        fi
    fi
    return 0
}

check_all_tools() {
    log_info "Checking required tools..."
    local missing=0
    for tool in "${REQUIRED_TOOLS[@]}"; do
        check_tool "${tool}" true || ((missing++))
    end
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        check_tool "${tool}" false || true
    done
    [[ ${missing} -eq 0 ]] || { log_error "Missing ${missing} required tool(s)"; return 1; }
    log_success "All required tools available"
    return 0
}

validate_url() {
    local url="$1"
    [[ "${url}" =~ ^https?:// ]] || return 1
    [[ "${url}" =~ samfw\.com ]] || { log_warning "URL doesn't appear to be from samfw.com"; }
    return 0
}

parse_compression() {
    local level="$1"
    case "${level}" in
        0) XZ_FLAGS="-0" ;;
        3) XZ_FLAGS="-3" ;;
        6) XZ_FLAGS="-6" ;;
        9) XZ_FLAGS="-9" ;;
        *) log_warning "Invalid compression level '${level}', using default (6)"; XZ_FLAGS="-6" ;;
    esac
}

start_progress_spinner() {
    local message="$1"
    (
        local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while true; do
            printf "\r${BLUE}[%c]${NC} %s" "${spin:i++%${#spin}:1}" "${message}"
            sleep 0.1
        done
    ) &
    PROGRESS_PID=$!
}

stop_progress_spinner() {
    if [[ -n "${PROGRESS_PID}" ]] && kill -0 "${PROGRESS_PID}" 2>/dev/null; then
        kill "${PROGRESS_PID}" 2>/dev/null || true
        wait "${PROGRESS_PID}" 2>/dev/null || true
    fi
    PROGRESS_PID=""
}

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
    COMPRESSION_LEVEL="${2:-6}"
    SELECTED_PARTITIONS="${3:-}"

    [[ -z "${URL}" ]] && { log_error "No URL provided"; exit 1; }
    [[ -z "${SELECTED_PARTITIONS}" ]] && { log_error "No partitions selected"; exit 1; }

    validate_url "${URL}" || { log_error "Invalid URL"; exit 1; }
    parse_compression "${COMPRESSION_LEVEL}"

    log_info "URL: ${URL}"
    log_info "Compression level: ${COMPRESSION_LEVEL}"
    log_info "Partitions: ${SELECTED_PARTITIONS}"
}

check_super_requirement() {
    NEED_SUPER=false
    for PART in ${SELECTED_PARTITIONS}; do
        for SP in ${SUPER_PARTS}; do
            if [[ "${PART}" == "${SP}" ]]; then
                NEED_SUPER=true
                return 0
            fi
        done
    done
}

download_firmware() {
    log_step "1/5" "Downloading firmware..."
    
    start_progress_spinner "Downloading firmware..."
    wget --no-check-certificate --content-disposition "${URL}" 2>&1 | tail -3
    stop_progress_spinner
    
    ZIP_FILE=$(ls -t *.zip 2>/dev/null | head -1)
    [[ -f "${ZIP_FILE}" ]] || { log_error "Download failed"; exit 1; }
    
    local FILESIZE=$(stat -c%s "${ZIP_FILE}")
    [[ "${FILESIZE}" -eq 0 ]] && { log_error "Empty file downloaded"; exit 1; }
    
    log_success "Downloaded: $(numfmt --to=iec ${FILESIZE})"
    
    register_cleanup_file "${ZIP_FILE}"
}

extract_firmware_info() {
    CSC_CODE=$(echo "${ZIP_FILE}" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z]{3}$' | grep -v -E '^(COM|SAM|FAC)$' | head -1)
    AP_CODE=$(echo "${ZIP_FILE}" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z][A-Z0-9]{11,}$' | head -1)
    
    [[ -n "${CSC_CODE}" ]] && echo "${CSC_CODE}" > csc_code.txt
    [[ -n "${AP_CODE}" ]] && echo "${AP_CODE}" > ap_code.txt
    
    log_info "Firmware: ${AP_CODE:-Unknown} | CSC: ${CSC_CODE:-Unknown}"
    register_cleanup_file "csc_code.txt"
    register_cleanup_file "ap_code.txt"
}

extract_zip() {
    log_step "2/5" "Extracting ZIP..."
    
    start_progress_spinner "Extracting ZIP..."
    unzip -o "${ZIP_FILE}" >/dev/null 2>&1
    stop_progress_spinner
    
    rm -f "${ZIP_FILE}"
    log_success "ZIP extracted"
}

extract_ap() {
    log_step "3/5" "Extracting AP tar..."
    
    AP_FILE=$(find . -maxdepth 1 \( -name "AP_*.tar.md5" -o -name "AP_*.tar" \) | head -n 1)
    [[ -z "${AP_FILE}" ]] && { log_error "AP file not found"; exit 1; }
    
    log_info "Extracting: $(basename "${AP_FILE}")"
    
    start_progress_spinner "Extracting AP tar..."
    
    local EXTRACT_ARGS=()
    for PART in ${SELECTED_PARTITIONS}; do
        EXTRACT_ARGS+=("*${PART}.img*" "*${PART}_a.img*" "*${PART}_b.img*")
    done
    ${NEED_SUPER} && EXTRACT_ARGS+=("*super.img*")
    
    if tar --no-anchored --wildcards -xf "${AP_FILE}" "${EXTRACT_ARGS[@]}" 2>/dev/null; then
        log_success "Selected partitions extracted"
    else
        log_warning "Wildcard extraction failed, trying full extraction..."
        tar -xf "${AP_FILE}" >/dev/null 2>&1 || { log_error "Failed to extract AP"; exit 1; }
        log_success "Full extraction completed"
    fi
    
    rm -f "${AP_FILE}"
    log_success "AP extraction completed"
}

extract_individual_partitions() {
    log_step "4/5" "Extracting individual partitions..."
    
    mkdir -p processed
    register_cleanup_dir "processed"
    
    local extracted_count=0
    
    for PART in ${SELECTED_PARTITIONS}; do
        if [[ -f "processed/${PART}.img.xz" ]] || \
           [[ -f "processed/${PART}_a.img.xz" ]] || \
           [[ -f "processed/${PART}_b.img.xz" ]]; then
            log_info "Partition ${PART} already processed, skipping"
            ((extracted_count++))
            continue
        fi
        
        local FILE
        FILE=$(find . -maxdepth 1 \( \
            -name "${PART}.img.lz4" -o -name "${PART}.img" \
            -o -name "${PART}_a.img.lz4" -o -name "${PART}_a.img" \
            -o -name "${PART}_b.img.lz4" -o -name "${PART}_b.img" \) | head -n 1)
        
        if [[ -n "${FILE}" && -f "${FILE}" ]]; then
            log_info "  ✓ Found: $(basename "${FILE}")"
            
            if [[ "${FILE}" == *.lz4 ]]; then
                log_info "    Decompressing LZ4..."
                lz4 -d "${FILE}" "${FILE%.lz4}" 2>/dev/null || { log_error "LZ4 decompression failed for ${FILE}"; continue; }
                FILE="${FILE%.lz4}"
            fi
            
            local BASENAME=$(basename "${FILE}")
            if xz ${XZ_FLAGS} -T0 "${FILE}" 2>/dev/null; then
                mv "${FILE}.xz" "processed/${BASENAME}.xz"
            else
                cp "${FILE}" "processed/${BASENAME}"
            fi
            ((extracted_count++))
        else
            log_warning "  ⚠ Partition ${PART} not found"
        fi
    done
    
    log_success "Individual partitions processed: ${extracted_count}/${#SELECTED_PARTITIONS[@]}"
}

extract_super_partitions() {
    [[ "${NEED_SUPER}" != "true" ]] && return 0
    
    log_step "4/5 (cont.)" "Processing super.img..."
    
    local SUPER_FILE
    SUPER_FILE=$(find . -maxdepth 1 \( -name "super.img*" -o -name "super.img" \) | head -n 1)
    
    [[ -z "${SUPER_FILE}" ]] && { log_warning "super.img not found"; return 0; }
    [[ ! -f "${SUPER_FILE}" ]] && { log_warning "super.img not found"; return 0; }
    
    if [[ "${SUPER_FILE}" == *.lz4 ]]; then
        log_info "Decompressing LZ4..."
        lz4 -d "${SUPER_FILE}" "super.img" 2>/dev/null || { log_error "LZ4 decompression failed"; return 1; }
        SUPER_FILE="super.img"
    fi
    
    if file "${SUPER_FILE}" 2>/dev/null | grep -q "sparse"; then
        log_info "Converting sparse image..."
        if command -v simg2img &>/dev/null; then
            simg2img "${SUPER_FILE}" "super.raw.img" 2>/dev/null
        elif [[ -f "tools/android-tools/simg2img" ]]; then
            tools/android-tools/simg2img "${SUPER_FILE}" "super.raw.img" 2>/dev/null
        else
            log_error "simg2img not found"
            return 1
        fi
        [[ -f "super.raw.img" ]] && SUPER_FILE="super.raw.img"
    fi
    
    register_cleanup_file "super.img"
    register_cleanup_file "super.raw.img"
    
    log_info "Extracting dynamic partitions..."
    mkdir -p super_dump
    register_cleanup_dir "super_dump"
    
    if [[ -f "tools/android-tools/lpunpack" ]]; then
        tools/android-tools/lpunpack "${SUPER_FILE}" super_dump 2>/dev/null || { log_error "lpunpack failed"; return 1; }
    else
        log_error "lpunpack not found"
        return 1
    fi
    
    log_info "Compressing ONLY selected partitions from super..."
    local extracted_count=0
    
    for PART in ${SELECTED_PARTITIONS}; do
        for SUFFIX in "_a" "" "_b"; do
            IMG_FILE="super_dump/${PART}${SUFFIX}.img"
            if [[ -f "${IMG_FILE}" ]]; then
                BASENAME="${PART}${SUFFIX}.img"
                log_info "    ✓ ${BASENAME}"
                if xz ${XZ_FLAGS} -T0 "${IMG_FILE}" 2>/dev/null; then
                    mv "${IMG_FILE}.xz" "processed/${BASENAME}.xz"
                else
                    cp "${IMG_FILE}" "processed/${BASENAME}"
                fi
                ((extracted_count++))
                break
            fi
        done
    done
    
    rm -rf super_dump super.img super.raw.img
    log_success "Super partitions processed: ${extracted_count}"
}

show_results() {
    log_step "5/5" "Results:"
    cd processed
    
    local FILE_COUNT=$(ls -1 2>/dev/null | wc -l)
    [[ "${FILE_COUNT}" -eq 0 ]] && { log_error "Nothing extracted!"; exit 1; }
    
    local TOTAL_SIZE=$(du -sh . | cut -f1)
    
    echo "═══════════════════════════════════════"
    log_success "Extracted $FILE_COUNT partitions"
    log_info "Total size: ${TOTAL_SIZE}"
    log_info "Compression: Level ${COMPRESSION_LEVEL}"
    echo
    log_info "Files:"
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
    check_super_requirement
    
    download_firmware
    extract_firmware_info
    extract_zip
    extract_ap
    extract_individual_partitions
    extract_super_partitions
    show_results
}

main "$@"