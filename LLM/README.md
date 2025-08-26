# LLM‑стэк с биллингом: Ollama + LiteLLM + Stripe + Open WebUI(LibreChat, Text Generation WebUI) + Nginx + HF‑Images Proxy (Podman/Podman‑compose)

> Готовая пошаговая инструкция для продакшн‑развёртывания на Linux. Включает: файловую структуру, готовые конфиги, команды запуска, прокси для изображений (OpenAI Images → HF Inference), базовую интеграцию со Stripe, а также заметки для миграции в Kubernetes.

---

## 🗺️ Архитектура и потоки

```
Клиент/браузер ──> Nginx (80/443)
   │
   ├── /webui ────────────> Open WebUI (3000→8080)
   ├── /v1/chat, /v1/* ───> LiteLLM Proxy (4000)
   │                          └── (локальные модели через Ollama 11434)
   └── /v1/images/* ──────> HF Images Proxy (8000)

Вспомогательно: Redis (6379) для LiteLLM (кеш, лимиты, трекинг), TLS‑серты в Nginx.
```

---

## 📋 Требования

- Linux‑сервер (рекомендовано 4+ vCPU, 16+ GB RAM; для крупных моделей — GPU)
- Podman 5.0+ и podman‑compose
- 3D controller: NVIDIA Corporation GA100 [A100 PCIe 80GB] (rev a1)
- Доступ к реестрам (docker.io, ghcr.io, quay.io)
- API‑ключи openrouter.ai, huggingface.co (OpenAI при необходимости, Hugging Face, Stripe)
- Порты: `80, 443, 3000, 4000, 8000, 11434, 6379` (или закройте внешние, оставив только 80/443 на Nginx)
- Порты открытые: 443, 3000