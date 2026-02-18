# Mangkok Avenue — Square ↔ Uber Eats Integration

A self-hosted web portal that connects your Square POS to Uber Eats.

## ✨ Features

- **Pull menu from Square** — import items, prices, images, categories
- **Price markup** — apply % or $ adjustment before pushing to Uber Eats
- **Manual menu sync** — select exactly which items go to Uber Eats
- **Auto order bridging** — Uber Eats orders automatically appear in Square as kitchen tickets (`UBER – [Customer Name]`)
- **Auto-86** — when Square inventory hits 0, the item is paused on Uber Eats
- **Google / Microsoft / Email sign-in** via NextAuth

---

## 🚀 Quick Start (3 options)

### Option 1 — Local (one command)

**Mac / Linux:**
```bash
git clone https://github.com/oodog/Square-uber.git && cd Square-uber && chmod +x setup.sh && ./setup.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/oodog/Square-uber.git; cd Square-uber; .\setup.ps1
```

Then open [http://localhost:3000](http://localhost:3000)

---

### Option 2 — Docker

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/)

```bash
git clone https://github.com/oodog/Square-uber.git
cd Square-uber
cp .env.example .env.local
# → Edit .env.local with your credentials
docker compose up -d
```

Then open [http://localhost:3000](http://localhost:3000)

To stop:
```bash
docker compose down
```

---

### Option 3 — Azure (under $10/month)

**Prerequisites:**
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure subscription](https://azure.com/free)

```bash
git clone https://github.com/oodog/Square-uber.git
cd Square-uber
cp .env.example .env.local
# → Edit .env.local with your credentials

az login
chmod +x azure/deploy.sh
./azure/deploy.sh
```

**Estimated cost:** ~$5–9/month (Azure Container Apps + Azure Files)

---

## ⚙️ Configuration

Copy `.env.example` to `.env.local` and fill in your values:

```bash
cp .env.example .env.local
```

### Required variables

| Variable | Where to get it |
|---|---|
| `NEXTAUTH_SECRET` | Run: `openssl rand -base64 32` |
| `GOOGLE_CLIENT_ID` | [Google Cloud Console](https://console.cloud.google.com) → OAuth 2.0 |
| `GOOGLE_CLIENT_SECRET` | Same as above |
| `SQUARE_APPLICATION_ID` | [Square Developer Portal](https://developer.squareup.com) |

### Square setup

1. Go to [Square Developer Portal](https://developer.squareup.com)
2. Create an application → get your **Access Token** and **Location ID**
3. Enter both in the app's **Settings** page after logging in

### Uber Eats setup

1. Go to [Uber Developer Portal](https://developer.uber.com)
2. Create an app with scopes: `eats.store eats.order`
3. Set redirect URI to: `https://your-domain.com/uber-redirect/`
4. Enter credentials in the app's **Settings** page

### Webhooks

| Service | URL |
|---|---|
| Square | `https://your-domain.com/api/webhooks/square` |
| Uber Eats | `https://your-domain.com/api/webhooks/uber` |

---

## 🔄 How it works

### Manual menu sync (your control)
1. Go to **Menu Sync** → click **Pull from Square**
2. Items are imported into the portal with their prices
3. Optionally set a price markup (e.g. +30%)
4. Select which items to push → click **Sync to Uber Eats**

### Automatic order flow (runs 24/7)
```
Customer orders on Uber Eats
        ↓
Webhook hits /api/webhooks/uber
        ↓
Square order created with "UBER – [Name]" label
        ↓
Prints on kitchen ticket
```

### Automatic 86 (out of stock)
```
Square inventory → 0
        ↓
Webhook hits /api/webhooks/square
        ↓
Item paused on Uber Eats automatically
```

---

## 🏗️ Tech stack

| Layer | Technology |
|---|---|
| Framework | Next.js 14 (App Router) |
| Language | TypeScript |
| Database | SQLite (local) / Azure Files (cloud) |
| Auth | NextAuth.js (Google, Microsoft, Email) |
| Square | Square Node.js SDK v42 |
| Uber Eats | REST API (OAuth 2.0) |
| Styling | Tailwind CSS + shadcn/ui |
| ORM | Prisma 5 |

---

## 📁 Project structure

```
src/
├── app/
│   ├── api/          # API routes
│   │   ├── square/   # Square pull-menu, test
│   │   ├── uber/     # Uber auth, sync-menu
│   │   ├── webhooks/ # Square + Uber webhooks
│   │   └── ...
│   └── dashboard/    # UI pages
│       ├── menu-sync/
│       ├── orders/
│       ├── settings/
│       └── webhooks/
├── components/       # UI components
├── lib/
│   ├── square.ts     # Square API client
│   ├── uber.ts       # Uber Eats API client
│   ├── auth.ts       # NextAuth config
│   └── prisma.ts     # Database client
prisma/
└── schema.prisma     # Database schema
azure/
├── main.bicep        # Azure infrastructure
└── deploy.sh         # Deployment script
```

---

## 🔐 Security notes

- `.env.local` is **never committed** to git
- Square and Uber credentials are stored encrypted in the database, not in config files
- Enter API keys through the **Settings** page in the UI
- Rotate your Square access token and Uber client secret regularly

---

## 📄 License

MIT — free to use and modify.
