<?php

namespace App\Policies;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;

/**
 * Shared helpers used by every module policy.
 *
 * Convention: a super-admin always passes every gate.  Module policies only
 * need to implement tenant-scoped logic; they should call parent::before()
 * (or use the gate before-check) to let super-admins through automatically.
 */
abstract class BasePolicy
{
    /**
     * Allow super-admins to bypass all checks.
     * Returning null continues to the individual method.
     */
    public function before(User $user, string $ability): ?bool
    {
        return $user->hasRole('super-admin') ? true : null;
    }

    // ── protected helpers ───────────────────────────────────────────────

    protected function sameCompany(User $user, Model $model): bool
    {
        return property_exists($model, 'company_id')
            && (int) $model->company_id === (int) $user->company_id;
    }

    protected function hasPermission(User $user, string $permission): bool
    {
        return $user->hasPermissionTo($permission);
    }

    protected function isAdmin(User $user): bool
    {
        return $user->hasRole(['super-admin', 'admin']);
    }
}
