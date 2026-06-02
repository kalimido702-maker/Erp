<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CompanySubscription extends Model
{
    protected $fillable = [
        'company_id', 'plan_id', 'status',
        'trial_ends_at', 'started_at', 'expires_at',
    ];

    protected $casts = [
        'trial_ends_at' => 'datetime',
        'started_at'    => 'datetime',
        'expires_at'    => 'datetime',
    ];

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    public function isActive(): bool
    {
        if ($this->status === 'active') {
            return $this->expires_at === null || $this->expires_at->isFuture();
        }

        if ($this->status === 'trial') {
            return $this->trial_ends_at !== null && $this->trial_ends_at->isFuture();
        }

        return false;
    }

    public function includesModule(string $module): bool
    {
        return $this->isActive() && $this->plan->includesModule($module);
    }
}
