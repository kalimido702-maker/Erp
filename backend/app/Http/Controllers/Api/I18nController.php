<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Translation;
use App\Traits\ApiResponse;
use Illuminate\Support\Facades\Auth;

/**
 * Serves UI translations to clients with a tenant-aware, override-capable model.
 *
 * Endpoints are public (needed before login). When a bearer token is present we
 * resolve the tenant on demand so a logged-in user gets their company's
 * supported locales and string overrides.
 *
 * @group Localization
 */
class I18nController extends Controller
{
    use ApiResponse;

    /**
     * Localization manifest — which languages this client should offer.
     *
     * @response { "success": true, "message": "Success", "data": { "locales": ["ar","en"], "default": "ar", "version": "a1b2c3" } }
     */
    public function manifest()
    {
        $company = $this->resolveCompany();

        $locales = $company
            ? $company->supportedLocaleCodes()
            : config('i18n.default_locales', ['ar', 'en']);

        $default = $company?->locale ?? config('i18n.fallback', 'ar');

        return $this->success([
            'locales' => array_values($locales),
            'default' => $default,
            'version' => $this->version($company),
        ]);
    }

    /**
     * Flat translation table for a locale: base platform strings merged with
     * any tenant overrides (overrides win).
     *
     * @urlParam locale string required The language code. Example: ar
     * @response { "success": true, "message": "Success", "data": { "auth.login": "تسجيل الدخول" } }
     */
    public function strings(string $locale)
    {
        if (! in_array($locale, config('i18n.available_locales', ['ar', 'en']), true)) {
            $locale = config('i18n.fallback', 'ar');
        }

        $base = $this->flatten($this->loadBase($locale));

        $overrides = Translation::query()
            ->where('locale', $locale)
            ->pluck('value', 'key')
            ->all();

        return $this->success(array_merge($base, $overrides));
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    /**
     * Resolve the tenant from a bearer token if one is supplied (optional auth).
     */
    protected function resolveCompany(): ?Company
    {
        return Auth::guard('sanctum')->user()?->company;
    }

    protected function loadBase(string $locale): array
    {
        $path = rtrim(config('i18n.base_path'), '/')."/{$locale}.json";
        if (! is_file($path)) {
            return [];
        }

        return json_decode(file_get_contents($path), true) ?: [];
    }

    /**
     * Flatten nested arrays into dotted keys: ['auth' => ['login' => '..']]
     * becomes ['auth.login' => '..'].
     */
    protected function flatten(array $data, string $prefix = ''): array
    {
        $out = [];
        foreach ($data as $key => $value) {
            $composed = $prefix === '' ? $key : "{$prefix}.{$key}";
            if (is_array($value)) {
                $out += $this->flatten($value, $composed);
            } else {
                $out[$composed] = (string) $value;
            }
        }

        return $out;
    }

    /**
     * A cheap cache-busting version: base-file mtimes + the tenant's latest
     * override timestamp. Changes whenever any source string changes.
     */
    protected function version(?Company $company): string
    {
        $parts = [];
        foreach (config('i18n.available_locales', ['ar', 'en']) as $locale) {
            $path = rtrim(config('i18n.base_path'), '/')."/{$locale}.json";
            $parts[] = is_file($path) ? (string) filemtime($path) : '0';
        }

        $latestOverride = Translation::query()->max('updated_at');
        $parts[] = (string) $latestOverride;
        $parts[] = (string) ($company?->id ?? 0);

        return substr(md5(implode('|', $parts)), 0, 12);
    }
}
