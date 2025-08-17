# Square ↔ Uber Eats Menu Sync & Order Integration

This project provides a **web portal + API** for restaurants to:

- **Sync Menu from Square to Uber Eats**
  - Import items, descriptions, and images from your Square catalog
  - Select which items to publish (checkboxes per item)
  - Apply a **% markup** globally or per-item before publishing to Uber
  - Publish as a full Uber menu or update individual items

- **Sync Orders from Uber Eats to Square**
  - Receive Uber order webhooks
  - Automatically create corresponding Square Orders
  - Preserve items, modifiers, taxes, discounts, and fulfillment info

- **Deploy Anywhere**
  - **Local development** via Docker Compose
  - **Azure App Service** deployment with App Service, Azure Database for PostgreSQL, and Key Vault for secrets

---

## Features

- Square → Uber menu sync with markup  
- Uber → Square order ingestion  
- Configurable **Config Page** for Square + Uber credentials  
- **Sync Page** to review imported items, apply markups, and publish  
- Persists data in PostgreSQL (SQLite optional for dev)  
- Secure secrets management (local `.env` or Azure Key Vault)  
- Installer script with interactive menu for Local vs Azure deployment  

---

## Architecture

web/ → React (Vite) frontend
server/ → Node.js (Express + Prisma) backend
db → PostgreSQL (local via Docker, Azure in prod)


---

## Quick Start

### 1. Run Installer

Clone and install in **one command**:

```bash
curl -sS https://raw.githubusercontent.com/oodog/Square-uber/refs/heads/main/install.sh | bash


You’ll see a menu:

Square ↔ Uber Setup
1) Install / Run Locally (Docker Compose)
2) Deploy to Azure (App Service + Postgres + Key Vault)
q) Quit


Choose 1 for Local or 2 for Azure.

2. Local Install

Creates .env from .env.example

Starts PostgreSQL + app via Docker Compose

Runs Prisma migrations + seeds DB

App runs at: http://localhost:3000

3. Azure Deploy

Creates Resource Group, ACR, Postgres (Flexible), Key Vault, App Service

Builds & pushes container image to ACR

Injects secrets from Key Vault into App Service

App runs at: https://<your-app-name>.azurewebsites.net

Requirements:

Azure CLI (az)

Logged in: az login

Docker installed

Configuration

You can configure via:

A) Config Page (recommended)

Accessible at /config. Enter:

Square

Location ID

Access Token (or use OAuth later)

Uber

Store ID

Client ID

Client Secret

Global Markup %

Click Save → stored in DB.

B) Environment Variables

.env file (local) or Key Vault (Azure):

APP_PORT=3000
NODE_ENV=production
DATABASE_URL=postgresql://postgres:secret@db:5432/menu_sync?schema=public

# Square
SQUARE_LOCATION_ID=YOUR_LOCATION_ID
SQUARE_ACCESS_TOKEN=YOUR_SQUARE_ACCESS_TOKEN

# Uber
UBER_STORE_ID=YOUR_STORE_ID
UBER_CLIENT_ID=YOUR_CLIENT_ID
UBER_CLIENT_SECRET=YOUR_CLIENT_SECRET

Usage
Import from Square

Go to /sync

Click Import from Square

Items, variations, and images load into the table

Select & Markup

Tick checkboxes for items to sync

Adjust per-item markup % (or global)

Preview final Uber payload (Preview button)

Publish to Uber

Click Publish

Syncs to Uber Marketplace Menu API

Orders Flow

Configure Uber Eats webhook to point at /api/orders/webhook

Incoming Uber orders auto-create Square Orders

Development
Run locally without installer
docker compose up --build

Prisma Migrations
docker compose exec app npx prisma migrate dev

Roadmap

 Square OAuth (instead of static access token)

 Uber OAuth / token refresh automation

 Status dashboard (last sync, errors)

 Multi-store support

License

MIT © 2025

This software is provided as-is with no support or warranty.
Use it as you like, modify it as you like, but if it breaks or requires updates, that is on you to fix.


---

Do you want me to also add a **“Screenshots” section** with placeholders (like `docs/config-page.png` and
