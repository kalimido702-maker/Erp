<?php

namespace Tests\Feature\Security;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_is_rate_limited_after_too_many_attempts(): void
    {
        $company = Company::factory()->create();
        $user = User::factory()->create([
            'company_id' => $company->id,
            'password'   => bcrypt('secret123'),
        ]);

        // 5 allowed attempts (all wrong → 401)
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/login', [
                'email'    => $user->email,
                'password' => 'wrongpass',
            ])->assertStatus(401);
        }

        // 6th attempt is throttled
        $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'wrong',
        ])->assertStatus(429)
          ->assertJsonStructure(['success', 'message']);
    }

    public function test_validation_error_returns_consistent_envelope(): void
    {
        $this->postJson('/api/v1/auth/login', ['email' => 'not-an-email'])
            ->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonStructure(['success', 'message', 'errors' => ['email', 'password']]);
    }

    public function test_unauthenticated_request_returns_consistent_envelope(): void
    {
        $this->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJson(['success' => false])
            ->assertJsonStructure(['success', 'message']);
    }

    public function test_not_found_returns_consistent_envelope(): void
    {
        $this->getJson('/api/v1/this-route-does-not-exist')
            ->assertStatus(404)
            ->assertJson(['success' => false])
            ->assertJsonStructure(['success', 'message']);
    }

    public function test_responses_carry_security_headers(): void
    {
        $this->getJson('/api/v1/auth/me')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('X-Frame-Options', 'DENY');
    }
}
