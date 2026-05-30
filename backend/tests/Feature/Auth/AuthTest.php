<?php

namespace Tests\Feature\Auth;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private function createUser(array $attrs = []): User
    {
        $company = Company::factory()->create();
        return User::factory()->create(array_merge(['company_id' => $company->id], $attrs));
    }

    public function test_login_with_valid_credentials(): void
    {
        $user = $this->createUser(['password' => bcrypt('secret123')]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'secret123',
        ]);

        $response->assertOk()
                 ->assertJsonStructure(['data' => ['token', 'user']]);
    }

    public function test_login_with_invalid_credentials(): void
    {
        $user = $this->createUser();

        $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'wrong-password',
        ])->assertStatus(401);
    }

    public function test_inactive_user_cannot_login(): void
    {
        $user = $this->createUser(['is_active' => false, 'password' => bcrypt('secret123')]);

        $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'secret123',
        ])->assertStatus(403);
    }

    public function test_me_endpoint_returns_authenticated_user(): void
    {
        $user = $this->createUser();

        $this->actingAs($user)
             ->getJson('/api/v1/auth/me')
             ->assertOk()
             ->assertJsonPath('data.id', $user->id);
    }

    public function test_logout_invalidates_token(): void
    {
        $user = $this->createUser();
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)
             ->postJson('/api/v1/auth/logout')
             ->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 0);

        // Simulate a fresh token-based API client (no carried-over session cookie)
        $this->app['auth']->forgetGuards();
        $this->flushSession();

        $this->withToken($token)
             ->getJson('/api/v1/auth/me')
             ->assertUnauthorized();
    }

    public function test_unauthenticated_request_is_rejected(): void
    {
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
    }
}
