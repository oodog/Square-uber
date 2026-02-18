# setup.ps1 — Mangkok Avenue local setup (Windows)
$ErrorActionPreference = "Stop"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Mangkok Avenue — Square ↔ Uber Eats  " -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Fix PATH for this session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "`n❌  Node.js not found." -ForegroundColor Red
    Write-Host "    Install from https://nodejs.org (v18+) then re-run this script."
    exit 1
}
$nodeVer = (node --version)
Write-Host "✅  Node.js $nodeVer"

# Create .env.local from example
if (-not (Test-Path ".env.local")) {
    Write-Host "`n📋  Creating .env.local from .env.example..."
    Copy-Item ".env.example" ".env.local"

    # Generate NEXTAUTH_SECRET using Node
    $secret = node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))"
    (Get-Content ".env.local") -replace 'NEXTAUTH_SECRET="change-me-use-openssl-rand-base64-32"', "NEXTAUTH_SECRET=`"$secret`"" | Set-Content ".env.local"
    Write-Host "✅  Generated NEXTAUTH_SECRET"

    Write-Host "`n⚠️   Please edit .env.local with your credentials." -ForegroundColor Yellow
    Write-Host "    At minimum you need:" -ForegroundColor Yellow
    Write-Host "    - GOOGLE_CLIENT_ID + GOOGLE_CLIENT_SECRET (for login)" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "    Press Enter when ready"
}

# Install dependencies
Write-Host "`n📦  Installing dependencies..."
npm install

# Set up database
Write-Host "`n🗄️   Setting up database..."
$env:DATABASE_URL = "file:./prisma/dev.db"
npx prisma db push --skip-generate

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅  Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To start the app, run:" -ForegroundColor White
Write-Host "  npm run dev" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then open: http://localhost:3000" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
