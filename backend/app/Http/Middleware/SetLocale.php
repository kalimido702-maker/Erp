<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Resolves the request language and sets it as the app locale, so any
 * translatable DATA (see HasTranslations) is returned in the right language.
 *
 * Precedence: `?locale=` query → `Accept-Language` header → platform fallback.
 * Only locales the platform ships are honoured; anything else falls back.
 */
class SetLocale
{
    public function handle(Request $request, Closure $next): Response
    {
        $available = config('i18n.available_locales', ['ar', 'en']);
        $fallback = config('i18n.fallback', 'ar');

        $requested = $request->query('locale')
            ?? $request->header('Accept-Language')
            ?? $fallback;

        // Take the primary 2-letter subtag (e.g. "en-US,en;q=0.9" → "en").
        $requested = strtolower(substr(trim(explode(',', (string) $requested)[0]), 0, 2));

        app()->setLocale(in_array($requested, $available, true) ? $requested : $fallback);

        return $next($request);
    }
}
