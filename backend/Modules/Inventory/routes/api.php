<?php

use Illuminate\Support\Facades\Route;
use Modules\Inventory\Http\Controllers\InventoryController;
use Modules\Inventory\Http\Controllers\ProductController;

Route::middleware(['auth:sanctum', 'tenant', 'subscription.active', 'module:inventory'])->prefix('v1')->group(function () {
    Route::apiResource('inventory/products', ProductController::class);
    Route::apiResource('inventories', InventoryController::class)->names('inventory');
});
