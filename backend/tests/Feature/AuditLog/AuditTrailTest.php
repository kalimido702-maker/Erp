<?php

namespace Tests\Feature\AuditLog;

use App\Models\AuditLog;
use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Modules\Inventory\Models\Product;
use Spatie\Permission\Models\Permission;
use Tests\TestCase;

class AuditTrailTest extends TestCase
{
    use RefreshDatabase;

    private function userWithProductAccess(Company $company): User
    {
        $user = User::factory()->create(['company_id' => $company->id]);
        foreach (['products.view', 'products.create', 'products.edit', 'products.delete'] as $perm) {
            Permission::findOrCreate($perm, 'sanctum');
            $user->givePermissionTo($perm);
        }
        return $user;
    }

    public function test_creating_a_product_writes_audit_log(): void
    {
        $company = Company::factory()->create();
        $user    = $this->userWithProductAccess($company);

        $this->actingAs($user)
             ->postJson('/api/v1/inventory/products', ['name' => 'Audited Product', 'price' => 100])
             ->assertCreated();

        $this->assertDatabaseHas('audit_logs', [
            'event'          => 'created',
            'auditable_type' => Product::class,
            'user_id'        => $user->id,
        ]);
    }

    public function test_updating_a_product_records_old_and_new_values(): void
    {
        $company = Company::factory()->create();
        $user    = $this->userWithProductAccess($company);
        $product = Product::create(['name' => 'Old Name', 'price' => 10, 'company_id' => $company->id]);

        $this->actingAs($user)
             ->putJson("/api/v1/inventory/products/{$product->id}", ['name' => 'New Name'])
             ->assertOk();

        $log = AuditLog::where('event', 'updated')->where('auditable_id', $product->id)->first();
        $this->assertNotNull($log);
        $this->assertEquals('Old Name', $log->old_values['name']);
        $this->assertEquals('New Name', $log->new_values['name']);
    }

    public function test_audit_log_endpoint_is_accessible(): void
    {
        $company = Company::factory()->create();
        $user    = User::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user)
             ->getJson('/api/v1/audit-logs')
             ->assertOk();
    }
}
