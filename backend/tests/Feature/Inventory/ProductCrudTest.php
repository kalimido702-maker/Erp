<?php

namespace Tests\Feature\Inventory;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Modules\Inventory\Models\Product;
use Tests\TestCase;

class ProductCrudTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $company = Company::factory()->create();
        $user = User::factory()->create(['company_id' => $company->id]);
        $this->actingAs($user);
        return $user;
    }

    public function test_can_create_product(): void
    {
        $this->actingUser();

        $response = $this->postJson('/api/v1/inventory/products', [
            'name'  => 'لاب توب',
            'sku'   => 'LAP-1',
            'price' => 4500,
        ]);

        $response->assertCreated()
                 ->assertJsonPath('data.name', 'لاب توب');

        $this->assertDatabaseHas('products', ['sku' => 'LAP-1', 'name' => 'لاب توب']);
    }

    /**
     * Regression: update used to call Product::create(), creating a NEW row
     * instead of modifying the existing one. This locks in the fix.
     */
    public function test_update_modifies_existing_product_not_creates_new(): void
    {
        $this->actingUser();
        $product = Product::create(['name' => 'Old', 'sku' => 'UPD-1', 'price' => 100]);

        $response = $this->putJson("/api/v1/inventory/products/{$product->id}", [
            'name'  => 'New Name',
            'sku'   => 'UPD-1',
            'price' => 150,
        ]);

        $response->assertOk()
                 ->assertJsonPath('data.name', 'New Name')
                 ->assertJsonPath('data.id', $product->id);

        // Exactly one product row must exist — no duplicate created.
        $this->assertSame(1, Product::count());
        $this->assertDatabaseHas('products', ['id' => $product->id, 'name' => 'New Name', 'price' => 150]);
    }

    public function test_can_delete_product(): void
    {
        $this->actingUser();
        $product = Product::create(['name' => 'Del', 'sku' => 'DEL-1', 'price' => 10]);

        $response = $this->deleteJson("/api/v1/inventory/products/{$product->id}");

        $response->assertOk();
        $this->assertSoftDeleted('products', ['id' => $product->id]);
    }

    public function test_duplicate_sku_rejected_within_same_company(): void
    {
        $this->actingUser();
        Product::create(['name' => 'A', 'sku' => 'DUP-1', 'price' => 10]);

        $response = $this->postJson('/api/v1/inventory/products', [
            'name'  => 'B',
            'sku'   => 'DUP-1',
            'price' => 20,
        ]);

        $response->assertUnprocessable()
                 ->assertJsonValidationErrors('sku');
    }

    public function test_validation_failure_does_not_persist_anything(): void
    {
        $this->actingUser();

        // Missing required price → validation fails → nothing should be written.
        $response = $this->postJson('/api/v1/inventory/products', [
            'name' => 'NoPrice',
            'sku'  => 'NP-1',
        ]);

        $response->assertUnprocessable();
        $this->assertDatabaseMissing('products', ['sku' => 'NP-1']);
    }
}
