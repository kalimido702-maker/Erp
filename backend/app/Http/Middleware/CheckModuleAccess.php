<?php

namespace App\Http\Middleware;

use App\Models\Company;
use App\Traits\ApiResponse;
use Closure;
use Illuminate\Http\Request;

/**
 * Gate-keeps routes by module subscription.
 * Usage in routes: ->middleware('module:inventory')
 *
 * Platform admins bypass this check entirely.
 */
class CheckModuleAccess
{
    use ApiResponse;

    public function handle(Request $request, Closure $next, string $module): mixed
    {
        $user = $request->user();

        if ($user?->is_platform_admin) {
            return $next($request);
        }

        $companyId = app('tenant.company_id');

        if (! $companyId) {
            return response()->json($this->errorPayload('لم يتم تحديد الشركة', 403));
        }

        $company = Company::with('subscription.plan')->find($companyId);

        if (! $company?->canAccessModule($module)) {
            return response()->json(
                $this->errorPayload("خطة اشتراكك لا تشمل وحدة: $module", 402),
                402
            );
        }

        return $next($request);
    }

    private function errorPayload(string $message, int $status): array
    {
        return ['success' => false, 'message' => $message, 'errors' => null];
    }
}
