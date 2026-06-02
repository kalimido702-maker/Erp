<?php

namespace Database\Factories;

use App\Models\CompanySubscription;
use App\Models\Plan;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class CompanyFactory extends Factory
{
    public function definition(): array
    {
        $name = $this->faker->company();
        return [
            'name'      => $name,
            'slug'      => Str::slug($name) . '-' . Str::random(4),
            'email'     => $this->faker->companyEmail(),
            'phone'     => $this->faker->phoneNumber(),
            'address'   => $this->faker->address(),
            'currency'  => 'SAR',
            'timezone'  => 'Asia/Riyadh',
            'locale'    => 'ar',
            'is_active' => true,
            'status'    => 'active',
        ];
    }

    /**
     * Attach an active enterprise subscription so routes behind
     * subscription.active middleware don't return 402 in tests.
     */
    public function withSubscription(?string $planSlug = 'enterprise'): static
    {
        return $this->afterCreating(function ($company) use ($planSlug) {
            $plan = Plan::firstOrCreate(
                ['slug' => $planSlug],
                [
                    'name'          => 'Test Plan',
                    'price'         => 0,
                    'billing_cycle' => 'monthly',
                    'modules'       => ['inventory', 'sales', 'purchases', 'hr', 'finance', 'accounting'],
                    'max_users'     => 999,
                    'max_branches'  => 999,
                    'storage_mb'    => 99999,
                    'trial_days'    => 30,
                    'is_active'     => true,
                ]
            );

            CompanySubscription::create([
                'company_id' => $company->id,
                'plan_id'    => $plan->id,
                'status'     => 'active',
                'started_at' => now(),
                'expires_at' => null,
            ]);
        });
    }
}
