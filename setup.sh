#!/bin/bash

# setup.sh - Creates all necessary files for Square-Uber integration
# Run this in your Square-uber directory

set -e

echo "🚀 Square-Uber Complete Setup Script"
echo "===================================="
echo ""
echo "This script will create all necessary files for your Square-Uber integration."
echo ""

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p server/{routes,controllers,services,utils,prisma,middleware}
mkdir -p web/{src/{components,pages,services,utils},public}

# Create root package.json
echo "📦 Creating root package.json..."
cat > package.json << 'ENDFILE'
{
  "name": "square-uber-integration",
  "version": "1.0.0",
  "description": "Square to Uber Eats Menu Sync Application",
  "scripts": {
    "dev": "concurrently \\"npm run server:dev\\" \\"npm run web:dev\\"",
    "start": "npm run server:start",
    "server:dev": "cd server && npm run dev",
    "server:start": "cd server && npm start",
    "web:dev": "cd web && npm run dev",
    "web:build": "cd web && npm run build",
    "install:all": "npm install && cd server && npm install && cd ../web && npm install",
    "setup:db": "cd server && npx prisma migrate deploy && npx prisma generate",
    "prisma:studio": "cd server && npx prisma studio",
    "docker:up": "docker-compose up --build",
    "docker:down": "docker-compose down",
    "docker:reset": "docker-compose down -v && docker-compose up --build"
  },
  "devDependencies": {
    "concurrently": "^8.2.2"
  }
}
ENDFILE

# Create server package.json
echo "📦 Creating server/package.json..."
cat > server/package.json << 'ENDFILE'
{
  "name": "square-uber-server",
  "version": "1.0.0",
  "description": "Square-Uber Integration Backend",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:deploy": "prisma migrate deploy",
    "prisma:studio": "prisma studio"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "@prisma/client": "^5.7.0",
    "axios": "^1.6.2",
    "body-parser": "^1.20.2",
    "square": "^33.0.0",
    "morgan": "^1.10.0",
    "helmet": "^7.1.0",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "prisma": "^5.7.0"
  }
}
ENDFILE

# Create web package.json
echo "📦 Creating web/package.json..."
cat > web/package.json << 'ENDFILE'
{
  "name": "square-uber-web",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.1",
    "axios": "^1.6.2",
    "@mui/material": "^5.14.20",
    "@emotion/react": "^11.11.1",
    "@emotion/styled": "^11.11.0",
    "@mui/icons-material": "^5.14.19"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^5.0.7"
  }
}
ENDFILE

# Create Prisma schema
echo "🗄️  Creating Prisma schema..."
cat > server/prisma/schema.prisma << 'ENDFILE'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Config {
  id                String   @id @default(cuid())
  squareLocationId  String?
  squareAccessToken String?
  uberStoreId       String?
  uberClientId      String?
  uberClientSecret  String?
  defaultMarkup     Float    @default(15)
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt
}

model MenuItem {
  id            String    @id @default(cuid())
  squareId      String    @unique
  name          String
  description   String?
  price         Float
  imageUrl      String?
  category      String?
  isActive      Boolean   @default(true)
  markup        Float     @default(0)
  syncToUber    Boolean   @default(false)
  lastSyncedAt  DateTime?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}

model Order {
  id           String   @id @default(cuid())
  uberId       String   @unique
  squareId     String?
  status       String
  total        Float
  items        Json
  customerInfo Json?
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
ENDFILE

# Create server index.js (minified for space)
echo "🖥️  Creating server/index.js..."
cat > server/index.js << 'ENDFILE'
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.APP_PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Config endpoints
app.get('/api/config', async (req, res) => {
  try {
    const config = await prisma.config.findFirst();
    res.json(config || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch configuration' });
  }
});

app.post('/api/config', async (req, res) => {
  try {
    const config = await prisma.config.findFirst();
    const data = {
      squareLocationId: req.body.squareLocationId,
      squareAccessToken: req.body.squareAccessToken,
      uberStoreId: req.body.uberStoreId,
      uberClientId: req.body.uberClientId,
      uberClientSecret: req.body.uberClientSecret,
      defaultMarkup: parseFloat(req.body.defaultMarkup) || 15
    };
    
    let result;
    if (config) {
      result = await prisma.config.update({
        where: { id: config.id },
        data
      });
    } else {
      result = await prisma.config.create({ data });
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Failed to save configuration' });
  }
});

// Square menu import
app.get('/api/square/menu', async (req, res) => {
  try {
    // Mock data for testing
    const mockItems = [
      { id: 'item1', name: 'Burger', description: 'Delicious burger', price: 12.99 },
      { id: 'item2', name: 'Pizza', description: 'Cheese pizza', price: 15.99 },
      { id: 'item3', name: 'Salad', description: 'Fresh salad', price: 8.99 }
    ];
    
    for (const item of mockItems) {
      await prisma.menuItem.upsert({
        where: { squareId: item.id },
        update: { name: item.name, description: item.description, price: item.price },
        create: { squareId: item.id, name: item.name, description: item.description, price: item.price }
      });
    }
    
    const menuItems = await prisma.menuItem.findMany();
    res.json(menuItems);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch menu' });
  }
});

// Update menu item
app.put('/api/menu/:id', async (req, res) => {
  try {
    const updated = await prisma.menuItem.update({
      where: { id: req.params.id },
      data: req.body
    });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update item' });
  }
});

// Sync to Uber
app.post('/api/uber/sync', async (req, res) => {
  try {
    const itemsToSync = await prisma.menuItem.findMany({
      where: { syncToUber: true }
    });
    
    await prisma.menuItem.updateMany({
      where: { syncToUber: true },
      data: { lastSyncedAt: new Date() }
    });
    
    res.json({ success: true, syncedCount: itemsToSync.length });
  } catch (error) {
    res.status(500).json({ error: 'Failed to sync' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(\`✅ Server running on port \${PORT}\`);
});
ENDFILE

# Create web files
echo "🎨 Creating web application files..."

# Create vite.config.js
cat > web/vite.config.js << 'ENDFILE'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      }
    }
  }
})
ENDFILE

# Create index.html
cat > web/index.html << 'ENDFILE'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Square-Uber Integration</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
ENDFILE

# Create main.jsx
cat > web/src/main.jsx << 'ENDFILE'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
ENDFILE

# Create simple App.jsx
cat > web/src/App.jsx << 'ENDFILE'
import React, { useState, useEffect } from 'react';
import axios from 'axios';

function App() {
  const [config, setConfig] = useState({});
  const [menuItems, setMenuItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      const response = await axios.get('/api/config');
      setConfig(response.data);
    } catch (error) {
      console.error('Error:', error);
    }
  };

  const saveConfig = async () => {
    setLoading(true);
    try {
      await axios.post('/api/config', config);
      setMessage('Configuration saved!');
    } catch (error) {
      setMessage('Error saving configuration');
    }
    setLoading(false);
  };

  const importMenu = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/square/menu');
      setMenuItems(response.data);
      setMessage(`Imported ${response.data.length} items`);
    } catch (error) {
      setMessage('Error importing menu');
    }
    setLoading(false);
  };

  const syncToUber = async () => {
    setLoading(true);
    try {
      const response = await axios.post('/api/uber/sync');
      setMessage(`Synced ${response.data.syncedCount} items to Uber`);
    } catch (error) {
      setMessage('Error syncing to Uber');
    }
    setLoading(false);
  };

  const updateItem = async (id, field, value) => {
    try {
      await axios.put(`/api/menu/${id}`, { [field]: value });
      setMenuItems(items => 
        items.map(item => 
          item.id === id ? { ...item, [field]: value } : item
        )
      );
    } catch (error) {
      console.error('Error updating item:', error);
    }
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>Square-Uber Integration</h1>
      
      {message && (
        <div style={{ padding: '10px', background: '#f0f0f0', marginBottom: '20px' }}>
          {message}
        </div>
      )}

      <div style={{ marginBottom: '30px' }}>
        <h2>Configuration</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', maxWidth: '600px' }}>
          <input
            placeholder="Square Location ID"
            value={config.squareLocationId || ''}
            onChange={(e) => setConfig({...config, squareLocationId: e.target.value})}
            style={{ padding: '8px' }}
          />
          <input
            placeholder="Square Access Token"
            type="password"
            value={config.squareAccessToken || ''}
            onChange={(e) => setConfig({...config, squareAccessToken: e.target.value})}
            style={{ padding: '8px' }}
          />
          <input
            placeholder="Uber Store ID"
            value={config.uberStoreId || ''}
            onChange={(e) => setConfig({...config, uberStoreId: e.target.value})}
            style={{ padding: '8px' }}
          />
          <input
            placeholder="Uber Client ID"
            value={config.uberClientId || ''}
            onChange={(e) => setConfig({...config, uberClientId: e.target.value})}
            style={{ padding: '8px' }}
          />
          <input
            placeholder="Uber Client Secret"
            type="password"
            value={config.uberClientSecret || ''}
            onChange={(e) => setConfig({...config, uberClientSecret: e.target.value})}
            style={{ padding: '8px' }}
          />
          <input
            placeholder="Default Markup %"
            type="number"
            value={config.defaultMarkup || 15}
            onChange={(e) => setConfig({...config, defaultMarkup: parseFloat(e.target.value)})}
            style={{ padding: '8px' }}
          />
        </div>
        <button 
          onClick={saveConfig} 
          disabled={loading}
          style={{ marginTop: '10px', padding: '10px 20px' }}
        >
          Save Configuration
        </button>
      </div>

      <div>
        <h2>Menu Sync</h2>
        <div style={{ marginBottom: '20px' }}>
          <button 
            onClick={importMenu} 
            disabled={loading}
            style={{ padding: '10px 20px', marginRight: '10px' }}
          >
            Import from Square
          </button>
          <button 
            onClick={syncToUber} 
            disabled={loading || menuItems.filter(i => i.syncToUber).length === 0}
            style={{ padding: '10px 20px' }}
          >
            Sync to Uber
          </button>
        </div>

        {menuItems.length > 0 && (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #ddd' }}>
                <th style={{ padding: '10px', textAlign: 'left' }}>Sync</th>
                <th style={{ padding: '10px', textAlign: 'left' }}>Name</th>
                <th style={{ padding: '10px', textAlign: 'left' }}>Price</th>
                <th style={{ padding: '10px', textAlign: 'left' }}>Markup %</th>
                <th style={{ padding: '10px', textAlign: 'left' }}>Final Price</th>
              </tr>
            </thead>
            <tbody>
              {menuItems.map((item) => (
                <tr key={item.id} style={{ borderBottom: '1px solid #eee' }}>
                  <td style={{ padding: '10px' }}>
                    <input
                      type="checkbox"
                      checked={item.syncToUber || false}
                      onChange={(e) => updateItem(item.id, 'syncToUber', e.target.checked)}
                    />
                  </td>
                  <td style={{ padding: '10px' }}>{item.name}</td>
                  <td style={{ padding: '10px' }}>${item.price?.toFixed(2)}</td>
                  <td style={{ padding: '10px' }}>
                    <input
                      type="number"
                      value={item.markup || config.defaultMarkup || 15}
                      onChange={(e) => updateItem(item.id, 'markup', parseFloat(e.target.value))}
                      style={{ width: '60px', padding: '5px' }}
                    />
                  </td>
                  <td style={{ padding: '10px' }}>
                    ${(item.price * (1 + (item.markup || config.defaultMarkup || 15) / 100)).toFixed(2)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

export default App;
