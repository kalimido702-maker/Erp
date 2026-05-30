<?php

namespace App\Traits;

use App\Models\AuditLog;
use Illuminate\Support\Arr;

trait Auditable
{
    private static array $_auditExclude = [
        'password', 'remember_token', 'email_verified_at', 'updated_at',
    ];

    protected static function bootAuditable(): void
    {
        static::created(function (self $model): void {
            static::writeAudit('created', $model, [], $model->getAttributes());
        });

        static::updated(function (self $model): void {
            static::writeAudit('updated', $model, $model->getOriginal(), $model->getChanges());
        });

        static::deleted(function (self $model): void {
            static::writeAudit('deleted', $model, $model->getAttributes(), []);
        });
    }

    private static function writeAudit(string $event, self $model, array $old, array $new): void
    {
        try {
            $exclude = static::$_auditExclude;
            $request = request();

            AuditLog::create([
                'company_id'     => app()->bound('tenant.company_id') ? app('tenant.company_id') : null,
                'user_id'        => $request->user()?->id,
                'user_name'      => $request->user()?->name,
                'event'          => $event,
                'auditable_type' => get_class($model),
                'auditable_id'   => (string) $model->getKey(),
                'old_values'     => Arr::except($old, $exclude) ?: null,
                'new_values'     => Arr::except($new, $exclude) ?: null,
                'ip_address'     => $request->ip(),
                'user_agent'     => substr($request->userAgent() ?? '', 0, 500),
            ]);
        } catch (\Throwable) {
            // Never let audit failure crash the main operation
        }
    }
}
