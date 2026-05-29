#!/bin/bash
set -e

echo "========================================="
echo "  ERP System - Initial Setup"
echo "========================================="

# Copy env if not exists
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✓ Created .env from .env.example"
fi

# Start Docker services
echo "Starting Docker services..."
docker compose up -d mysql redis

echo "Waiting for MySQL to be ready..."
sleep 10

# Run Laravel setup
echo "Setting up Laravel backend..."
docker compose run --rm php bash -c "
    composer install --no-interaction &&
    php artisan migrate --force &&
    php artisan db:seed --force &&
    php artisan storage:link &&
    php artisan optimize
"

# Start all services
docker compose up -d

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "  Backend API:    http://localhost/api/v1"
echo "  phpMyAdmin:     http://localhost:8080"
echo ""
echo "  Default Login:"
echo "  Email:    admin@erp.local"
echo "  Password: Admin@1234"
echo ""
