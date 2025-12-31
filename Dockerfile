FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ---------- System ----------
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------- Python ----------
RUN pip3 install --upgrade pip

# ---------- ComfyUI ----------
WORKDIR /
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /ComfyUI
RUN pip3 install -r requirements.txt

# ---------- Torch (fixe Version, stabil) ----------
RUN pip uninstall -y torch torchvision torchaudio || true && \
    pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 \
    --index-url https://download.pytorch.org/whl/cu121

# ---------- Custom Nodes ----------
WORKDIR /ComfyUI/custom_nodes
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

# ---------- RealESRGAN Model ----------
RUN mkdir -p /ComfyUI/models/upscale_models && \
    curl -L \
    -o /ComfyUI/models/upscale_models/RealESRGAN_x4plus.pth \
    https://huggingface.co/xinntao/Real-ESRGAN/resolve/main/weights/RealESRGAN_x4plus.pth

# ---------- App Files ----------
WORKDIR /
COPY handler.py /handler.py
COPY workflow /workflow

# ---------- RunPod ----------
RUN pip install runpod

EXPOSE 8188

CMD ["python3", "/handler.py"]
