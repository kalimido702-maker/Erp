<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Throwable;

abstract class BaseJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Retry up to 3 times before marking as failed. */
    public int $tries = 3;

    /** Seconds to wait before the first retry (doubles each attempt). */
    public array $backoff = [30, 60, 120];

    /** Seconds before the job is considered stuck. */
    public int $timeout = 60;

    /**
     * Called by Laravel when all retries are exhausted.
     * Subclasses can override for custom failure handling.
     */
    public function failed(Throwable $exception): void
    {
        Log::error(static::class . ' permanently failed', [
            'exception' => $exception->getMessage(),
            'file'      => $exception->getFile() . ':' . $exception->getLine(),
            'job_id'    => $this->job?->getJobId(),
        ]);
    }
}
