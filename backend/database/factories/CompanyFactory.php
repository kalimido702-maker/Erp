<?php

namespace Database\Factories;

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
            'is_active' => true,
        ];
    }
}
