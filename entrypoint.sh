#!/usr/bin/env bash
set -euo pipefail

export PYTHONUNBUFFERED=1
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}

cd /ComfyUI

# Starte ComfyUI und schreibe ALLES in eine Log-Datei
python3 main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch > /tmp/comfyui.log 2>&1 &
COMFY_PID=$!

echo "ComfyUI PID: $COMFY_PID"

MAX_WAIT=${MAX_WAIT:-600}

for i in $(seq 1 "$MAX_WAIT"); do
  # Wenn ComfyUI crashed -> Log zeigen und hart beenden (damit wir die Ursache sehen)
  if ! kill -0 "$COMFY_PID" 2>/dev/null; then
    echo "❌ ComfyUI crashed while starting."
    echo "---- Last 200 lines of /tmp/comfyui.log ----"
    tail -n 200 /tmp/comfyui.log || true
    exit 1
  fi

  # Ready-Check (system_stats ist in ComfyUI meist zuverlässig)
  if curl -sf "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1; then
    echo "✅ ComfyUI is ready!"
    break
  fi

  echo "Waiting for ComfyUI... ($i/$MAX_WAIT)"
  sleep 1
done

# Wenn nach MAX_WAIT immer noch nicht ready -> Log zeigen
if ! curl -sf "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1; then
  echo "❌ Timeout: ComfyUI never became ready."
  echo "---- Last 200 lines of /tmp/comfyui.log ----"
  tail -n 200 /tmp/comfyui.log || true
  exit 1
fi

# Jetzt erst den RunPod-Handler starten
python3 -u /handler.py

# Falls Handler endet: ComfyUI sauber mit beenden
kill "$COMFY_PID" 2>/dev/null || true
