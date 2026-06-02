<?php

namespace App\Http\Middleware;

use App\Models\Company;
use Closure;
use Illuminate\Http\Request;

/**
 * Blocks access if the company's subscription is expired, suspended, or cancelled.
 * Platform admins bypass this check.
 */
class CheckSubscriptionActive
{
    public function handle(Request $request, Closure $next): mixed
    {
        $user = $request->user();

        if ($user?->is_platform_admin) {
            return $next($request);
        }

        $companyId = app('tenant.company_id');

        if ($companyId) {
            $company = Company::with('subscription')->find($companyId);

            if ($company && ! $company->hasActiveSubscription()) {
                return response()->json([
                    'success' => false,
                    'message' => 'انتهى اشتراكك — يرجى تجديد الاشتراك للمتابعة',
                    'errors'  => ['subscription' => ['expired']],
                ], 402);
            }
        }

        return $next($request);
    }
}
