<?php

namespace Tests\Feature\Inventory;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Modules\Inventory\Models\Product;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * Proves the ProductPolicy is actually enforced on the endpoints — not just
 * defined. These are the regression tests for the "authorization is wired but
 * never applied" gap.
 */
class ProductAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    private function seedPermissions(): void
    {
        foreach (['products.view', 'products.create', 'products.edit', 'products.delete'] as $perm) {
            Permission::findOrCreate($perm, 'sanctum');
        }
    }

    public function test_user_without_any_permission_cannot_list_products(): void
    {
        $company = Company::factory()->withSubscription()->create();
        $user = User::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user)
             ->getJson('/api/v1/inventory/products')
             ->assertForbidden();
    }

    public function test_user_without_delete_permission_cannot_delete(): void
    {
        $this->seedPermissions();
        $company = Company::factory()->withSubscription()->create();
        $user = User::factory()->create(['company_id' => $company->id]);
        // Has view+create+edit but NOT delete (the typical "employee").
        $user->givePermissionTo('products.view', 'products.create', 'products.edit');

        $product = Product::create(['name' => 'P', 'price' => 10, 'company_id' => $company->id]);

        $this->actingAs($user)
             ->deleteJson("/api/v1/inventory/products/{$product->id}")
             ->assertForbidden();

        // The product must still exist — the forbidden request changed nothing.
        $this->assertDatabaseHas('products', ['id' => $product->id, 'deleted_at' => null]);
    }

    public function test_user_with_delete_permission_can_delete(): void
    {
        $this->seedPermissions();
        $company = Company::factory()->withSubscription()->create();
        $user = User::factory()->create(['company_id' => $company->id]);
        $user->givePermissionTo('products.delete');

        $product = Product::create(['name' => 'P', 'price' => 10, 'company_id' => $company->id]);

        $this->actingAs($user)
             ->deleteJson("/api/v1/inventory/products/{$product->id}")
             ->assertOk();

        $this->assertSoftDeleted('products', ['id' => $product->id]);
    }

    public function test_super_admin_bypasses_all_permission_checks(): void
    {
        $role = Role::findOrCreate('super-admin', 'sanctum');
        $company = Company::factory()->withSubscription()->create();
        $user = User::factory()->create(['company_id' => $company->id]);
        $user->assignRole($role); // No explicit permissions granted.

        $product = Product::create(['name' => 'P', 'price' => 10, 'company_id' => $company->id]);

        // before() hook lets super-admin through every gate.
        $this->actingAs($user)
             ->deleteJson("/api/v1/inventory/products/{$product->id}")
             ->assertOk();
    }
}
