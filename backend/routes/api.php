<?php

use App\Http\Controllers\Api\AttachmentController;
use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CompanyController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PdfController;
use App\Http\Controllers\Api\PlatformAdminController;
use App\Http\Controllers\Api\RegistrationController;
use App\Http\Controllers\Api\SubscriptionController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::prefix('v1')->group(function () {

    // Infrastructure health probe (DB + cache)
    Route::get('health', \App\Http\Controllers\Api\HealthController::class);

    // Public plans list (shown on pricing / registration page)
    Route::get('plans', [SubscriptionController::class, 'plans']);

    // Localization — public so clients can load strings before login. Both are
    // tenant-aware when a bearer token is present (optional auth).
    Route::get('i18n/manifest', [\App\Http\Controllers\Api\I18nController::class, 'manifest']);
    Route::get('i18n/{locale}', [\App\Http\Controllers\Api\I18nController::class, 'strings'])
        ->where('locale', '[a-zA-Z\-]{2,8}');

    // Tenant self-registration — rate-limited to prevent abuse
    Route::post('register', [RegistrationController::class, 'register'])->middleware('throttle:5,1');

    Route::prefix('auth')->group(function () {
        // Brute-force protection: 5 attempts / minute per email+IP.
        Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
    });

    // ── Authenticated routes ────────────────────────────────────────────
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

        // Module routes are registered automatically by nwidart/laravel-modules.
        // Wrap them with: middleware(['tenant', 'subscription.active', 'module:inventory'])

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

        // Subscription info for the current company
        Route::get('subscription', [SubscriptionController::class, 'show'])
            ->middleware('tenant');

        // ── Tenant-scoped routes ────────────────────────────────────────
        Route::middleware(['tenant', 'subscription.active'])->group(function () {
            Route::get('audit-logs', [AuditLogController::class, 'index']);
            Route::get('audit-logs/{type}/{id}', [AuditLogController::class, 'forModel']);
            Route::get('company', [CompanyController::class, 'show']);
            Route::put('company', [CompanyController::class, 'update']);

            // Polymorphic file attachments (works for any morph-mapped model)
            Route::get('attachments/{type}/{id}', [AttachmentController::class, 'index']);
            Route::post('attachments', [AttachmentController::class, 'store']);
            Route::delete('attachments/{attachment}', [AttachmentController::class, 'destroy']);
        });

        // ── Platform admin routes (is_platform_admin = true only) ───────
        Route::middleware('platform.admin')->prefix('platform')->group(function () {
            Route::get('companies', [PlatformAdminController::class, 'listCompanies']);
            Route::get('companies/{company}', [PlatformAdminController::class, 'showCompany']);
            Route::post('companies/{company}/suspend', [PlatformAdminController::class, 'suspendCompany']);
            Route::post('companies/{company}/activate', [PlatformAdminController::class, 'activateCompany']);
            Route::post('companies/{company}/plan', [PlatformAdminController::class, 'assignPlan']);
            Route::get('plans', [PlatformAdminController::class, 'listPlans']);
        });
    });
});
