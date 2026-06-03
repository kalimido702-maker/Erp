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
        'currency', 'timezone', 'locale', 'supported_locales', 'is_active', 'status',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'supported_locales' => 'array',
    ];

    /**
     * Languages this tenant offers, always including its default `locale`.
     * Falls back to the platform defaults when unset.
     */
    public function supportedLocaleCodes(): array
    {
        $codes = $this->supported_locales ?: config('i18n.default_locales', ['ar', 'en']);
        $default = $this->locale ?: config('i18n.fallback', 'ar');

        return array_values(array_unique([$default, ...$codes]));
    }

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
