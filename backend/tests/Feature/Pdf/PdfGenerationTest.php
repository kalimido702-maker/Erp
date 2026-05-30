<?php

namespace Tests\Feature\Pdf;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PdfGenerationTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $company = Company::factory()->create();
        $this->user = User::factory()->create(['company_id' => $company->id]);
    }

    public function test_generate_invoice_pdf_as_base64(): void
    {
        $payload = [
            'view'     => 'pdf.invoice',
            'mode'     => 'base64',
            'filename' => 'invoice-001.pdf',
            'data'     => [
                'company'  => ['name' => 'شركة الاختبار'],
                'customer' => ['name' => 'عميل الاختبار'],
                'currency' => 'SAR',
                'invoice'  => [
                    'number'   => 'INV-001',
                    'date'     => now()->format('Y-m-d'),
                    'status'   => 'pending',
                    'items'    => [
                        ['name' => 'منتج', 'qty' => 2, 'unit_price' => 100, 'discount' => 0, 'total' => 200],
                    ],
                    'subtotal' => 200,
                    'tax_rate' => 15,
                    'tax_amount' => 30,
                    'total'    => 230,
                ],
            ],
        ];

        $response = $this->actingAs($this->user)->postJson('/api/v1/pdf/generate', $payload);

        $response->assertOk()
                 ->assertJsonStructure(['success', 'data' => ['pdf']]);

        // Verify the returned value is valid base64 and non-empty
        $pdf = base64_decode($response->json('data.pdf'), strict: true);
        $this->assertNotFalse($pdf);
        $this->assertStringStartsWith('%PDF', $pdf); // dompdf signature
    }

    public function test_rejects_unknown_view(): void
    {
        $response = $this->actingAs($this->user)->postJson('/api/v1/pdf/generate', [
            'view' => 'pdf.malicious',
            'data' => [],
        ]);

        $response->assertUnprocessable();
    }

    public function test_requires_authentication(): void
    {
        $response = $this->postJson('/api/v1/pdf/generate', [
            'view' => 'pdf.invoice',
            'data' => [],
        ]);

        $response->assertUnauthorized();
    }

    public function test_generate_report_pdf_as_base64(): void
    {
        $payload = [
            'view' => 'pdf.report',
            'mode' => 'base64',
            'data' => [
                'company' => ['name' => 'شركة الاختبار'],
                'report'  => [
                    'title'   => 'تقرير المخزون',
                    'period'  => 'مايو 2026',
                    'columns' => ['المنتج', 'المخزون', 'السعر'],
                    'rows'    => [
                        ['لاب توب', '10', '4500 SAR'],
                        ['شاشة',    '25', '1200 SAR'],
                    ],
                ],
            ],
        ];

        $response = $this->actingAs($this->user)->postJson('/api/v1/pdf/generate', $payload);

        $response->assertOk();
        $pdf = base64_decode($response->json('data.pdf'), strict: true);
        $this->assertStringStartsWith('%PDF', $pdf);
    }
}
