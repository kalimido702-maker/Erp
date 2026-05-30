<?php

namespace App\Support;

use Illuminate\Support\Facades\Auth;

/**
 * Single source of truth for the current tenant (company) id.
 *
 * Resolution order:
 *   1. An explicit binding in the container (set by SetTenantFromAuth middleware,
 *      or manually inside queued jobs / console commands).
 *   2. The authenticated user's company_id.
 *
 * Falling back to the authenticated user is critical: route-model binding
 * (SubstituteBindings) runs BEFORE route middleware, so relying on the
 * container binding alone leaves a window where TenantScope is not applied —
 * which would let a user resolve another company's record via {model} binding.
 * Authenticate runs before SubstituteBindings, so Auth::user() is already
 * available at bind time and closes that gap.
 */
class TenantContext
{
    public static function companyId(): ?int
    {
        if (app()->bound('tenant.company_id')) {
            $bound = app('tenant.company_id');
            return $bound === null ? null : (int) $bound;
        }

        $user = Auth::user();

        return $user?->company_id !== null ? (int) $user->company_id : null;
    }

    public static function has(): bool
    {
        return static::companyId() !== null;
    }
}
