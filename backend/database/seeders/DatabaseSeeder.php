<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $superAdmin = Role::firstOrCreate(['name' => 'super-admin', 'guard_name' => 'sanctum']);
        $admin      = Role::firstOrCreate(['name' => 'admin', 'guard_name' => 'sanctum']);
        $employee   = Role::firstOrCreate(['name' => 'employee', 'guard_name' => 'sanctum']);

        $permissions = [
            'users.view', 'users.create', 'users.edit', 'users.delete',
            'roles.view', 'roles.create', 'roles.edit', 'roles.delete',
            'branches.view', 'branches.create', 'branches.edit', 'branches.delete',
            'settings.view', 'settings.edit',
            // Inventory
            'products.view', 'products.create', 'products.edit', 'products.delete',
        ];

        foreach ($permissions as $perm) {
            Permission::firstOrCreate(['name' => $perm, 'guard_name' => 'sanctum']);
        }

        // super-admin: everything (also bypasses via policy before() hook).
        $superAdmin->syncPermissions(Permission::all());

        // admin: full module access, no role/user administration.
        $admin->syncPermissions(Permission::whereNotIn('name', [
            'users.delete', 'roles.create', 'roles.edit', 'roles.delete',
        ])->get());

        // employee: read + day-to-day create/edit, but NOT delete.
        $employee->syncPermissions([
            'products.view', 'products.create', 'products.edit',
            'branches.view', 'settings.view',
        ]);

        $company = Company::firstOrCreate(
            ['slug' => 'default'],
            [
                'name'      => 'Default Company',
                'email'     => 'company@erp.local',
                'currency'  => 'SAR',
                'is_active' => true,
            ]
        );

        $user = User::firstOrCreate(
            ['email' => 'admin@erp.local'],
            [
                'name'       => 'Super Admin',
                'password'   => bcrypt('Admin@1234'),
                'is_active'  => true,
                'company_id' => $company->id,
            ]
        );

        if (! $user->company_id) {
            $user->update(['company_id' => $company->id]);
        }

        $user->assignRole($superAdmin);

        // Realistic demo data (skipped automatically in production)
        $this->call(DemoSeeder::class);
    }
}
