#!/bin/bash

# Название файла для Python скрипта
PYTHON_SCRIPT_NAME="request_script.py"
VENV_DIR="venv"
FAKER_SESSION_LIMIT=5

# Проверка, запущен ли скрипт с правами суперпользователя
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с правами суперпользователя (sudo)."
    exit 1
fi

# Проверка, установлен ли Python, и установка, если он не установлен
if ! command -v python3 &> /dev/null; then
    echo "Python3 не найден, устанавливаем..."
    apt update
    apt install python3 -y
else
    echo "Python3 уже установлен"
fi

# Установка python3-venv, если не установлен
if ! dpkg -s python3-venv &> /dev/null; then
    echo "Устанавливаем python3-venv..."
    apt install python3-venv -y
else
    echo "python3-venv уже установлен"
fi

# Проверка, установлен ли pip, и установка, если он не установлен
if ! command -v pip3 &> /dev/null; then
    echo "pip3 не найден, устанавливаем..."
    apt update
    apt install python3-pip -y
else
    echo "pip3 уже установлен"
fi

# Установка virtualenv, если не установлен
if ! pip3 show virtualenv &> /dev/null; then
    echo "Устанавливаем virtualenv..."
    pip3 install virtualenv
else
    echo "virtualenv уже установлен"
fi

# Создание виртуального окружения
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

# Активация виртуального окружения
source $VENV_DIR/bin/activate

# Установка библиотек requests и faker, если они не установлены
if ! pip3 show requests &> /dev/null; then
    echo "Библиотека requests не найдена, устанавливаем..."
    pip3 install requests
else
    echo "Библиотека requests уже установлена"
fi

if ! pip3 show faker &> /dev/null; then
    echo "Библиотека Faker не найдена, устанавливаем..."
    pip3 install faker
else
    echo "Библиотека Faker уже установлена"
fi


# Создание Python скрипта
echo "Создаём Python скрипт..."
cat << EOF > $PYTHON_SCRIPT_NAME
import requests
import json
import time
import logging

# ------------------------------------------------------------------------------------------
'''
Просто меняем ссылку на свою ноду, далее запускаем.
Будет автоматически идти диалог с задержкой между сообщениями 10 сек.
'''
# ------------------------------------------------------------------------------------------

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(message)s")

gaianetLink = 'https://abuzeman.gaia.domains/v1/chat/completions'

GREEN = "\033[32m"
RESET = "\033[0m"

class DualAPIClient:
    def __init__(self, gpt_config, custom_config):
        self.gpt_config = gpt_config
        self.custom_config = custom_config
        self.previous_question = None  # Переменная для хранения предыдущего вопроса

    def _send_request(self, config):
        try:
            response = requests.post(config['url'], headers=config['headers'], data=json.dumps(config['data']))
            if response.status_code == 200:
                return response.json()
            else:
                # Возвращаем код ошибки и текст ответа сервера
                return {
                    "error": response.status_code,
                    "message": response.text
                }
        except requests.exceptions.RequestException as e:
            # Ловим исключения сети, например, таймауты
            return {
                "error": "network_error",
                "message": str(e)
            }

    def send_gpt_request(self, user_message):
        if self.previous_question:
            usr_message = f"{user_message} + 'your answer: {self.previous_question}'"
        else:
            usr_message = user_message

        self.gpt_config['data']['messages'][1]['content'] = usr_message
        response = self._send_request(self.gpt_config)

        if "error" not in response:
            self.previous_question = self.extract_answer(response)

        return response

    def send_custom_request(self, user_message):
        self.custom_config['data']['messages'][1]['content'] = user_message
        return self._send_request(self.custom_config)

    def extract_answer(self, response):
        if "error" in response:
            return f"Error: {response['error']} - {response['message']}"
        return response.get('choices', [{}])[0].get('message', {}).get('content', '')


gpt_config = {
    'url': f'https://abuzeman.gaia.domains/v1/chat/completions',
    'headers': {
        'accept': 'application/json',
        'Content-Type': 'application/json'
    },
    'data': {
        "messages": [
            {"role": "system", "content": 'You answer with 1 short phrase'},
            {"role": "user", "content": ""}
        ]
    }
}

gaianet_config = {
    'url': f'https://abuzeman.gaia.domains/v1/chat/completions',
    'headers': {
        'accept': 'application/json',
        'Content-Type': 'application/json'
    },
    'data': {
        "messages": [
            {"role": "system", "content": "You answer with 1 short phrase"},
            {"role": "user", "content": ""}
        ]
    }
}

client = DualAPIClient(gpt_config, gaianet_config)

initial_question = "Let's go tell about China!"
gpt_response = client.send_gpt_request(initial_question)

while True:
    print(f'\n{GREEN}' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + f" [Вопрос от GPT]:{RESET}")

    if "error" in gpt_response:
        logging.error(f"GPT Request Error {gpt_response['error']}: {gpt_response['message']}")
        gpt_answer = "Error occurred. Please retry."
    else:
        gpt_answer = client.extract_answer(gpt_response).replace('\n', ' ')
        print(gpt_answer)

    custom_response = client.send_custom_request(gpt_answer + ' Tell me a random theme to speak')

    print(f'\n{GREEN}' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + f" [Ответ GaiaNet]:{RESET}")

    if "error" in custom_response:
        logging.error(f"GaiaNet Request Error {custom_response['error']}: {custom_response['message']}")
        custom_answer = "Error occurred. Please retry."
    else:
        custom_answer = client.extract_answer(custom_response).replace('\n', ' ')
        print(custom_answer)

    gpt_response = client.send_gpt_request(custom_answer)
    time.sleep(1)

EOF
echo "Python скрипт создан. Запускать можно командой: python3 $PYTHON_SCRIPT_NAME"
