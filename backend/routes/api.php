<?php

use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CompanyController;
use App\Http\Controllers\Api\NotificationController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::prefix('v1')->group(function () {

    Route::prefix('auth')->group(function () {
        Route::post('login', [AuthController::class, 'login']);
    });

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {

        Route::prefix('auth')->group(function () {
            Route::post('logout', [AuthController::class, 'logout']);
            Route::get('me', [AuthController::class, 'me']);
            Route::post('refresh', [AuthController::class, 'refresh']);
        });

        // Modules routes are registered automatically by nwidart/laravel-modules

        // Notifications
        Route::prefix('notifications')->group(function () {
            Route::get('/', [NotificationController::class, 'index']);
            Route::get('unread-count', [NotificationController::class, 'unreadCount']);
            Route::patch('{id}/read', [NotificationController::class, 'markRead']);
            Route::post('read-all', [NotificationController::class, 'markAllRead']);
        });

        // Broadcasting auth (for private channels)
        Route::post('broadcasting/auth', function (\Illuminate\Http\Request $request) {
            return \Illuminate\Support\Facades\Broadcast::auth($request);
        });

        Route::middleware('tenant')->group(function () {
            Route::get('audit-logs', [AuditLogController::class, 'index']);
            Route::get('audit-logs/{type}/{id}', [AuditLogController::class, 'forModel']);
            Route::get('company', [CompanyController::class, 'show']);
            Route::put('company', [CompanyController::class, 'update']);
        });
    });
});
