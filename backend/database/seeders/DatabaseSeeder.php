<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $superAdmin = Role::firstOrCreate(['name' => 'super-admin', 'guard_name' => 'sanctum']);
        Role::firstOrCreate(['name' => 'admin', 'guard_name' => 'sanctum']);
        Role::firstOrCreate(['name' => 'employee', 'guard_name' => 'sanctum']);

        $permissions = [
            'users.view', 'users.create', 'users.edit', 'users.delete',
            'roles.view', 'roles.create', 'roles.edit', 'roles.delete',
            'branches.view', 'branches.create', 'branches.edit', 'branches.delete',
            'settings.view', 'settings.edit',
        ];

        foreach ($permissions as $perm) {
            Permission::firstOrCreate(['name' => $perm, 'guard_name' => 'sanctum']);
        }

        $superAdmin->syncPermissions(Permission::all());

        $user = User::firstOrCreate(
            ['email' => 'admin@erp.local'],
            [
                'name'      => 'Super Admin',
                'password'  => bcrypt('Admin@1234'),
                'is_active' => true,
            ]
        );

        $user->assignRole($superAdmin);
    }
}
