# Use specific version of nvidia cuda image
FROM wlsdml1114/multitalk-base:1.8 as runtime

RUN pip install -U "huggingface_hub[hf_transfer]"
RUN pip install runpod websocket-client

WORKDIR /

RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && \
    pip install -r requirements.txt

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
