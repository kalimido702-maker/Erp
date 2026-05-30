<?php

namespace Tests\Feature\MultiTenancy;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Modules\Inventory\Models\Product;
use Spatie\Permission\Models\Permission;
use Tests\TestCase;

class TenantIsolationTest extends TestCase
{
    use RefreshDatabase;

    private function makeUser(Company $company): User
    {
        $user = User::factory()->create(['company_id' => $company->id]);
        foreach (['products.view', 'products.create', 'products.edit', 'products.delete'] as $perm) {
            Permission::findOrCreate($perm, 'sanctum');
            $user->givePermissionTo($perm);
        }
        return $user;
    }

    public function test_users_only_see_their_own_company_products(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $userA    = $this->makeUser($companyA);
        $userB    = $this->makeUser($companyB);

        // Create products for each company
        app()->instance('tenant.company_id', $companyA->id);
        $productA = Product::create(['name' => 'Product A', 'price' => 10, 'company_id' => $companyA->id]);

        app()->instance('tenant.company_id', $companyB->id);
        $productB = Product::create(['name' => 'Product B', 'price' => 20, 'company_id' => $companyB->id]);

        // User A should only see Product A
        $this->actingAs($userA)
             ->getJson('/api/v1/inventory/products')
             ->assertOk()
             ->assertJsonPath('data.0.name', 'Product A')
             ->assertJsonMissing(['name' => 'Product B']);
    }

    public function test_user_cannot_access_other_company_product(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $userA    = $this->makeUser($companyA);
        $productB = Product::create(['name' => 'B Product', 'price' => 10, 'company_id' => $companyB->id]);

        $this->actingAs($userA)
             ->getJson("/api/v1/inventory/products/{$productB->id}")
             ->assertNotFound();
    }

    public function test_product_auto_assigns_company_id_on_create(): void
    {
        $company = Company::factory()->create();
        $user    = $this->makeUser($company);

        $this->actingAs($user)
             ->postJson('/api/v1/inventory/products', ['name' => 'New Product', 'price' => 50])
             ->assertCreated();

        $this->assertDatabaseHas('products', ['name' => 'New Product', 'company_id' => $company->id]);
    }
}
