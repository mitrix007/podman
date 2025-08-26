#!/bin/bash

# Script to deploy a GGUF model in Ollama, optimized for CPU or GPU
# Adds model to litellm_config.yaml without clearing
# Usage: ./deploy_gguf_model.sh [--device=cpu|gpu]

# Settings (modify these for your model)
HF_REPO="miqudev/miqu-1-70b"
GGUF_FILE="miqu-1-70b.q4_k_m.gguf"  # Default for CPU
GGUF_FILE_GPU="miqu-1-70b.q8_0.gguf"  # Optional for GPU, adjust as needed
MODEL_NAME="miqu-1-70b"
MODELS_DIR="/opt/llm/data/llm_ollama/models"
MODELFILE_PATH="/tmp/Modelfile"
CONTAINER_NAME="llm_ollama"
LITELLM_CONFIG="/opt/llm/litellm_config.yaml"
REQUIRED_SPACE=42000000  # 41.4 GB in KB, adjust for other models (e.g., 5000000 for ~5 GB)
REQUIRED_MEMORY=50000000  # 50 GB in KB, adjust for other models (e.g., 8000000 for ~8 GB)

# Default device
DEVICE="cpu"

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    --device=*)
      DEVICE="${arg#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--device=cpu|gpu]"
      exit 1
      ;;
  esac
done

# Validate device
if [[ "$DEVICE" != "cpu" && "$DEVICE" != "gpu" ]]; then
  echo "Error: --device must be 'cpu' or 'gpu'"
  exit 1
fi

# Set GGUF file and resource requirements based on device
if [ "$DEVICE" = "gpu" ]; then
  GGUF_FILE="$GGUF_FILE_GPU"
  REQUIRED_SPACE=45000000  # Adjust for larger Q8_0 file, if applicable
  REQUIRED_MEMORY=55000000  # Adjust for GPU memory requirements
fi

# Function to dynamically generate MODELFILE_TEMPLATE
generate_model_file() {
  local repo="$1"
  local model="$2"
  local device="$3"
  local system_prompt="You are a helpful assistant, optimized for general-purpose tasks and instruction-tuned for clarity and accuracy."
  local temperature="0.7"

  # Extract keywords (case-insensitive)
  repo_lower=$(echo "$repo" | tr '[:upper:]' '[:lower:]')
  model_lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')

  # Determine SYSTEM prompt and temperature based on keywords
  if [[ "$repo_lower" =~ "coder" || "$model_lower" =~ "coder" ]]; then
    system_prompt="You are a coding assistant, specializing in providing clear and accurate programming solutions."
    temperature="0.6"
  elif [[ "$repo_lower" =~ "instruct" || "$model_lower" =~ "instruct" || "$repo_lower" =~ "it" || "$model_lower" =~ "it" ]]; then
    system_prompt="You are an instruction-tuned assistant, optimized for following user instructions with high accuracy."
    temperature="0.7"
  elif [[ "$repo_lower" =~ "chat" || "$model_lower" =~ "chat" ]]; then
    system_prompt="You are a conversational assistant, designed for engaging and helpful dialogue."
    temperature="0.8"
  elif [[ "$repo_lower" =~ "mikrotik" || "$model_lower" =~ "mikrotik" ]]; then
    system_prompt="You are a MikroTik RouterOS Expert Assistant, specialized in configuring and troubleshooting MikroTik devices."
    temperature="0.7"
  elif [[ "$repo_lower" =~ "miqu" || "$model_lower" =~ "miqu" ]]; then
    system_prompt="You are a highly capable assistant, specializing in clear and accurate responses, with strong language skills including German."
    temperature="0.7"
  elif [[ "$repo_lower" =~ "gemma" || "$model_lower" =~ "gemma" ]]; then
    system_prompt="You are a versatile assistant based on Gemma, optimized for general-purpose tasks and clear communication."
    temperature="0.7"
  fi

  # Adjust temperature for GPU (slightly more creative)
  if [ "$device" = "gpu" ]; then
    temperature=$(echo "$temperature + 0.1" | bc)
  fi

  # Get CPU threads or GPU count
  if [ "$device" = "cpu" ]; then
    CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}' 2>/dev/null || echo "16")
    echo "Detected $CPU_THREADS CPU threads for PARAMETER num_cpu."
    PARAMETERS="PARAMETER num_cpu $CPU_THREADS\nPARAMETER temperature $temperature"
  else
    GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -n 1 || echo "1")
    echo "Detected $GPU_COUNT GPU(s) for PARAMETER num_gpu."
    PARAMETERS="PARAMETER num_gpu $GPU_COUNT\nPARAMETER temperature $temperature"
  fi

  # Construct MODELFILE_TEMPLATE
  echo -e "FROM /root/.ollama/models/$GGUF_FILE\nSYSTEM $system_prompt\n$PARAMETERS"
}

# Step 1: Check if models directory exists
if [ ! -d "$MODELS_DIR" ]; then
  echo "Error: Directory $MODELS_DIR does not exist. Create it first."
  exit 1
fi

# Step 2: Load .env for HF_API_TOKEN
if [ -f "/opt/llm/.env" ]; then
  source /opt/llm/.env
else
  echo "Warning: .env file not found. Attempting to download without token."
fi

# Step 3: Check available disk space
AVAILABLE_SPACE=$(df -k "$MODELS_DIR" | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
  echo "Error: Insufficient disk space in $MODELS_DIR. Need ~$((REQUIRED_SPACE/1024/1024)) GB, available: $((AVAILABLE_SPACE/1024/1024)) GB."
  exit 1
fi

# Step 4: Check available memory (RAM + swap)
AVAILABLE_MEMORY=$(free -k | grep Mem | awk '{print $7}')  # Available RAM
AVAILABLE_SWAP=$(free -k | grep Swap | awk '{print $4}')   # Available swap
TOTAL_MEMORY=$((AVAILABLE_MEMORY + AVAILABLE_SWAP))
if [ "$TOTAL_MEMORY" -lt "$REQUIRED_MEMORY" ]; then
  echo "Warning: Insufficient memory. Need ~$((REQUIRED_MEMORY/1024/1024)) GB, available: $((TOTAL_MEMORY/1024/1024)) GB. Consider adding swap."
fi

# Step 5: Download GGUF from Hugging Face
if [ ! -f "$MODELS_DIR/$GGUF_FILE" ]; then
  echo "Downloading $GGUF_FILE from $HF_REPO..."
  if [ -n "$HF_API_TOKEN" ]; then
    curl -H "Authorization: Bearer $HF_API_TOKEN" \
         "https://huggingface.co/$HF_REPO/resolve/main/$GGUF_FILE" \
         -o "$MODELS_DIR/$GGUF_FILE" -L
  else
    curl "https://huggingface.co/$HF_REPO/resolve/main/$GGUF_FILE" \
         -o "$MODELS_DIR/$GGUF_FILE" -L
  fi

  if [ $? -ne 0 ]; then
    echo "Error downloading. Check repo, file, or HF_API_TOKEN."
    exit 1
  fi
else
  echo "$GGUF_FILE already exists in $MODELS_DIR, skipping download."
fi

# Verify file exists
if [ ! -f "$MODELS_DIR/$GGUF_FILE" ]; then
  echo "Error: File $GGUF_FILE not found in $MODELS_DIR."
  exit 1
fi

# Step 6: Generate MODELFILE_TEMPLATE
MODELFILE_TEMPLATE=$(generate_model_file "$HF_REPO" "$MODEL_NAME" "$DEVICE")
echo "Generated MODELFILE_TEMPLATE: $MODELFILE_TEMPLATE"

# Step 7: Create Modelfile on host
echo -e "$MODELFILE_TEMPLATE" > $MODELFILE_PATH
echo "Modelfile created: $(cat $MODELFILE_PATH)"

# Step 8: Copy Modelfile to container and create model in Ollama
podman cp $MODELFILE_PATH $CONTAINER_NAME:/tmp/Modelfile
podman exec -it $CONTAINER_NAME ollama create $MODEL_NAME -f /tmp/Modelfile

if [ $? -ne 0 ]; then
  echo "Error creating model in Ollama. Check logs: podman logs $CONTAINER_NAME"
  rm $MODELFILE_PATH
  exit 1
fi

rm $MODELFILE_PATH  # Clean up temporary file

# Step 9: Add model to litellm_config.yaml without clearing
echo "Adding model to $LITELLM_CONFIG..."
cat <<EOL >> $LITELLM_CONFIG

  - model_name: local_$MODEL_NAME
    litellm_params:
      model: "ollama/$MODEL_NAME"
      api_base: http://ollama:11434
    cost: 0.000001
EOL

if [ $? -ne 0 ]; then
  echo "Error adding to litellm_config.yaml."
  exit 1
fi

# Step 10: Restart litellm to apply config
echo "Restarting llm_litellm..."
podman restart llm_litellm

if [ $? -ne 0 ]; then
  echo "Error restarting llm_litellm. Check logs: podman logs llm_litellm"
  exit 1
fi

# Step 11: Verification
echo "Model $MODEL_NAME deployed, optimized for $DEVICE."
echo "1. Check in Ollama: podman exec -it llm_ollama ollama list"
echo "2. Check in LiteLLM: curl http://localhost:4000/v1/models"
echo "3. In WebUI (port 3000): model should appear as local_$MODEL_NAME"
echo "4. Test model: podman exec -it llm_ollama ollama run $MODEL_NAME 'Test prompt, e.g., How to configure a DHCP server?'"