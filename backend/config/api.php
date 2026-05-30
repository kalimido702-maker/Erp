<?php

return [

    /*
    |--------------------------------------------------------------------------
    | API Versioning
    |--------------------------------------------------------------------------
    |
    | All API routes are prefixed with a URL version segment (e.g. /api/v1).
    | This is the single source of truth for the *current* version. When a
    | breaking change is required, introduce a new prefix (v2) ALONGSIDE v1
    | rather than mutating v1 in place — existing mobile/desktop clients keep
    | working until they upgrade.
    |
    | Strategy (URL-based versioning):
    |   - routes/api.php groups everything under prefix('v1').
    |   - Non-breaking additions (new fields, new endpoints) go into v1.
    |   - Breaking changes (renamed/removed fields, changed semantics) require
    |     a new prefix('v2') group; old controllers stay until v1 is retired.
    |
    */

    'version'           => env('API_VERSION', 'v1'),

    // Versions still served (for the health endpoint / docs). Oldest first.
    'supported_versions' => ['v1'],

    // Human-readable build identifier surfaced by /health.
    'release'           => env('APP_RELEASE', 'dev'),

];
