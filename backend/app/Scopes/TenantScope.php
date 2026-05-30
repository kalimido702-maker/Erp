<?php

namespace App\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;

class TenantScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        if (app()->bound('tenant.company_id')) {
            $builder->where($model->getTable() . '.company_id', app('tenant.company_id'));
        }
    }
}
