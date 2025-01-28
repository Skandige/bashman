#!/bin/bash

# Список дисков, для которых нужно создать партицию, занимающую весь диск
disks=(
    "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" "sdo" "sdp"
    "sdq" "sdr" "sds" "sdt" "sdu" "sdv" "sdw" "sdx" "sdy" "sdz" "sdaa" "sdab"
)

# Файловая система
FS_TYPE="xfs"

# Базовый путь для монтирования
BASE_MOUNT=disk
# Начальный номер для каталога
COUNT=1

# Функция для создания партиции, занимающей весь диск
create_full_disk_partition() {
    local disk=$1
    echo "Creating full disk partition for /dev/$disk..."

    # Убедимся, что таблица разделов GPT установлена
    sudo parted -s "/dev/$disk" mklabel gpt

    if [ $? -ne 0 ]; then
        echo "Failed to set GPT label for /dev/$disk."
        return
    fi

    # Создаем партицию, занимающую весь диск
    sudo parted -s "/dev/$disk" mkpart primary 0% 100%

    if [ $? -eq 0 ]; then
        echo "Successfully created full disk partition for /dev/$disk."
    else
        echo "Failed to create partition for /dev/$disk."
    fi
}

# Функция для создания файловой системы на разделе
create_filesystem() {
    local part=$1
    echo "Создание файловой системы $FS_TYPE на $part..."
    sudo mkfs -t $FS_TYPE $part
    if [ $? -eq 0 ]; then
        echo "Файловая система на $part создана успешно."
    else
        echo "Ошибка при создании файловой системы на $part." >&2
    fi
}

# Функция для добавления записи в /etc/fstab и прописывания метки
add_to_fstab() {
    local disk=$1
    local mountpoint="/stat-data/${BASE_MOUNT}${COUNT}"
    local part="/dev/${disk}1"

    # Присваиваем метку разделу
    sudo xfs_admin -L ${BASE_MOUNT}${COUNT} $part
    LABEL=$(sudo xfs_admin -l $part | awk -F '"' '{print $2}')

    # Создаем директорию для монтирования
    sudo mkdir -p $mountpoint

    # Добавляем запись в /etc/fstab
    echo "Добавляем запись в /etc/fstab..."
    echo "LABEL=$LABEL $mountpoint $FS_TYPE defaults,nofail 0 2" | sudo tee -a /etc/fstab > /dev/null

    if [ $? -eq 0 ]; then
        echo "Запись для $part успешно добавлена в /etc/fstab."
    else
        echo "Ошибка при добавлении записи в /etc/fstab." >&2
    fi

    # Увеличиваем счётчик
    COUNT=$((COUNT + 1))
}

# Применяем функции ко всем дискам в списке
for disk in "${disks[@]}"; do
    create_full_disk_partition "$disk"
    PARTITION="/dev/${disk}1"

    # Ожидаем завершения операции создания партиции
    sleep 2

    create_filesystem "$PARTITION"
    add_to_fstab "$disk"
done

echo "Все диски обработаны. Не забудьте перезагрузить систему или выполнить 'mount -a' для применения изменений."
