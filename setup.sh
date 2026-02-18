#!/usr/bin/env bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Mangkok Avenue — Square ↔ Uber Eats"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Node.js
if ! command -v node &> /dev/null; then
  echo "❌  Node.js not found. Please install from https://nodejs.org (v18+)"
  exit 1
fi

NODE_VERSION=$(node -e "process.exit(parseInt(process.version.slice(1)) < 18 ? 1 : 0)" 2>/dev/null && echo "ok" || echo "old")
if [ "$NODE_VERSION" = "old" ]; then
  echo "❌  Node.js v18+ required. Current: $(node --version)"
  exit 1
fi

echo "✅  Node.js $(node --version)"

# Create .env.local if it doesn't exist
if [ ! -f .env.local ]; then
  echo ""
  echo "📋  Creating .env.local from .env.example..."
  cp .env.example .env.local

  # Generate a random NEXTAUTH_SECRET
  if command -v openssl &> /dev/null; then
    SECRET=$(openssl rand -base64 32)
    sed -i.bak "s|NEXTAUTH_SECRET=\"change-me-use-openssl-rand-base64-32\"|NEXTAUTH_SECRET=\"$SECRET\"|" .env.local
    rm -f .env.local.bak
    echo "✅  Generated NEXTAUTH_SECRET"
  fi

  echo ""
  echo "⚠️   Please edit .env.local with your credentials before continuing."
  echo "    At minimum you need:"
  echo "    - GOOGLE_CLIENT_ID + GOOGLE_CLIENT_SECRET (for login)"
  echo ""
  read -p "    Press Enter when ready, or Ctrl+C to cancel..."
fi

# Install dependencies
echo ""
echo "📦  Installing dependencies..."
npm install

# Set up database
echo ""
echo "🗄️   Setting up database..."
DATABASE_URL="file:./prisma/dev.db" npx prisma db push --skip-generate

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅  Setup complete!"
echo ""
echo "To start the app:"
echo "  npm run dev"
echo ""
echo "Then open: http://localhost:3000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
