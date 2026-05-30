<?php

namespace App\Jobs;

use App\Services\PdfService;
use Illuminate\Mail\Message;
use Illuminate\Support\Facades\Mail;

/**
 * Example concrete job: generate a PDF from a Blade view and email it.
 * Modules dispatch this instead of doing heavy PDF work inside HTTP requests.
 *
 * Usage:
 *   SendPdfEmailJob::dispatch(
 *       view: 'pdf.invoice',
 *       data: ['invoice' => $invoice],
 *       filename: "invoice-{$invoice->id}.pdf",
 *       to: $customer->email,
 *       subject: "Your Invoice #{$invoice->number}",
 *   );
 */
class SendPdfEmailJob extends BaseJob
{
    public function __construct(
        private readonly string $view,
        private readonly array  $data,
        private readonly string $filename,
        private readonly string $to,
        private readonly string $subject,
        private readonly string $body = '',
    ) {}

    public function handle(PdfService $pdf): void
    {
        $bytes = $pdf->bytes($this->view, $this->data);

        Mail::raw($this->body ?: $this->subject, function (Message $msg) use ($bytes) {
            $msg->to($this->to)
                ->subject($this->subject)
                ->attachData($bytes, $this->filename, ['mime' => 'application/pdf']);
        });
    }
}
