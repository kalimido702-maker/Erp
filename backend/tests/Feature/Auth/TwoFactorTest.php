<?php

namespace Tests\Feature\Auth;

use App\Models\Company;
use App\Models\User;
use App\Services\TwoFactorService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TwoFactorTest extends TestCase
{
    use RefreshDatabase;

    private function user(array $attrs = []): User
    {
        $company = Company::factory()->create();
        return User::factory()->create(array_merge(['company_id' => $company->id], $attrs));
    }

    public function test_enable_returns_secret_and_qr(): void
    {
        $user = $this->user();

        $this->actingAs($user)
             ->postJson('/api/v1/auth/2fa/enable')
             ->assertOk()
             ->assertJsonStructure(['data' => ['secret', 'qr_url']]);

        $this->assertNotNull($user->fresh()->two_factor_secret);
        // Not confirmed yet → not active.
        $this->assertFalse($user->fresh()->hasTwoFactorEnabled());
    }

    public function test_confirm_with_valid_code_activates_2fa_and_returns_recovery_codes(): void
    {
        $user = $this->user();
        $svc = app(TwoFactorService::class);
        $secret = $svc->generateSecret();
        $user->forceFill(['two_factor_secret' => $secret])->save();

        $code = app(\PragmaRX\Google2FA\Google2FA::class)->getCurrentOtp($secret);

        $this->actingAs($user)
             ->postJson('/api/v1/auth/2fa/confirm', ['code' => $code])
             ->assertOk()
             ->assertJsonStructure(['data' => ['recovery_codes']]);

        $this->assertTrue($user->fresh()->hasTwoFactorEnabled());
    }

    public function test_confirm_with_invalid_code_is_rejected(): void
    {
        $user = $this->user();
        $svc = app(TwoFactorService::class);
        $user->forceFill(['two_factor_secret' => $svc->generateSecret()])->save();

        $this->actingAs($user)
             ->postJson('/api/v1/auth/2fa/confirm', ['code' => '000000'])
             ->assertStatus(422);

        $this->assertFalse($user->fresh()->hasTwoFactorEnabled());
    }

    public function test_login_requires_code_when_2fa_enabled(): void
    {
        $svc = app(TwoFactorService::class);
        $secret = $svc->generateSecret();
        $user = $this->user([
            'password'                => bcrypt('secret123'),
            'two_factor_secret'       => $secret,
            'two_factor_confirmed_at' => now(),
        ]);

        // Step 1: no code → challenge.
        $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'secret123',
        ])->assertStatus(422)
          ->assertJsonPath('errors.two_factor_required.0', true);

        // Step 2: valid code → success.
        $code = app(\PragmaRX\Google2FA\Google2FA::class)->getCurrentOtp($secret);
        $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'secret123',
            'code'     => $code,
        ])->assertOk()
          ->assertJsonStructure(['data' => ['token', 'user']]);
    }

    public function test_recovery_code_works_and_is_consumed(): void
    {
        $svc = app(TwoFactorService::class);
        $secret = $svc->generateSecret();
        $codes = $svc->generateRecoveryCodes();
        $user = $this->user([
            'password'                  => bcrypt('secret123'),
            'two_factor_secret'         => $secret,
            'two_factor_recovery_codes' => $codes,
            'two_factor_confirmed_at'   => now(),
        ]);

        $recovery = $codes[0];

        $this->postJson('/api/v1/auth/login', [
            'email'    => $user->email,
            'password' => 'secret123',
            'code'     => $recovery,
        ])->assertOk();

        // Code is single-use → removed from the stored list.
        $this->assertNotContains($recovery, $user->fresh()->two_factor_recovery_codes);
    }

    public function test_disable_requires_correct_password(): void
    {
        $user = $this->user([
            'password'                => bcrypt('secret123'),
            'two_factor_secret'       => app(TwoFactorService::class)->generateSecret(),
            'two_factor_confirmed_at' => now(),
        ]);

        $this->actingAs($user)
             ->postJson('/api/v1/auth/2fa/disable', ['password' => 'wrong'])
             ->assertStatus(422);

        $this->actingAs($user)
             ->postJson('/api/v1/auth/2fa/disable', ['password' => 'secret123'])
             ->assertOk();

        $this->assertFalse($user->fresh()->hasTwoFactorEnabled());
    }
}
