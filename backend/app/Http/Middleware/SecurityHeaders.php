<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Adds baseline hardening headers to every API response. These are cheap,
 * always-on protections that every endpoint inherits.
 */
class SecurityHeaders
{
    /**
     * The hardening headers, exposed so error responses (which bypass the
     * middleware pipeline) can carry the same set via the exception renderer.
     *
     * @return array<string,string>
     */
    public static function headers(): array
    {
        return [
            'X-Content-Type-Options' => 'nosniff',
            'X-Frame-Options'        => 'DENY',
            'Referrer-Policy'        => 'no-referrer',
            'X-XSS-Protection'       => '1; mode=block',
            'Permissions-Policy'     => 'geolocation=(), microphone=(), camera=()',
        ];
    }

    public function handle(Request $request, Closure $next): Response
    {
        /** @var Response $response */
        $response = $next($request);

        foreach (self::headers() as $key => $value) {
            if (! $response->headers->has($key)) {
                $response->headers->set($key, $value);
            }
        }

        return $response;
    }
}
