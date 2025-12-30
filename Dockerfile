# Use specific version of nvidia cuda image
FROM wlsdml1114/multitalk-base:1.8 as runtime

RUN pip install -U "huggingface_hub[hf_transfer]"
RUN pip install runpod websocket-client

WORKDIR /

RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && \
    pip install -r requirements.txt

# ---- Pin PyTorch (avoid PyTorch 2.6 weights_only behavior) ----
RUN pip uninstall -y torch torchvision torchaudio || true && \
    pip install --no-cache-dir torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121


# ---- Force torch.load(weights_only=False) in ComfyUI safe loader ----
RUN python - << 'PY'
import pathlib, re
p = pathlib.Path("/ComfyUI/comfy/utils.py")
t = p.read_text(encoding="utf-8")
# Very targeted: if ComfyUI calls torch.load without weights_only, inject weights_only=False.
# (If ComfyUI already sets weights_only=True somewhere, flip it to False.)
t2 = t.replace("weights_only=True", "weights_only=False")
p.write_text(t2, encoding="utf-8")
print("Patched comfy/utils.py weights_only handling")
PY

# === Install system deps for model download ===
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# === Download RealESRGAN model ===
RUN mkdir -p /ComfyUI/models/upscale_models && \
    curl -L --retry 10 --retry-delay 2 \
    -o /ComfyUI/models/upscale_models/RealESRGAN_x4plus.pth \
    "https://huggingface.co/xinntao/Real-ESRGAN/resolve/main/weights/RealESRGAN_x4plus.pth?download=true"

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip install -r requirements.txt
    
#RUN cd /ComfyUI/custom_nodes && \
   # git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
   # cd ComfyUI-Frame-Interpolation && \
   # python install.py

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/chflame163/ComfyUI_LayerStyle.git && \
    cd ComfyUI_LayerStyle && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    cd ComfyUI-VideoHelperSuite && \
    pip install -r requirements.txt

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /ComfyUI/models/upscale_models && \
    curl -L --retry 10 --retry-delay 2 --connect-timeout 20 --max-time 600 \
    -o /ComfyUI/models/upscale_models/RealESRGAN_x4plus.pth \
    "https://huggingface.co/xinntao/Real-ESRGAN/resolve/main/weights/RealESRGAN_x4plus.pth?download=true"
WORKDIR /

COPY . .
RUN mkdir -p /ComfyUI/user/default/ComfyUI-Manager
COPY config.ini /ComfyUI/user/default/ComfyUI-Manager/config.ini
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
