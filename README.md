# my-scripts

Публичные скрипты для домашней лаборатории.

## Proxmox

### create-ci-interactive.sh

Создаёт Cloud-Init шаблон **Ubuntu 26.04 LTS** в Proxmox с UEFI-загрузкой.

**Основано на:** [RomNero/YouTube-Infos](https://github.com/RomNero/YouTube-Infos)

**Что делает:**
- Скачивает Ubuntu 26.04 Cloud Image
- Создаёт VM с UEFI (OVMF), CPU `x86-64-v2-AES`, QEMU agent
- Настраивает Cloud-Init (пользователь, IP)
- Превращает VM в шаблон для клонирования
- Поддерживает VLAN tag (опционально)

**Использование:**

```bash
cd /root
wget https://raw.githubusercontent.com/a-yspv/my-scripts/main/proxmox/create-ci-interactive.sh
chmod +x create-ci-interactive.sh
./create-ci-interactive.sh
