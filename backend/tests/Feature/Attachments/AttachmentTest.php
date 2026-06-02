<?php

namespace Tests\Feature\Attachments;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Modules\Inventory\Models\Product;
use Tests\TestCase;

class AttachmentTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(Company $company): User
    {
        $user = User::factory()->create(['company_id' => $company->id]);
        $this->actingAs($user);
        return $user;
    }

    public function test_can_upload_attachment_to_a_product(): void
    {
        Storage::fake('public');
        $company = Company::factory()->withSubscription()->create();
        $this->actingUser($company);
        $product = Product::create(['name' => 'P', 'price' => 1, 'company_id' => $company->id]);

        $this->postJson('/api/v1/attachments', [
            'type' => 'products',
            'id'   => $product->id,
            'file' => UploadedFile::fake()->create('invoice.pdf', 200, 'application/pdf'),
        ])->assertCreated()
          ->assertJsonPath('data.original_name', 'invoice.pdf');

        $this->assertDatabaseHas('attachments', [
            'attachable_type' => 'products',
            'attachable_id'   => $product->id,
            'company_id'      => $company->id,
            'original_name'   => 'invoice.pdf',
        ]);

        $path = $product->attachments()->first()->path;
        Storage::disk('public')->assertExists($path);
    }

    public function test_oversized_file_is_rejected(): void
    {
        Storage::fake('public');
        $company = Company::factory()->withSubscription()->create();
        $this->actingUser($company);
        $product = Product::create(['name' => 'P', 'price' => 1, 'company_id' => $company->id]);

        $this->postJson('/api/v1/attachments', [
            'type' => 'products',
            'id'   => $product->id,
            'file' => UploadedFile::fake()->create('big.pdf', 20000), // 20 MB > 10 MB
        ])->assertStatus(422);
    }

    public function test_unsupported_type_is_rejected(): void
    {
        $company = Company::factory()->withSubscription()->create();
        $this->actingUser($company);

        $this->postJson('/api/v1/attachments', [
            'type' => 'unknown_thing',
            'id'   => 1,
            'file' => UploadedFile::fake()->create('x.pdf', 10),
        ])->assertStatus(422);
    }

    public function test_deleting_attachment_removes_file(): void
    {
        Storage::fake('public');
        $company = Company::factory()->withSubscription()->create();
        $this->actingUser($company);
        $product = Product::create(['name' => 'P', 'price' => 1, 'company_id' => $company->id]);

        $attachment = $product->attachFile(UploadedFile::fake()->create('doc.pdf', 50, 'application/pdf'));
        Storage::disk('public')->assertExists($attachment->path);

        $this->deleteJson("/api/v1/attachments/{$attachment->id}")->assertOk();

        Storage::disk('public')->assertMissing($attachment->path);
        $this->assertDatabaseMissing('attachments', ['id' => $attachment->id]);
    }

    public function test_cannot_access_other_company_attachment(): void
    {
        Storage::fake('public');
        $companyA = Company::factory()->withSubscription()->create();
        $companyB = Company::factory()->withSubscription()->create();

        // Attachment owned by company B
        $userB = User::factory()->create(['company_id' => $companyB->id]);
        $this->actingAs($userB);
        $productB = Product::create(['name' => 'B', 'price' => 1, 'company_id' => $companyB->id]);
        $attachmentB = $productB->attachFile(UploadedFile::fake()->create('b.pdf', 10, 'application/pdf'));

        // User from company A must not be able to delete it
        $this->actingUser($companyA);
        $this->deleteJson("/api/v1/attachments/{$attachmentB->id}")->assertNotFound();
    }
}
