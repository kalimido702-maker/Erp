<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        $this->configureRateLimiting();

        // Stable polymorphic aliases for mapped models (e.g. products). Use the
        // non-strict morphMap so unmapped models (User/Role via Sanctum/Spatie)
        // keep working with their default class-name morph type.
        Relation::morphMap(config('morph_map', []));
    }

    /**
     * Named rate limiters used across the API.
     *
     *  - "login": brute-force protection. 5 tries / minute keyed by email+IP,
     *    so one attacker can't lock out a victim from a different IP.
     *  - "api":   general abuse protection. 90 requests / minute per
     *    authenticated user (falls back to IP for guests).
     */
    protected function configureRateLimiting(): void
    {
        RateLimiter::for('login', function (Request $request) {
            $key = Str::lower((string) $request->input('email')).'|'.$request->ip();

            return [
                Limit::perMinute(5)->by($key),
                Limit::perMinute(20)->by($request->ip()),
            ];
        });

        RateLimiter::for('api', function (Request $request) {
            return $request->user()
                ? Limit::perMinute(90)->by('user:'.$request->user()->id)
                : Limit::perMinute(30)->by('ip:'.$request->ip());
        });
    }
}
