<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Plan extends Model
{
    protected $fillable = [
        'name', 'slug', 'description', 'price', 'billing_cycle',
        'modules', 'max_users', 'max_branches', 'storage_mb',
        'is_active', 'trial_days',
    ];

    protected $casts = [
        'modules'    => 'array',
        'is_active'  => 'boolean',
        'price'      => 'decimal:2',
        'trial_days' => 'integer',
        'max_users'  => 'integer',
        'max_branches' => 'integer',
        'storage_mb'   => 'integer',
    ];

    public function subscriptions(): HasMany
    {
        return $this->hasMany(CompanySubscription::class);
    }

    public function includesModule(string $module): bool
    {
        return in_array($module, $this->modules ?? [], true);
    }
}
