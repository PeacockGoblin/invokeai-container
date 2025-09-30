# RunPod Template Notes

- Use the image you build from this repo.
- Mount a persistent volume at `/workspace/invokeai` and set `INVOKEAI_ROOT` to that path.
- Add env vars: CIVITAI_TOKEN, CHECKPOINT_URL, LORA_URL_1..3, VAE_URL.
- Expose port 9090. First boot will download models into the volume.
- For multi-GPU pods: select GPUs at deploy. InvokeUI typically uses one GPU per inference session.
