<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\Plan;
use App\Models\User;
use App\Services\TenantProvisioningService;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Seed plans first — provisioning depends on the starter plan existing.
        $this->call(PlanSeeder::class);

        // 2. Create the default demo company + platform admin.
        $company = Company::firstOrCreate(
            ['slug' => 'default'],
            [
                'name'      => 'Default Company',
                'email'     => 'company@erp.local',
                'currency'  => 'SAR',
                'timezone'  => 'Asia/Riyadh',
                'locale'    => 'ar',
                'is_active' => true,
                'status'    => 'active',
            ]
        );

        $admin = User::firstOrCreate(
            ['email' => 'admin@erp.local'],
            [
                'name'       => 'Super Admin',
                'password'   => bcrypt('Admin@1234'),
                'is_active'  => true,
                'company_id' => $company->id,
            ]
        );

        if (! $admin->company_id) {
            $admin->update(['company_id' => $company->id]);
        }

        // 3. Provision the company (roles, permissions, subscription).
        //    Idempotent — safe to re-run.
        $plan = Plan::where('slug', 'enterprise')->first();
        app(TenantProvisioningService::class)->provision($company, $admin, $plan);

        // Override the trial subscription with a permanent active one for the demo.
        $company->subscriptions()->update(['status' => 'active', 'expires_at' => null]);
        $company->update(['status' => 'active']);

        // 4. Create the platform admin (no company, manages the SaaS platform itself).
        User::firstOrCreate(
            ['email' => 'platform@erp.local'],
            [
                'name'              => 'Platform Admin',
                'password'          => bcrypt('Platform@1234'),
                'is_active'         => true,
                'is_platform_admin' => true,
                'company_id'        => null,
            ]
        );

        // 5. Realistic demo data (skipped automatically in production).
        $this->call(DemoSeeder::class);
    }
}
