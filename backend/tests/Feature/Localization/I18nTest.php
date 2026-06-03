<?php

namespace Tests\Feature\Localization;

use App\Models\Company;
use App\Models\Translation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class I18nTest extends TestCase
{
    use RefreshDatabase;

    public function test_manifest_returns_platform_defaults_when_unauthenticated(): void
    {
        $this->getJson('/api/v1/i18n/manifest')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.default', 'ar')
            ->assertJsonFragment(['locales' => ['ar', 'en']])
            ->assertJsonStructure(['data' => ['locales', 'default', 'version']]);
    }

    public function test_strings_returns_flattened_base_translations(): void
    {
        // Keys contain literal dots, so assert against the decoded array directly
        // (assertJsonPath would split on the dot).
        $data = $this->getJson('/api/v1/i18n/ar')->assertOk()->json('data');

        $this->assertSame('تسجيل الدخول', $data['auth.login']);
        $this->assertSame('شامل ERP', $data['brand.name']);
    }

    public function test_unknown_locale_falls_back_to_default(): void
    {
        $data = $this->getJson('/api/v1/i18n/zz')->assertOk()->json('data');

        $this->assertSame('تسجيل الدخول', $data['auth.login']);
    }

    public function test_manifest_reflects_company_supported_locales(): void
    {
        $company = Company::factory()->withSubscription()->create([
            'locale' => 'en',
            'supported_locales' => ['en'],
        ]);
        $user = User::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/i18n/manifest')
            ->assertOk()
            ->assertJsonPath('data.default', 'en')
            ->assertJsonFragment(['locales' => ['en']]);
    }

    public function test_tenant_override_wins_over_base_string(): void
    {
        $company = Company::factory()->withSubscription()->create();
        $user = User::factory()->create(['company_id' => $company->id]);

        Translation::create([
            'company_id' => $company->id,
            'locale' => 'ar',
            'key' => 'auth.login',
            'value' => 'دخول مخصص',
        ]);

        $data = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/i18n/ar')
            ->assertOk()
            ->json('data');

        $this->assertSame('دخول مخصص', $data['auth.login']);
        // untouched keys still come from the base file
        $this->assertSame('شامل ERP', $data['brand.name']);
    }

    public function test_tenant_cannot_see_another_companys_overrides(): void
    {
        $other = Company::factory()->withSubscription()->create();
        Translation::create([
            'company_id' => $other->id,
            'locale' => 'ar',
            'key' => 'auth.login',
            'value' => 'سر الشركة الأخرى',
        ]);

        $company = Company::factory()->withSubscription()->create();
        $user = User::factory()->create(['company_id' => $company->id]);

        $data = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/i18n/ar')
            ->assertOk()
            ->json('data');

        // sees the base string, never the other tenant's override
        $this->assertSame('تسجيل الدخول', $data['auth.login']);
    }
}
