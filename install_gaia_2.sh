#!/bin/bash

NEON_BLUE='\033[38;5;45m'
NEON_RED='\033[38;5;196m'
RESET='\033[0m'

# Логотип
logo() {
    echo -e "
${NEON_RED}  ____   ${NEON_BLUE}____  
${NEON_RED} |  _ \\  ${NEON_BLUE}|  _ \\ 
${NEON_RED} | | | | ${NEON_BLUE}| |_) |
${NEON_RED} | |_| | ${NEON_BLUE}|  __/ 
${NEON_RED} |____/  ${NEON_BLUE}|_|    
${NEON_RESET}
"
}

# Вызов логотипа

set -e

# Получаем номер ноды от пользователя
echo -e "${NEON_BLUE}Введите номер ноды (например, 2): ${RESET}"

# Чтение ввода
read NODE_NUMBER

# Для первой ноды устанавливаем параметры
if [ "$NODE_NUMBER" -eq 1 ]; then
    NODE_DIR="/root/gaianet"
    LLAMAEDGE_PORT=8080
    SERVICE_FILE="/etc/systemd/system/gaianet.service"
    SESSION_NAME="gaianet1"
    NODE_NAME="gaianet"
else
    NODE_DIR="/root/gaianet-$NODE_NUMBER"
    LLAMAEDGE_PORT=$((8080 + (NODE_NUMBER - 1) * 5))
    SERVICE_FILE="/etc/systemd/system/gaianet-$NODE_NUMBER.service"
    SESSION_NAME="gaianet$NODE_NUMBER"
    NODE_NAME="gaianet-$NODE_NUMBER"
fi


# Проверяем наличие директории
if [ ! -d "$NODE_DIR" ]; then
  echo "Директория $NODE_DIR не найдена. Убедитесь, что вы выполнили первый скрипт."
  exit 1
fi

# Инициализируем ноду
gaianet init --config "https://raw.githubusercontent.com/GaiaNet-AI/node-configs/main/qwen-1.5-0.5b-chat/config.json" --base $NODE_DIR

# Настраиваем порт в конфигурации
sed -i "s/\"llamaedge_port\": \"8080\"/\"llamaedge_port\": \"$LLAMAEDGE_PORT\"/" "$NODE_DIR/config.json"

# Настраиваем службу systemd
cat <<EOL | sudo tee $SERVICE_FILE
[Unit]
Description=Gaianet Node Service $NODE_NUMBER
After=network.target

[Service]
Type=forking
RemainAfterExit=true
ExecStart=$NODE_DIR/bin/gaianet start --base $NODE_DIR
ExecStop=$NODE_DIR/bin/gaianet stop --base $NODE_DIR
ExecStopPost=/bin/sleep 20
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOL

sleep 5 

# Применяем изменения
sudo systemctl daemon-reload
sudo systemctl restart $NODE_NAME.service
sudo systemctl enable $NODE_NAME.service

# Сохраняем информацию о ноде
gaianet info > "$NODE_DIR/gaianet_info.txt"
NODE_ID=$(grep 'Node ID:' "$NODE_DIR/gaianet_info.txt" | awk '{print $3}' | sed 's/[^a-zA-Z0-9]//g' | cut -c1-42)



# Инструкция для пользователя с перекрашиванием в неоновый красный
echo -e "${NEON_BLUE}"
cat << EOF
Установка завершена!
- Node ID: $NODE_ID
- Конфигурация сохранена в: $NODE_DIR/config.json
- Лог общения: chat_log_$NODE_NUMBER.txt

Для подключения к screen-сессии:

  screen -r $SESSION_NAME 

Чтобы выйти из сессии, не останавливая скрипт:
  Нажмите Ctrl+A, затем D.
EOF
echo -e "${RESET}"

