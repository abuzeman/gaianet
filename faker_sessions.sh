#!/bin/bash
PYTHON_SCRIPT_NAME="request_script.py"
FAKER_SESSION_LIMIT=5

# Запуск Faker скриптов общения
for COUNT in {1..$FAKER_SESSION_LIMIT}
do
    SESSION="gaiasession$COUNT"
    screen -dmS $SESSION bash -c "python3 $PYTHON_SCRIPT_NAME"
  #sleep $((RANDOM % (180 - 20 + 1) + 20))  # Пауза между запусками (опционально)
    sleep 3
done

echo "Faker скрипты в количестве $FAKER_SESSION_LIMIT запущены в сессиях"
