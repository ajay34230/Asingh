# Hosting Chandravanshi free on Oracle Cloud (Always Free VM)

Takes about 30–45 minutes. Oracle's console wording changes now and then — the names below are close, not exact. Free-tier terms also change, so check Oracle's current "Always Free" page.

## 1. Create the account
1. Sign up at oracle.com/cloud/free. A card is needed for identity verification; Always Free resources are not charged.
2. Pick your **home region** carefully — it can't be changed later, and free resources live there.

## 2. Create the VM
1. Menu → **Compute → Instances → Create instance**.
2. **Image:** Ubuntu 22.04 or 24.04. **Shape:** pick one marked *Always Free-eligible* (Ampere A1 Flex with 1–2 OCPU / 6–12 GB, or VM.Standard.E2.1.Micro). If "out of capacity", try again later or another availability domain.
3. **Networking:** keep "Assign a public IPv4 address".
4. **SSH keys:** "Generate a key pair" and **download the private key**. Keep it safe — it's the only way in.
5. Create, then copy the **public IP**.

## 3. Open the web ports (Oracle firewall)
Networking → **Virtual cloud networks** → your VCN → your subnet → **Security List** → *Add ingress rules*:
`Source 0.0.0.0/0 · TCP · destination port 80` and again for `443`.

## 4. Point a domain at the VM (needed for HTTPS)
- Free option: create a name at **duckdns.org** (e.g. `asingh.duckdns.org`) and set its IP to the VM's public IP.
- Or use your own domain: add an **A record** → the public IP.

## 5. Install
```bash
chmod 600 ~/Downloads/ssh-key-*.key
ssh -i ~/Downloads/ssh-key-*.key ubuntu@<PUBLIC_IP>

git clone <your-repo-url> asingh && cd asingh
git checkout claude/extreme-responsive-design-t9g7mk      # or your main branch once merged
sudo bash deploy/oracle-setup.sh asingh.duckdns.org you@example.com
```
The script installs Node 22 and Caddy, runs the store as a locked-down service that restarts itself, gets a free HTTPS certificate, opens ports 80/443 in the VM firewall, and sets up daily backups. **It prints your admin password once** (also in `/etc/asingh.env`).

Then open `https://your-domain` and `https://your-domain/admin.html`:
1. Sign in → **Security** → change the password.
2. **Payment & QR** → upload your QR, set UPI ID and payee name, fill in *Bill details*.
3. **Alerts** → enable browser notifications and (optionally) paste a Slack/Discord webhook.

## 6. Day-to-day
| Task | Command (on the VM) |
|---|---|
| Update the site | `cd ~/asingh && sudo bash deploy/update.sh` |
| See logs | `journalctl -u asingh -f` |
| Restart | `sudo systemctl restart asingh` |
| Backups | daily in `/var/backups/asingh/` (14 days). **Copy them off the VM** now and then: `scp -i key ubuntu@IP:/var/backups/asingh/*.tar.gz .` |
| Change settings | edit `/etc/asingh.env`, then restart |

## Things to know
- **Idle reclamation:** Oracle may reclaim Always Free compute that sits nearly idle for a long time. A quiet shop could qualify — keep off-VM backups, and read Oracle's current policy (upgrading the account to pay-as-you-go while staying within free limits is often suggested to lower the risk; confirm on Oracle's site).
- **If the page doesn't load:** (1) Security List rules for 80/443, (2) the domain's IP matches, (3) `sudo systemctl status asingh caddy`.
- **Not tested on a live Oracle VM** from my side — the script is checked for syntax and follows each tool's documented install steps. Run it on a fresh VM first and read any error it prints.
