<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Sentry\State\Scope;
use Symfony\Component\HttpFoundation\Response;

use function Sentry\configureScope;

/**
 * Attaches the authenticated user to the Sentry scope so every error report
 * includes who was affected (id, email, company_id). Safe to use in production
 * — no PII is sent if SENTRY_SEND_DEFAULT_PII=false (the default).
 * When DSN is not configured this is a no-op.
 */
class SentryContext
{
    public function handle(Request $request, Closure $next): Response
    {
        if (app()->bound('sentry') && $request->user()) {
            configureScope(function (Scope $scope) use ($request): void {
                $user = $request->user();
                $scope->setUser([
                    'id'         => $user->id,
                    'email'      => $user->email,
                    'company_id' => $user->company_id,
                ]);
            });
        }

        return $next($request);
    }
}
