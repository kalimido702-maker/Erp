<?php

namespace Tests\Feature\SaaS;

use App\Models\Company;
use App\Models\CompanySubscription;
use App\Models\Plan;
use App\Models\User;
use Database\Seeders\PlanSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PlatformAdminTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(PlanSeeder::class);
    }

    public function test_platform_admin_can_list_companies(): void
    {
        $platform = $this->makePlatformAdmin();

        Company::factory()->count(3)->create();

        $this->actingAs($platform)
            ->getJson('/api/v1/platform/companies')
            ->assertOk()
            ->assertJsonPath('success', true);
    }

    public function test_regular_user_cannot_access_platform_routes(): void
    {
        $company = Company::factory()->create();
        $user    = User::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user)
            ->getJson('/api/v1/platform/companies')
            ->assertStatus(403);
    }

    public function test_platform_admin_can_suspend_and_activate_company(): void
    {
        $platform = $this->makePlatformAdmin();
        $company  = Company::factory()->create(['is_active' => true, 'status' => 'active']);

        $this->actingAs($platform)
            ->postJson("/api/v1/platform/companies/{$company->id}/suspend")
            ->assertOk();

        $this->assertDatabaseHas('companies', ['id' => $company->id, 'status' => 'suspended']);

        $this->actingAs($platform)
            ->postJson("/api/v1/platform/companies/{$company->id}/activate")
            ->assertOk();

        $this->assertDatabaseHas('companies', ['id' => $company->id, 'status' => 'active']);
    }

    public function test_platform_admin_can_assign_plan(): void
    {
        $platform = $this->makePlatformAdmin();
        $company  = Company::factory()->create();
        $plan     = Plan::where('slug', 'growth')->first();

        $this->actingAs($platform)
            ->postJson("/api/v1/platform/companies/{$company->id}/plan", [
                'plan_id' => $plan->id,
            ])
            ->assertOk();

        $this->assertDatabaseHas('company_subscriptions', [
            'company_id' => $company->id,
            'plan_id'    => $plan->id,
            'status'     => 'active',
        ]);
    }

    private function makePlatformAdmin(): User
    {
        return User::factory()->create([
            'is_platform_admin' => true,
            'company_id'        => null,
        ]);
    }
}
