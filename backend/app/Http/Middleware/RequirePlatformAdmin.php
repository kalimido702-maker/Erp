<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/**
 * Restricts routes to platform-level admins only (is_platform_admin = true).
 * These are NOT company users — they manage the SaaS platform itself.
 */
class RequirePlatformAdmin
{
    public function handle(Request $request, Closure $next): mixed
    {
        if (! $request->user()?->is_platform_admin) {
            return response()->json([
                'success' => false,
                'message' => 'غير مصرح',
                'errors'  => null,
            ], 403);
        }

        return $next($request);
    }
}
