#!/usr/bin/env bash
# Build/install out-of-tree Intel i915 (intel-i915-dkms) for the running kernel
# and bind it to unbound Intel GPUs (e.g. 8086:0bda) so Level Zero / sycl-ls
# can see them.
#
# Usage:
#   sudo install-intel-i915-dkms.sh           # build, install, load, bind, verify
#   sudo install-intel-i915-dkms.sh --verify  # status only
#   sudo install-intel-i915-dkms.sh --load    # load/bind only (module already installed)
#
# Requires: intel-i915-dkms package, linux-headers-$(uname -r), root.

set -euo pipefail

MODULE_PKG="intel-i915-dkms"
KERNEL="$(uname -r)"
ARCH="$(uname -m)"
# PCI IDs that need the OOT driver on this host (PVC / related); extend as needed.
INTEL_GPU_PCI_IDS_RE='8086:(0bd5|0bd6|0bd7|0bd8|0bd9|0bda|0bdb)'

MODE="all" # all | verify | load
for arg in "$@"; do
  case "$arg" in
    --verify|-V) MODE="verify" ;;
    --load|-L) MODE="load" ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "run as root (e.g. sudo $0)"
  fi
}

detect_dkms_version() {
  local ver="" src
  # Prefer the version directory under /var/lib/dkms (authoritative once added).
  if [[ -d "/var/lib/dkms/${MODULE_PKG}" ]]; then
    ver="$(find "/var/lib/dkms/${MODULE_PKG}" -mindepth 1 -maxdepth 1 -type d \
      ! -name 'kernel-*' -printf '%f\n' 2>/dev/null | sort -V | tail -1 || true)"
  fi
  if [[ -n "${ver}" ]]; then
    echo "${ver}"
    return 0
  fi
  # Fall back to /usr/src tree from the deb.
  src="$(ls -d /usr/src/intel-i915-dkms-* 2>/dev/null | sort -V | tail -1 || true)"
  [[ -n "${src}" ]] || return 1
  basename "${src}" | sed 's/^intel-i915-dkms-//'
}

headers_ok() {
  [[ -d "/lib/modules/${KERNEL}/build" ]] \
    && [[ -e "/lib/modules/${KERNEL}/build/.config" ]]
}

ensure_headers() {
  if headers_ok; then
    log "Kernel headers OK for ${KERNEL}"
    return 0
  fi
  log "Installing linux-headers-${KERNEL} ..."
  apt-get install -y "linux-headers-${KERNEL}" \
    || die "failed to install linux-headers-${KERNEL}; install manually then re-run"
  headers_ok || die "headers still missing after apt install"
}

# Ubuntu 5.15.0-204+ changed pci_resize_resource() to take exclude_bars.
# Older intel-i915-dkms still calls the 3-arg form and fails to build.
kernel_has_pci_resize_exclude_bars() {
  local hdr="/lib/modules/${KERNEL}/build/include/linux/pci.h"
  [[ -f "${hdr}" ]] && grep -q 'exclude_bars' "${hdr}"
}

patch_pci_resize_for_ubuntu204() {
  local ver="$1"
  local src="/usr/src/${MODULE_PKG}-${ver}/drivers/gpu/drm/i915/i915_driver.c"
  [[ -f "${src}" ]] || die "missing ${src}"

  if ! kernel_has_pci_resize_exclude_bars; then
    log "Kernel pci_resize_resource is 3-arg; no source patch needed"
    return 0
  fi

  if grep -q 'pci_resize_resource(pdev, resno, bar_size, 0)' "${src}"; then
    log "i915_driver.c already patched for exclude_bars"
    return 0
  fi

  if ! grep -q 'pci_resize_resource(pdev, resno, bar_size);' "${src}"; then
    die "unexpected pci_resize_resource call site in ${src}; update script"
  fi

  log "Patching ${src} for Ubuntu pci_resize_resource(..., exclude_bars)"
  # exclude_bars=0: BARs already released by __release_bars() just above.
  sed -i 's/pci_resize_resource(pdev, resno, bar_size);/pci_resize_resource(pdev, resno, bar_size, 0);/' \
    "${src}"
  grep -n 'pci_resize_resource(pdev, resno, bar_size' "${src}" || true
}

# Ubuntu 5.15.0-204+ renamed dma_resv_reserve_shared -> dma_resv_reserve_fences
# while keeping LINUX_VERSION at 5.15, so intel-i915-dkms BPM macros (gated on
# >=5.19) do not enable the existing backport alias.
kernel_lacks_dma_resv_reserve_shared() {
  local hdr="/lib/modules/${KERNEL}/build/include/linux/dma-resv.h"
  [[ -f "${hdr}" ]] || return 1
  grep -q 'dma_resv_reserve_fences' "${hdr}" \
    && ! grep -q 'dma_resv_reserve_shared' "${hdr}"
}

patch_dma_resv_reserve_shared_alias() {
  local ver="$1"
  local hdr="/usr/src/${MODULE_PKG}-${ver}/backport-include/linux/dma-resv.h"
  [[ -f "${hdr}" ]] || die "missing ${hdr}"

  if ! kernel_lacks_dma_resv_reserve_shared; then
    log "Kernel still provides dma_resv_reserve_shared; no alias patch needed"
    return 0
  fi

  if grep -q 'CURSOR_FORCE_DMA_RESV_RESERVE_SHARED_ALIAS' "${hdr}"; then
    log "dma-resv.h already patched for reserve_shared alias"
    return 0
  fi

  log "Patching ${hdr}: alias dma_resv_reserve_shared -> dma_resv_reserve_fences"
  # Insert an unconditional alias after include_next, in addition to the BPM one.
  # Marker comment makes the patch idempotent.
  sed -i '/#include_next <linux\/dma-resv.h>/a\
\
/* CURSOR_FORCE_DMA_RESV_RESERVE_SHARED_ALIAS */\
/* Ubuntu 5.15.0-204+ removed dma_resv_reserve_shared without bumping version. */\
#ifndef BPM_DMA_RESV_RESERVE_SHARED_NOT_PRESENT\
#define BPM_DMA_RESV_RESERVE_SHARED_NOT_PRESENT\
#endif
' "${hdr}"
}

dkms_installed_for_kernel() {
  local ver="$1"
  # Prefer filesystem check; `dkms status` is noisy when old kernel configs are gone.
  local installed_ko="/lib/modules/${KERNEL}/updates/dkms/i915.ko"
  local alt_ko="/lib/modules/${KERNEL}/updates/i915.ko"
  if [[ -e "${installed_ko}" || -e "${alt_ko}" ]]; then
    return 0
  fi
  dkms status -m "${MODULE_PKG}" -v "${ver}" -k "${KERNEL}" 2>/dev/null \
    | grep -Eqi 'installed'
}

build_and_install() {
  local ver="$1"

  if ! dpkg -s "${MODULE_PKG}" >/dev/null 2>&1; then
    die "package ${MODULE_PKG} is not installed (apt install ${MODULE_PKG})"
  fi

  # Register source if DKMS only has the deb tree.
  if ! dkms status -m "${MODULE_PKG}" -v "${ver}" >/dev/null 2>&1; then
    log "dkms add ${MODULE_PKG}/${ver}"
    dkms add -m "${MODULE_PKG}" -v "${ver}"
  fi

  if dkms_installed_for_kernel "${ver}"; then
    log "${MODULE_PKG}/${ver} already installed for ${KERNEL}"
    return 0
  fi

  patch_pci_resize_for_ubuntu204 "${ver}"
  patch_dma_resv_reserve_shared_alias "${ver}"

  # Drop a failed prior build tree so the patched sources are picked up cleanly.
  rm -rf "/var/lib/dkms/${MODULE_PKG}/${ver}/build" || true

  log "dkms build ${MODULE_PKG}/${ver} -k ${KERNEL} (this can take several minutes)"
  if ! dkms build -m "${MODULE_PKG}" -v "${ver}" -k "${KERNEL}"; then
    local logf="/var/lib/dkms/${MODULE_PKG}/${ver}/${KERNEL}/${ARCH}/log/make.log"
    [[ -f "${logf}" ]] || logf="/var/lib/dkms/${MODULE_PKG}/${ver}/build/make.log"
    die "dkms build failed; see ${logf}"
  fi

  log "dkms install ${MODULE_PKG}/${ver} -k ${KERNEL}"
  dkms install -m "${MODULE_PKG}" -v "${ver}" -k "${KERNEL}"

  log "depmod ${KERNEL}"
  depmod -a "${KERNEL}"
}

load_modules() {
  # Out-of-tree stack: compat first, then i915 (and helpers if present).
  local mods=(i915-compat i915 i915_spi iaf)
  local m
  for m in "${mods[@]}"; do
    if modinfo "${m}" >/dev/null 2>&1; then
      log "modprobe ${m}"
      modprobe "${m}" || log "warning: modprobe ${m} failed (continuing)"
    fi
  done
}

pci_gpu_bdfs() {
  lspci -Dn | awk -v re="${INTEL_GPU_PCI_IDS_RE}" '
    tolower($0) ~ tolower(re) { print $1 }
  '
}

bind_unbound_gpus() {
  local bdf driver_link bind_path
  bind_path="/sys/bus/pci/drivers/i915/bind"
  if [[ ! -e "${bind_path}" ]]; then
    die "i915 driver sysfs not present; module did not load"
  fi

  while read -r bdf; do
    [[ -n "${bdf}" ]] || continue
    driver_link="/sys/bus/pci/devices/${bdf}/driver"
    if [[ -e "${driver_link}" ]]; then
      log "PCI ${bdf} already bound to $(basename "$(readlink -f "${driver_link}")")"
      continue
    fi
    log "Binding ${bdf} to i915"
    # Newline required by sysfs bind.
    if ! echo "${bdf}" >"${bind_path}"; then
      log "warning: bind ${bdf} failed"
    fi
  done < <(pci_gpu_bdfs)

  # Nudge udev in case nodes appear asynchronously.
  if command -v udevadm >/dev/null 2>&1; then
    udevadm trigger --subsystem-match=drm --action=add || true
    udevadm settle --timeout=15 || true
  fi
}

verify() {
  local rc=0
  log "=== Verification ==="
  echo "Kernel: ${KERNEL}"
  echo
  echo "DKMS:"
  dkms status -m "${MODULE_PKG}" 2>/dev/null | grep "${KERNEL}" || {
    echo "  (no ${MODULE_PKG} entry for ${KERNEL})"
    rc=1
  }
  echo
  echo "Loaded modules:"
  lsmod | grep -E '^(i915|i915_compat)\b' || {
    echo "  (i915 / i915_compat not loaded)"
    rc=1
  }
  echo
  echo "PCI GPUs (want Kernel driver in use: i915):"
  local bdf
  while read -r bdf; do
    [[ -n "${bdf}" ]] || continue
    lspci -s "${bdf#0000:}" -nnk || true
    if [[ ! -e "/sys/bus/pci/devices/${bdf}/driver" ]]; then
      echo "  -> UNBOUND"
      rc=1
    fi
  done < <(pci_gpu_bdfs)
  echo
  echo "/dev/dri:"
  ls -la /dev/dri/ 2>/dev/null || true
  if ! ls /dev/dri/renderD* >/dev/null 2>&1; then
    echo "  -> no renderD* nodes (Level Zero needs these)"
    rc=1
  fi
  echo
  if command -v sycl-ls >/dev/null 2>&1; then
    echo "sycl-ls:"
    # Do not fail the script solely on sycl-ls; print for the operator.
    sycl-ls 2>&1 | head -40 || true
  fi
  return "${rc}"
}

main() {
  need_root

  case "${MODE}" in
    verify)
      verify
      exit $?
      ;;
    load)
      load_modules
      bind_unbound_gpus
      verify
      exit $?
      ;;
    all)
      ensure_headers
      local ver
      ver="$(detect_dkms_version)" \
        || die "cannot find ${MODULE_PKG} (is the package installed?)"
      log "Using ${MODULE_PKG} version ${ver}"
      build_and_install "${ver}"
      load_modules
      bind_unbound_gpus
      if verify; then
        log "SUCCESS: Intel GPU DRM nodes should be available for Level Zero / SYCL"
        exit 0
      else
        log "COMPLETED WITH WARNINGS: see verification above (dmesg | grep -i i915)"
        exit 1
      fi
      ;;
  esac
}

main "$@"
