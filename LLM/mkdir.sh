#!/bin/bash

BASE_DIR="/opt/llm/data"

# Список контейнеров
CONTAINERS=("llm_ollama" "llm_litellm" "llm_redis" "llm_webui" "llm_nginx" "llm_hfimages_proxy")

echo "🔧 Создаём директории для volumes..."

for name in "${CONTAINERS[@]}"; do
  path="${BASE_DIR}/${name}"
  echo "📁 ${path}"
  sudo mkdir -p "$path"
  sudo chown -R root:root "$path"
  sudo chmod 755 "$path"
done

echo "✅ Все директории созданы и настроены."
