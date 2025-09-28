# InvokeAI in Docker (Unraid + RunPod ready)

## Prereqs
- NVIDIA GPU drivers on host + NVIDIA Container Toolkit
- Docker & Docker Compose v2

## First run (Unraid/local)
1. `cp .env.example .env` and edit:
   - `INVOKEAI_ROOT=/mnt/user/appdata/invokeai` (or any persistent path)
   - `CIVITAI_TOKEN=...`
   - Fill `CHECKPOINT_URL`, 3x `LORA_URL_*`, and `VAE_URL` (optional)
2. `docker compose up --build -d`
3. Open `http://<host>:9090`
4. In **Manage Models**, use **Scan Folder** if anything didn’t auto‑register:
   - `${INVOKEAI_ROOT}/models/checkpoints`
   - `${INVOKEAI_ROOT}/models/loras`
   - `${INVOKEAI_ROOT}/models/vae`

## Update image/models
- Change Dockerfile tag to a newer `*-cuda` release and rebuild.
- Edit `.env` with new URLs and `docker compose restart` to fetch missing files.

## RunPod notes
- Build & push this image to a registry you control.
- In your RunPod template, set:
  - `INVOKEAI_ROOT=/workspace/invokeai` (and mount a volume there)
  - Add your CIVITAI token and URLs as env vars
  - Expose port 9090
