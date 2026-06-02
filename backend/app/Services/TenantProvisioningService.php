<?php

namespace App\Services;

use App\Models\Company;
use App\Models\CompanySubscription;
use App\Models\Plan;
use App\Models\User;
use App\Traits\HandlesTransactions;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

/**
 * Called once when a new tenant is created (self-registration or platform-admin creation).
 * Sets up default roles, permissions, settings, and trial subscription.
 */
class TenantProvisioningService
{
    use HandlesTransactions;

    /** All permissions that can exist within a single tenant. */
    public const TENANT_PERMISSIONS = [
        // Users & roles
        'users.view', 'users.create', 'users.edit', 'users.delete',
        'roles.view', 'roles.create', 'roles.edit', 'roles.delete',
        // Branches
        'branches.view', 'branches.create', 'branches.edit', 'branches.delete',
        // Settings
        'settings.view', 'settings.edit',
        // Inventory
        'products.view', 'products.create', 'products.edit', 'products.delete',
        // Sales
        'sales.view', 'sales.create', 'sales.edit', 'sales.delete',
        // Purchases
        'purchases.view', 'purchases.create', 'purchases.edit', 'purchases.delete',
        // HR
        'hr.view', 'hr.create', 'hr.edit', 'hr.delete',
        // Finance
        'finance.view', 'finance.create', 'finance.edit', 'finance.delete',
        // Accounting
        'accounting.view', 'accounting.create', 'accounting.edit', 'accounting.delete',
    ];

    /**
     * Provision a freshly created company:
     * - Create company-scoped roles + seed permissions
     * - Assign the admin user the super-admin role
     * - Start a trial subscription on the given plan (defaults to the free plan)
     */
    public function provision(Company $company, User $admin, ?Plan $plan = null): void
    {
        $this->transaction(function () use ($company, $admin, $plan) {
            $this->seedPermissions();
            $this->createCompanyRoles($company);
            $this->assignAdminRole($admin);
            $this->startTrial($company, $plan ?? $this->defaultPlan());
        });
    }

    private function seedPermissions(): void
    {
        foreach (self::TENANT_PERMISSIONS as $name) {
            Permission::firstOrCreate(['name' => $name, 'guard_name' => 'sanctum']);
        }
    }

    private function createCompanyRoles(Company $company): void
    {
        $superAdmin = Role::firstOrCreate(['name' => 'super-admin', 'guard_name' => 'sanctum']);
        $admin      = Role::firstOrCreate(['name' => 'admin',       'guard_name' => 'sanctum']);
        $employee   = Role::firstOrCreate(['name' => 'employee',    'guard_name' => 'sanctum']);

        // super-admin: full access (also short-circuits via BasePolicy::before())
        $superAdmin->syncPermissions(Permission::all());

        // admin: everything except user/role deletion
        $admin->syncPermissions(
            Permission::whereNotIn('name', ['users.delete', 'roles.create', 'roles.edit', 'roles.delete'])->get()
        );

        // employee: day-to-day read + create/edit, no delete, no financial
        $employee->syncPermissions([
            'products.view', 'products.create', 'products.edit',
            'sales.view', 'sales.create', 'sales.edit',
            'purchases.view', 'purchases.create', 'purchases.edit',
            'branches.view', 'settings.view',
        ]);
    }

    private function assignAdminRole(User $admin): void
    {
        $admin->assignRole('super-admin');
    }

    private function startTrial(Company $company, Plan $plan): void
    {
        CompanySubscription::create([
            'company_id'    => $company->id,
            'plan_id'       => $plan->id,
            'status'        => 'trial',
            'trial_ends_at' => now()->addDays($plan->trial_days),
        ]);
    }

    private function defaultPlan(): Plan
    {
        return Plan::where('slug', 'starter')->firstOrFail();
    }
}
