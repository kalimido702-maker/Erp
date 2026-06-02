<?php

namespace Tests\Feature\SaaS;

use App\Models\Company;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TenantRegistrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(\Database\Seeders\PlanSeeder::class);
    }

    public function test_new_tenant_can_self_register(): void
    {
        $response = $this->postJson('/api/v1/register', [
            'company_name'          => 'شركة الاختبار',
            'name'                  => 'مدير الاختبار',
            'email'                 => 'test@company.com',
            'password'              => 'Secret@1234',
            'password_confirmation' => 'Secret@1234',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['token', 'user', 'company']]);

        $this->assertDatabaseHas('companies', ['name' => 'شركة الاختبار', 'status' => 'trial']);
        $this->assertDatabaseHas('users', ['email' => 'test@company.com']);
        $this->assertDatabaseHas('company_subscriptions', ['status' => 'trial']);
    }

    public function test_registration_requires_unique_email(): void
    {
        User::factory()->create(['email' => 'existing@company.com']);

        $this->postJson('/api/v1/register', [
            'company_name'          => 'شركة أخرى',
            'name'                  => 'مدير',
            'email'                 => 'existing@company.com',
            'password'              => 'Secret@1234',
            'password_confirmation' => 'Secret@1234',
        ])->assertStatus(422);
    }

    public function test_registration_provisions_roles_and_subscription(): void
    {
        $this->postJson('/api/v1/register', [
            'company_name'          => 'شركة جديدة',
            'name'                  => 'أحمد',
            'email'                 => 'ahmed@new.com',
            'password'              => 'Secret@1234',
            'password_confirmation' => 'Secret@1234',
        ])->assertStatus(201);

        $user = User::where('email', 'ahmed@new.com')->first();

        $this->assertTrue($user->hasRole('super-admin'));
        $this->assertNotNull($user->company->subscription);
    }

    public function test_plans_are_publicly_listed(): void
    {
        $this->getJson('/api/v1/plans')
            ->assertOk()
            ->assertJsonPath('success', true);
    }
}
