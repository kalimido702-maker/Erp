<?php

namespace Tests\Feature\SaaS;

use App\Models\Company;
use App\Models\CompanySubscription;
use App\Models\Plan;
use App\Models\User;
use Database\Seeders\PlanSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ModuleAccessTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(PlanSeeder::class);
    }

    public function test_company_with_module_can_access_it(): void
    {
        [$user] = $this->makeCompanyWithPlan('starter'); // includes inventory

        $this->assertTrue($user->company->canAccessModule('inventory'));
        $this->assertFalse($user->company->canAccessModule('hr'));
    }

    public function test_subscription_blocks_expired_tenant(): void
    {
        [$user] = $this->makeCompanyWithPlan('starter');

        $user->company->subscription->update([
            'status'        => 'trial',
            'trial_ends_at' => now()->subDay(),
        ]);

        $this->assertFalse($user->company->hasActiveSubscription());
    }

    public function test_platform_admin_bypasses_module_check(): void
    {
        $platform = User::factory()->create([
            'is_platform_admin' => true,
            'company_id'        => null,
        ]);

        // Platform admin has no company, but is_platform_admin bypasses everything.
        $this->assertTrue($platform->is_platform_admin);
    }

    private function makeCompanyWithPlan(string $planSlug): array
    {
        $plan = Plan::where('slug', $planSlug)->first();

        $company = Company::factory()->create(['is_active' => true, 'status' => 'active']);

        CompanySubscription::create([
            'company_id' => $company->id,
            'plan_id'    => $plan->id,
            'status'     => 'active',
            'started_at' => now(),
        ]);

        $user = User::factory()->create(['company_id' => $company->id]);

        return [$user, $company];
    }
}
