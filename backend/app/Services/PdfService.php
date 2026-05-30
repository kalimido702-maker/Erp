<?php

namespace App\Services;

use Barryvdh\DomPDF\Facade\Pdf;
use Symfony\Component\HttpFoundation\StreamedResponse;

class PdfService
{
    /**
     * Stream PDF in the browser (inline).
     */
    public function stream(string $view, array $data = [], string $filename = 'document.pdf'): Response
    {
        return $this->build($view, $data)->stream($filename);
    }

    /**
     * Force-download the PDF.
     */
    public function download(string $view, array $data = [], string $filename = 'document.pdf'): Response
    {
        return $this->build($view, $data)->download($filename);
    }

    /**
     * Return raw PDF bytes (useful for attaching to emails / queued jobs).
     */
    public function bytes(string $view, array $data = []): string
    {
        return $this->build($view, $data)->output();
    }

    /**
     * Return PDF encoded as base64 (useful for JSON API responses).
     */
    public function base64(string $view, array $data = []): string
    {
        return base64_encode($this->bytes($view, $data));
    }

    private function build(string $view, array $data): \Barryvdh\DomPDF\PDF
    {
        return Pdf::loadView($view, $data)
            ->setPaper('a4', 'portrait')
            ->setOptions([
                'defaultFont'         => 'DejaVu Sans',
                'isHtml5ParserEnabled' => true,
                'isRemoteEnabled'     => false,
                'dpi'                 => 150,
            ]);
    }
}
