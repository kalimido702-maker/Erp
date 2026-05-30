<?php

namespace App\Traits;

use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Wraps multi-step write operations in a database transaction so that a
 * failure half-way through never leaves the database in an inconsistent
 * state (e.g. an invoice saved without its line items, or stock deducted
 * without a matching sale). Essential for an accounting/ERP system.
 *
 * Usage inside a controller or service:
 *
 *   return $this->transaction(function () use ($data) {
 *       $invoice = Invoice::create($data);
 *       $invoice->items()->createMany($data['items']);
 *       return $invoice;
 *   });
 */
trait HandlesTransactions
{
    /**
     * Run the callback inside a DB transaction. Commits on success,
     * rolls back and re-throws on any exception.
     *
     * @template T
     * @param  callable():T  $callback
     * @return T
     */
    protected function transaction(callable $callback, int $attempts = 1): mixed
    {
        return DB::transaction($callback, $attempts);
    }

    /**
     * Run the callback in a transaction but swallow nothing — identical to
     * transaction(), kept as an explicit name for read-modify-write flows
     * that may deadlock and benefit from automatic retries.
     *
     * @template T
     * @param  callable():T  $callback
     * @return T
     */
    protected function transactionWithRetry(callable $callback, int $attempts = 3): mixed
    {
        return DB::transaction($callback, $attempts);
    }
}
