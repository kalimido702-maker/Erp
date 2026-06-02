<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Company extends Model
{
    use HasFactory;

    protected $fillable = [
        'name', 'slug', 'logo', 'email', 'phone', 'address',
        'currency', 'timezone', 'locale', 'is_active', 'status',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(CompanySubscription::class)->latestOfMany();
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(CompanySubscription::class);
    }

    public function hasActiveSubscription(): bool
    {
        return $this->subscription?->isActive() ?? false;
    }

    public function canAccessModule(string $module): bool
    {
        return $this->subscription?->includesModule($module) ?? false;
    }
}
