<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * @group System
 *
 * Infrastructure probes — public endpoints for load balancers and uptime monitors.
 */
class HealthController extends Controller
{
    use ApiResponse;

    /**
     * Health check
     *
     * Checks database connectivity and cache read/write. Returns 503 if any service is down.
     *
     * @unauthenticated
     * @response 200 {"success":true,"status":"ok","checks":{"database":"up","cache":"up"},"time":"2026-05-30T10:00:00+00:00"}
     * @response 503 {"success":false,"status":"degraded","checks":{"database":"down","cache":"up"},"time":"2026-05-30T10:00:00+00:00"}
     */
    public function __invoke(): JsonResponse
    {
        $checks = [
            'database' => $this->check(fn () => DB::connection()->getPdo() !== null),
            'cache'    => $this->check(function () {
                Cache::put('health:ping', '1', 5);
                return Cache::get('health:ping') === '1';
            }),
        ];

        $healthy = ! in_array('down', $checks, true);

        return response()->json([
            'success' => $healthy,
            'status'  => $healthy ? 'ok' : 'degraded',
            'version' => config('api.version'),
            'release' => config('api.release'),
            'checks'  => $checks,
            'time'    => now()->toIso8601String(),
        ], $healthy ? 200 : 503);
    }

    private function check(callable $probe): string
    {
        try {
            return $probe() ? 'up' : 'down';
        } catch (\Throwable) {
            return 'down';
        }
    }
}
