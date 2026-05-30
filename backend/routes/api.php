<?php

use App\Http\Controllers\Api\AttachmentController;
use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CompanyController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PdfController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::prefix('v1')->group(function () {

    // Infrastructure health probe (DB + cache)
    Route::get('health', \App\Http\Controllers\Api\HealthController::class);

    Route::prefix('auth')->group(function () {
        // Brute-force protection: 5 attempts / minute per email+IP.
        Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
    });

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {

        Route::prefix('auth')->group(function () {
            Route::post('logout', [AuthController::class, 'logout']);
            Route::get('me', [AuthController::class, 'me']);
            Route::post('refresh', [AuthController::class, 'refresh']);

            // Two-factor enrolment / management
            Route::post('2fa/enable', [\App\Http\Controllers\Api\TwoFactorController::class, 'enable']);
            Route::post('2fa/confirm', [\App\Http\Controllers\Api\TwoFactorController::class, 'confirm']);
            Route::post('2fa/disable', [\App\Http\Controllers\Api\TwoFactorController::class, 'disable']);
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

        // PDF generation (allowlisted views only)
        Route::post('pdf/generate', [PdfController::class, 'generate']);

        Route::middleware('tenant')->group(function () {
            Route::get('audit-logs', [AuditLogController::class, 'index']);
            Route::get('audit-logs/{type}/{id}', [AuditLogController::class, 'forModel']);
            Route::get('company', [CompanyController::class, 'show']);
            Route::put('company', [CompanyController::class, 'update']);

            // Polymorphic file attachments (works for any morph-mapped model)
            Route::get('attachments/{type}/{id}', [AttachmentController::class, 'index']);
            Route::post('attachments', [AttachmentController::class, 'store']);
            Route::delete('attachments/{attachment}', [AttachmentController::class, 'destroy']);
        });
    });
});
