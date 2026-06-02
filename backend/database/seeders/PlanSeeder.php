<?php

namespace Database\Seeders;

use App\Models\Plan;
use Illuminate\Database\Seeder;

class PlanSeeder extends Seeder
{
    public function run(): void
    {
        $plans = [
            [
                'name'          => 'Starter',
                'slug'          => 'starter',
                'description'   => 'للشركات الصغيرة — مبيعات + مخزون',
                'price'         => 99.00,
                'billing_cycle' => 'monthly',
                'modules'       => ['inventory', 'sales'],
                'max_users'     => 3,
                'max_branches'  => 1,
                'storage_mb'    => 500,
                'trial_days'    => 14,
                'is_active'     => true,
            ],
            [
                'name'          => 'Growth',
                'slug'          => 'growth',
                'description'   => 'للشركات المتوسطة — مبيعات + مخزون + مشتريات + HR',
                'price'         => 249.00,
                'billing_cycle' => 'monthly',
                'modules'       => ['inventory', 'sales', 'purchases', 'hr'],
                'max_users'     => 15,
                'max_branches'  => 3,
                'storage_mb'    => 2048,
                'trial_days'    => 14,
                'is_active'     => true,
            ],
            [
                'name'          => 'Enterprise',
                'slug'          => 'enterprise',
                'description'   => 'جميع الموديولات — بدون حدود',
                'price'         => 599.00,
                'billing_cycle' => 'monthly',
                'modules'       => ['inventory', 'sales', 'purchases', 'hr', 'finance', 'accounting'],
                'max_users'     => 999,
                'max_branches'  => 999,
                'storage_mb'    => 20480,
                'trial_days'    => 30,
                'is_active'     => true,
            ],
        ];

        foreach ($plans as $data) {
            Plan::updateOrCreate(['slug' => $data['slug']], $data);
        }
    }
}
