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

