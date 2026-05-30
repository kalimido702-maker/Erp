<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PdfService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * @group PDF
 *
 * Server-side PDF generation from allowlisted Blade templates.
 */
class PdfController extends Controller
{
    use ApiResponse;

    private const ALLOWED_VIEWS = [
        'pdf.invoice',
        'pdf.report',
    ];

    public function __construct(private readonly PdfService $pdf) {}

    /**
     * Generate PDF
     *
     * Renders a Blade template as PDF. Use `mode=base64` for JSON API (mobile/web apps),
     * `stream` to display inline in the browser, or `download` to force-download.
     *
     * @bodyParam view string required The template to render. Allowed: `pdf.invoice`, `pdf.report`. Example: pdf.invoice
     * @bodyParam data object required Template data (structure depends on the chosen view).
     * @bodyParam filename string optional Output filename when mode is `download`. Example: invoice-001.pdf
     * @bodyParam mode string optional Output mode: `stream`, `download`, or `base64`. Defaults to `stream`. Example: base64
     *
     * @response 200 scenario="mode=base64" {"success":true,"message":"Success","data":{"pdf":"JVBERi0x..."}}
     * @response 200 scenario="mode=stream/download" Binary PDF file stream
     */
    public function generate(Request $request): StreamedResponse|JsonResponse
    {
        $validated = $request->validate([
            'view'     => ['required', 'string', 'in:' . implode(',', self::ALLOWED_VIEWS)],
            'data'     => ['required', 'array'],
            'filename' => ['nullable', 'string', 'max:120'],
            'mode'     => ['nullable', 'string', 'in:stream,download,base64'],
        ]);

        $view     = $validated['view'];
        $data     = $validated['data'];
        $filename = $validated['filename'] ?? 'document.pdf';
        $mode     = $validated['mode'] ?? 'stream';

        return match ($mode) {
            'download' => $this->pdf->download($view, $data, $filename),
            'base64'   => $this->success(['pdf' => $this->pdf->base64($view, $data)]),
            default    => $this->pdf->stream($view, $data, $filename),
        };
    }
}
