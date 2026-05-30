<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PdfService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Generic PDF endpoint used by all modules.
 *
 * Each module sends { view, data, filename, mode } in the request body.
 * Only trusted views are allowed (allowlist) to prevent arbitrary template injection.
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
     * POST /api/v1/pdf/generate
     * Body: { view, data, filename?, mode? }  mode = stream|download|base64
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
