<?php

namespace App\Traits;

use App\Models\Company;
use App\Scopes\TenantScope;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

trait BelongsToTenant
{
    protected static function bootBelongsToTenant(): void
    {
        static::addGlobalScope(new TenantScope);

        static::creating(function (self $model): void {
            if (empty($model->company_id) && app()->bound('tenant.company_id')) {
                $model->company_id = app('tenant.company_id');
            }
        });
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }
}
