<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Controls which origins may call the API from a browser. The Flutter app
    | on Web/Desktop sends an Origin header, so these must be configured or
    | requests will be blocked by the browser's same-origin policy.
    |
    | Allowed origins are driven by the CORS_ALLOWED_ORIGINS env var
    | (comma-separated) so production domains can be set without code changes.
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie', 'broadcasting/auth', 'docs', 'docs/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_filter(
        explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost,http://localhost:3000,http://127.0.0.1:8000'))
    ),

    'allowed_origins_patterns' => array_filter(
        explode(',', (string) env('CORS_ALLOWED_ORIGIN_PATTERNS', ''))
    ),

    'allowed_headers' => ['*'],

    // Expose pagination/rate-limit headers so the Flutter client can read them.
    'exposed_headers' => [
        'X-RateLimit-Limit',
        'X-RateLimit-Remaining',
        'Retry-After',
    ],

    'max_age' => 3600,

    // Required true only when using Sanctum cookie-based (SPA) auth.
    // Token-based auth (mobile/desktop) does not need credentials.
    'supports_credentials' => env('CORS_SUPPORTS_CREDENTIALS', true),

];
