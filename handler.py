import os
import json
import time
import uuid
import urllib.request
import urllib.parse

import runpod


SERVER = os.getenv("SERVER_ADDRESS", "127.0.0.1")
COMFY_HTTP = f"http://{SERVER}:8188"
COMFY_PROMPT = f"{COMFY_HTTP}/prompt"
COMFY_HISTORY = f"{COMFY_HTTP}/history"

WORKFLOW_PATH = os.getenv("WORKFLOW_PATH", "/workflow/upscale.json")
COMFY_INPUT_DIR = os.getenv("COMFY_INPUT_DIR", "/ComfyUI/input")
COMFY_OUTPUT_DIR = os.getenv("COMFY_OUTPUT_DIR", "/ComfyUI/output")

# Dein Workflow nutzt Node "1" als VHS_LoadVideo
VIDEO_NODE_ID = "1"
VIDEO_INPUT_KEY = "video"  # inputs.video


def download_file(url: str, out_path: str):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=600) as r:
        with open(out_path, "wb") as f:
            f.write(r.read())


def queue_prompt(prompt: dict) -> str:
    payload = {"prompt": prompt, "client_id": str(uuid.uuid4())}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(COMFY_PROMPT, data=data, headers={"Content-Type": "application/json"})
    resp = urllib.request.urlopen(req, timeout=60).read()
    j = json.loads(resp)
    return j["prompt_id"]


def get_history(prompt_id: str) -> dict:
    url = f"{COMFY_HISTORY}/{prompt_id}"
    resp = urllib.request.urlopen(url, timeout=60).read()
    return json.loads(resp)


def find_latest_output_file() -> str:
    # Nimmt das neueste File aus /ComfyUI/output
    if not os.path.isdir(COMFY_OUTPUT_DIR):
        return ""
    files = []
    for root, _, fnames in os.walk(COMFY_OUTPUT_DIR):
        for n in fnames:
            p = os.path.join(root, n)
            files.append((os.path.getmtime(p), p))
    if not files:
        return ""
    files.sort(key=lambda x: x[0], reverse=True)
    return files[0][1]


def handler(job):
    inp = job.get("input", {}) or {}

    video_url = inp.get("video_url")
    if not video_url:
        return {"error": "Missing 'video_url' in input."}

    # optional
    filename_prefix = inp.get("filename_prefix", "upscaled")
    timeout_s = int(inp.get("timeout_s", 1800))  # 30min default

    # 1) Video downloaden nach /ComfyUI/input/input_video.mp4
    local_video_name = "input_video.mp4"
    local_video_path = os.path.join(COMFY_INPUT_DIR, local_video_name)
    download_file(video_url, local_video_path)

    # 2) Workflow laden
    if not os.path.isfile(WORKFLOW_PATH):
        return {"error": f"Workflow not found at {WORKFLOW_PATH}"}

    with open(WORKFLOW_PATH, "r", encoding="utf-8") as f:
        prompt = json.load(f)

    # 3) Video-Input setzen
    # Dein VHS_LoadVideo erwartet NUR den Filename (ComfyUI input dir), nicht URL
    prompt[VIDEO_NODE_ID]["inputs"][VIDEO_INPUT_KEY] = local_video_name

    # Optional: prefix im VideoCombine überschreiben (Node "2")
    if "2" in prompt and "inputs" in prompt["2"]:
        prompt["2"]["inputs"]["filename_prefix"] = filename_prefix

    # 4) Prompt an ComfyUI schicken
    prompt_id = queue_prompt(prompt)

    # 5) Warten bis fertig
    t0 = time.time()
    while True:
        hist = get_history(prompt_id)
        # Wenn prompt_id im history auftaucht, ist er fertig (success oder fail)
        if prompt_id in hist:
            break
        if time.time() - t0 > timeout_s:
            return {"error": f"Timed out waiting for ComfyUI (>{timeout_s}s).", "prompt_id": prompt_id}
        time.sleep(2)

    # 6) Output finden
    out_path = find_latest_output_file()
    if not out_path:
        return {"error": "No output file found in /ComfyUI/output", "prompt_id": prompt_id}

    # RunPod kann local files als Ergebnis zurückgeben, je nach Template.
    # Wir geben Pfad + prompt_id zurück (du kannst auch später uploaden).
    return {"prompt_id": prompt_id, "output_path": out_path}


runpod.serverless.start({"handler": handler})
