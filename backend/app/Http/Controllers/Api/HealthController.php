<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * Lightweight liveness/readiness probe for load balancers, Docker health
 * checks and uptime monitors. Public (no auth) so infra can reach it.
 */
class HealthController extends Controller
{
    use ApiResponse;

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
