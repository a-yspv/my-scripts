#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Proxmox Ubuntu 26.04 LTS Cloud-Init Template Creator
#
# Based on script by RomNero:
#   https://github.com/RomNero/YouTube-Infos
#
# Behavior:
#  - If started with no arguments -> interactive menu
#  - Option 1 -> run with default values
#  - Option 2 -> interactive configuration
#  - Option --default -> run with defaults directly
#
# Modified for Ubuntu 26.04 LTS (Resolute Raccoon):
#  - UEFI boot (OVMF + q35 + efidisk0) — required by 26.04 cloud images
#  - CPU x86-64-v2-AES — AES-NI + modern instructions, but portable
#  - QEMU Guest Agent enabled
#  - Optional VLAN tag
# ------------------------------------------------------------------------------

# -----------------------------
# Default values
# -----------------------------
VMID=9998
VM_NAME="ubuntu-2604-ci"

MEMORY_MB=4096
CORES=2
CPU_TYPE="x86-64-v2-AES"

BRIDGE="vmbr0"
VLAN_TAG=""
NET_MODEL="virtio"

STORAGE="local-lvm"

ISO_DIR="/var/lib/vz/template/iso"

UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img"
UBUNTU_IMG_FILE="ubuntu-26.04-server-cloudimg-amd64.img"

CI_USER="ubuntu"
IPCONFIG0="ip=dhcp"

DISK_RESIZE="+10G"

# -----------------------------
# Helper: ask question with default
# -----------------------------
ask() {
    local prompt=$1
    local default=$2
    read -p "$prompt [$default]: " value
    echo "${value:-$default}"
}

# -----------------------------
# Interactive configuration
# -----------------------------
interactive_config() {

    echo ""
    echo "Configure VM parameters (press ENTER to use default value)"
    echo ""

    VMID=$(ask "VM ID" "$VMID")
    VM_NAME=$(ask "VM Name" "$VM_NAME")
    MEMORY_MB=$(ask "RAM (MB)" "$MEMORY_MB")
    CORES=$(ask "CPU Cores" "$CORES")
    CPU_TYPE=$(ask "CPU Type" "$CPU_TYPE")
    BRIDGE=$(ask "Network Bridge" "$BRIDGE")
    VLAN_TAG=$(ask "VLAN Tag (empty = no tag)" "$VLAN_TAG")
    STORAGE=$(ask "Storage" "$STORAGE")
    CI_USER=$(ask "Cloud-init User" "$CI_USER")
    IPCONFIG0=$(ask "IP Config (e.g. ip=dhcp or ip=192.168.1.10/24,gw=192.168.1.1)" "$IPCONFIG0")
    DISK_RESIZE=$(ask "Disk Resize" "$DISK_RESIZE")
}

# -----------------------------
# Help / Menu
# -----------------------------
menu() {

    echo ""
    echo "Proxmox Ubuntu 26.04 Cloud-Init Template Script"
    echo "-----------------------------------------------"
    echo ""
    echo "1) Install with default settings"
    echo "2) Customize parameters"
    echo "3) Exit"
    echo ""

    read -p "Select option: " choice

    case $choice in
        1)
            echo "Running with default settings..."
            ;;
        2)
            interactive_config
            ;;
        *)
            echo "Exit."
            exit 0
            ;;
    esac
}

# -----------------------------
# Parameter handling
# -----------------------------
if [[ $# -eq 0 ]]; then
    menu
fi

if [[ "${1:-}" == "--default" ]]; then
    echo "Running with default configuration..."
fi

# -----------------------------
# Preflight checks
# -----------------------------
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root."
  exit 1
fi

command -v qm >/dev/null || { echo "qm command not found"; exit 1; }
command -v wget >/dev/null || { echo "wget not found"; exit 1; }

UBUNTU_IMG_PATH="$ISO_DIR/$UBUNTU_IMG_FILE"

mkdir -p "$ISO_DIR"

# -----------------------------
# Download cloud image
# -----------------------------
if [[ ! -f "$UBUNTU_IMG_PATH" ]]; then
    echo "Downloading Ubuntu 26.04 Cloud Image..."
    wget -O "$UBUNTU_IMG_PATH" "$UBUNTU_IMG_URL"
else
    echo "Cloud image already exists."
fi

# -----------------------------
# Build network string (with optional VLAN tag)
# -----------------------------
if [[ -n "$VLAN_TAG" ]]; then
    NET_STRING="${NET_MODEL},bridge=${BRIDGE},tag=${VLAN_TAG}"
else
    NET_STRING="${NET_MODEL},bridge=${BRIDGE}"
fi

# -----------------------------
# Create VM
# -----------------------------
echo "Creating VM $VMID..."

qm create "$VMID" \
  --name "$VM_NAME" \
  --memory "$MEMORY_MB" \
  --cores "$CORES" \
  --cpu "$CPU_TYPE" \
  --agent enabled=1 \
  --machine q35 \
  --bios ovmf \
  --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=1" \
  --net0 "$NET_STRING"

# -----------------------------
# Import disk
# -----------------------------
echo "Importing disk..."

qm importdisk "$VMID" "$UBUNTU_IMG_PATH" "$STORAGE"

IMPORTED_VOL="${STORAGE}:vm-${VMID}-disk-0"

# -----------------------------
# Configure disk
# -----------------------------
qm set "$VMID" \
  --scsihw virtio-scsi-single \
  --scsi0 "${IMPORTED_VOL},discard=on"

# -----------------------------
# Add cloud-init drive
# -----------------------------
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"

# -----------------------------
# Boot configuration
# -----------------------------
qm set "$VMID" --boot c --bootdisk scsi0

# -----------------------------
# Resize disk
# -----------------------------
qm resize "$VMID" scsi0 "$DISK_RESIZE"

# -----------------------------
# Cloud-init defaults
# -----------------------------
qm set "$VMID" --ciuser "$CI_USER"
qm set "$VMID" --ipconfig0 "$IPCONFIG0"

# -----------------------------
# Convert to template
# -----------------------------
echo "Converting VM to template..."

qm template "$VMID"

echo ""
echo "Template successfully created!"
echo "VMID: $VMID"
echo "Name: $VM_NAME"
echo "CPU: $CPU_TYPE"
echo "BIOS: OVMF (UEFI)"
echo "User: $CI_USER"
if [[ -n "$VLAN_TAG" ]]; then
    echo "VLAN: $VLAN_TAG"
fi
