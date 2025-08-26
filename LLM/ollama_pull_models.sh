#!/bin/bash

##Основные типы моделей
#       Dense (плотные): Все параметры модели используются для каждого входа (стандартный тип).
#Пример: qwen3:0.6b, qwen3:4b, qwen3:30b.
#       MoE (Mixture of Experts): Использует подмножество экспертов в зависимости от входа (эффективнее для больших моделей).
#Пример: qwen3:235b-a22b (235 млрд параметров, MoE).
##Основные аббревиатуры и их значение
#       Суффикс         Что означает                                                                    Когда выбрать
#       -q4_K_M         Квантование 4 бита (оптимизировано для скорости и памяти).                      На слабом железе, мобильные устройства.
#       -q8_0           Квантование 8 бит (более точное, но требует больше памяти).                     Баланс между скоростью и точностью.
#       -fp16           Полная точность (16 бит), без квантования.                                      На мощных GPU, высокая точность.
#       -instruct       Оптимизирована для ответов на инструкции (например, "Напиши письмо...").        Для задач с четкими запросами.
#       -thinking       Оптимизирована для сложных рассуждений (логика, анализ).                        Для задач, требующих глубокого анализа.
#       -a3b            Версия MoE (Mixture of Experts) с архитектурой A3B (235b — это MoE-модель).     Для больших задач с высокой сложностью.
##Ключевые параметры
#*Размер модели:
#       0.6b (600 млн) → 235b (235 млрд).
#       Чем больше, тем сложнее задачи, но требует больше ресурсов.
#*Контекст (context):
#       40K (40 тыс. токенов) vs 256K (256 тыс. токенов).
#       256K — для обработки очень длинных текстов (например, целые книги).
#*Тип входа:
#       Все модели работают с текстом (Text), но некоторые (с -instruct/-thinking) лучше справляются с конкретными задачами.
##Рекомендации по выбору
#       Сценарий        Рекомендуемая модель
#       Слабый компьютер / мобильное приложение         qwen3:0.6b-q4_K_M (маленький размер + квантование)
#       Точность для бизнес-задач                       qwen3:4b-fp16 (баланс между скоростью и качеством)
#       Анализ длинных текстов (книги, документы)       qwen3:235b-a22b-256K-fp16 (большой контекст + MoE)
#       Инструкции (например, "Напиши SEO-текст")       qwen3:4b-instruct-fp16
#       Сложные рассуждения (математика, логика)        qwen3:30b-thinking-fp16



# Список моделей для загрузки (можно менять)
MODELS=(
    "llama3"                                    # Meta Llama 3
    "llava:7b"                                  # LLaVA: Large Language and Vision Assistant
    "qwen:0.5b-chat-v1.5-q4_0"                  #Qwen Квантование 4 бита (оптимизировано для скорости и памяти).                        На слабом железе, мобильные устройства.
    "qwen2.5-coder:7b"                          #Qwen 2.5 Coder series of models are now updated in 6 sizes: 0.5B, 1.5B, 3B, 7B, 14B and 32B.
    "qwen2.5-coder:32b"                         #Qwen 2.5 Coder series of models are now updated in 6 sizes: 0.5B, 1.5B, 3B, 7B, 14B and 32B.
    "qwen3-coder:30b"                           #Qwen3-Coder is the most agentic code model to date in the Qwen series.
    "qwen3:8b"                                  #Qwen3 is the latest generation of large language models in Qwen series
    "qwen3:30b"                                 #Qwen3 is the latest generation of large language models in Qwen series
    "qwen3:30b-a3b-q4_K_M"                      #Qwen3 Квантование 4 бита (оптимизировано для скорости и памяти).                       На слабом железе, мобильные устройства.
    "qwen3:30b-a3b-q8_0"                        #Qwen3 Квантование 8 бит (более точное, но требует больше памяти).                      Баланс между скоростью и точностью.
#    "qwen3:30b-a3b-fp16"                       #Qwen3 Полная точность (16 бит), без квантования.                                       На мощных GPU, высокая точность.
#    "qwen3:30b-a3b-instruct-2507-q8_0"         #Qwen3 Оптимизирована для ответов на инструкции (например, "Напиши письмо..."). Для задач с четкими запросами.
    "qwen3:30b-a3b-thinking-2507-q4_K_M"        #Qwen3 Оптимизирована для сложных рассуждений (логика, анализ).                 Для задач, требующих глубокого анализа.
    "qwen3:30b-a3b"                             #Qwen3 Версия MoE (Mixture of Experts) с архитектурой A3B (235b — это MoE-модель).      Для больших задач с высокой сложностью.
#    "qwen3:235b-a22b-q4_K_M"                   #Qwen3 Квантование 4 бита (оптимизировано для скорости и памяти).                       На слабом железе, мобильные устройства.
    "gpt-oss:20b"                               # OpenAI’s open-weight models designed for powerful reasoning, agentic tasks, and versatile developer use cases.
#    "gpt-oss:120b"                             # OpenAI’s open-weight models designed for powerful reasoning, agentic tasks, and versatile developer use cases.
    "dengcao/Qwen3-Reranker-8B:Q3_K_M"                  #Qwen3 Alibaba's text reranking model.
    "dengcao/Qwen3-Reranker-8B:Q4_K_M"                  #Qwen3 Alibaba's text reranking model.
    "dengcao/Qwen3-Reranker-8B:Q5_K_M"                  #Qwen3 Alibaba's text reranking model.
    "dengcao/Qwen3-Reranker-8B:Q8_0"                    #Qwen3 Alibaba's text reranking model.
    "dengcao/Qwen3-Reranker-8B:F16"                     #Qwen3 Alibaba's text reranking model.
    "mxbai-embed-large"                         #State-of-the-art large embedding model from mixedbread.ai
    "nomic-embed-text:latest"                   #A high-performing open embedding model with a large token context window.
    "all-minilm:latest"                         #Embedding models on very large sentence level datasets.
    "ALIENTELLIGENCE/homeassistantaiadvisor:latest"     #Home Assistant AI Advisor: Provides assistance with Home Assistant
    "allenporter/assist-llm:latest"             #A function calling LLM for use with the Home Assistant assist pipeline, based on llama3.1 8B
#    "deepseek-v3:671b"                         # 404GB
#    "deepseek-r1:671b-0528-q4_K_M"             # 404GB
#    "qwen3-coder:latest"                       # 19GB
#    "quantumcthulhu/Qwen3-235B-A22B-Instruct-2507-Q4_K_M:latest"       # 142GB
#    "haybu/gpt-oss-120b:latest"                # 65GB
#    "glm4:9b"                                  # 5,5GB
)

# Проверка, запущен ли контейнер Ollama
if ! podman ps | grep -q llm_ollama; then
    echo "Ошибка: контейнер 'llm_ollama' не запущен!"
    exit 1
fi

# Загрузка моделей
for model in "${MODELS[@]}"; do
    echo "Загрузка модели: $model ..."
    if ! podman exec -it llm_ollama ollama pull "$model"; then
        echo "Ошибка при загрузке $model!"
    else
        echo "Успешно: $model загружена."
    fi
    echo "-----------------------------------"
done

# Итог
echo "Готово! Загруженные модели:"
podman exec -it llm_ollama ollama list
