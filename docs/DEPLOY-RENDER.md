# Demo deploy on Render (free) — about 5 minutes

1. Go to render.com and sign up / sign in **with GitHub**.
2. **New → Blueprint** → choose this repository → Render reads `render.yaml` → **Apply**.
3. Wait 2–3 minutes. Open the link Render shows (like `https://asingh-xxxx.onrender.com`).
4. Admin: `https://<your-link>/admin.html`, email `admin@asingh.local`. The password was generated for you: Render dashboard → your service → **Environment** → `ADMIN_PASSWORD` (click to reveal). Change it in Admin → Security.
5. In Admin → Payment & QR: upload your QR, set UPI ID, bill details.

Remember: free tier = sleeps after ~15 min idle, and **all data is erased on restart/redeploy** (re-upload the QR each time). For real orders use `docs/DEPLOY-ORACLE.md`.
