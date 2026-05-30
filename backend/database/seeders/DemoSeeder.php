<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\App;
use Modules\Inventory\Models\Product;
use Spatie\Permission\Models\Role;

/**
 * Realistic demo data — run with:  php artisan db:seed --class=DemoSeeder
 *
 * Safe to run repeatedly (uses firstOrCreate / updateOrCreate).
 */
class DemoSeeder extends Seeder
{
    public function run(): void
    {
        // Only seed demo data in non-production environments
        if (App::isProduction()) {
            $this->command->warn('DemoSeeder skipped in production.');
            return;
        }

        /** @var Company $company */
        $company = Company::firstOrCreate(
            ['slug' => 'demo'],
            [
                'name'       => 'شركة الديمو للتجارة',
                'email'      => 'demo@erp.local',
                'phone'      => '+966500000001',
                'currency'   => 'SAR',
                'is_active'  => true,
            ]
        );

        $this->seedUsers($company);
        $this->seedProducts($company);

        $this->command->info('Demo data seeded successfully for company: ' . $company->name);
    }

    private function seedUsers(Company $company): void
    {
        $adminRole    = Role::firstOrCreate(['name' => 'admin',    'guard_name' => 'sanctum']);
        $employeeRole = Role::firstOrCreate(['name' => 'employee', 'guard_name' => 'sanctum']);

        $users = [
            ['name' => 'مدير الديمو',   'email' => 'demo-admin@erp.local',  'role' => $adminRole],
            ['name' => 'موظف المخزون', 'email' => 'demo-store@erp.local',  'role' => $employeeRole],
            ['name' => 'موظف المبيعات', 'email' => 'demo-sales@erp.local',  'role' => $employeeRole],
        ];

        foreach ($users as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['email']],
                [
                    'name'       => $data['name'],
                    'password'   => bcrypt('Demo@1234'),
                    'is_active'  => true,
                    'company_id' => $company->id,
                ]
            );

            if (! $user->hasRole($data['role'])) {
                $user->assignRole($data['role']);
            }
        }
    }

    private function seedProducts(Company $company): void
    {
        $products = [
            // Electronics
            ['name' => 'لاب توب Dell Latitude 5540', 'sku' => 'DELL-LAT-5540', 'category' => 'إلكترونيات', 'unit' => 'قطعة', 'price' => 4500.00, 'cost' => 3800.00, 'stock_qty' => 25, 'min_stock' => 5],
            ['name' => 'شاشة LG 27 بوصة',           'sku' => 'LG-MON-27',     'category' => 'إلكترونيات', 'unit' => 'قطعة', 'price' => 1200.00, 'cost' =>  950.00, 'stock_qty' => 40, 'min_stock' => 8],
            ['name' => 'طابعة HP LaserJet Pro',      'sku' => 'HP-LJ-PRO',     'category' => 'إلكترونيات', 'unit' => 'قطعة', 'price' => 2100.00, 'cost' => 1750.00, 'stock_qty' => 12, 'min_stock' => 3],
            ['name' => 'ماوس لاسلكي Logitech',       'sku' => 'LOG-MOUSE-W',   'category' => 'إلكترونيات', 'unit' => 'قطعة', 'price' =>  150.00, 'cost' =>   90.00, 'stock_qty' => 80, 'min_stock' => 15],
            ['name' => 'لوحة مفاتيح Logitech',       'sku' => 'LOG-KEY-USB',   'category' => 'إلكترونيات', 'unit' => 'قطعة', 'price' =>  120.00, 'cost' =>   70.00, 'stock_qty' => 60, 'min_stock' => 10],

            // Office Supplies
            ['name' => 'ورق A4 (رزمة 500 ورقة)',     'sku' => 'PPR-A4-500',    'category' => 'قرطاسية',   'unit' => 'رزمة', 'price' =>   25.00, 'cost' =>   18.00, 'stock_qty' => 500, 'min_stock' => 50],
            ['name' => 'أقلام حبر جافة (علبة)',       'sku' => 'PEN-BALL-BX',   'category' => 'قرطاسية',   'unit' => 'علبة', 'price' =>   15.00, 'cost' =>    9.00, 'stock_qty' => 200, 'min_stock' => 30],
            ['name' => 'ملف أرشفة بلاستيك',           'sku' => 'FLD-ARCH-PL',   'category' => 'قرطاسية',   'unit' => 'قطعة', 'price' =>    8.00, 'cost' =>    4.50, 'stock_qty' => 300, 'min_stock' => 50],
            ['name' => 'دباسة مكتبية كبيرة',          'sku' => 'STA-LRG-STL',   'category' => 'قرطاسية',   'unit' => 'قطعة', 'price' =>   45.00, 'cost' =>   28.00, 'stock_qty' => 35,  'min_stock' => 10],

            // Furniture
            ['name' => 'كرسي مكتب مع مسند ذراع',     'sku' => 'CHR-OFF-ARM',   'category' => 'أثاث',      'unit' => 'قطعة', 'price' =>  850.00, 'cost' =>  620.00, 'stock_qty' => 20,  'min_stock' => 4],
            ['name' => 'مكتب L-شكل خشبي',             'sku' => 'DSK-L-WD',      'category' => 'أثاث',      'unit' => 'قطعة', 'price' => 1800.00, 'cost' => 1300.00, 'stock_qty' => 8,   'min_stock' => 2],
            ['name' => 'خزانة ملفات 4 أدراج',         'sku' => 'CAB-4DRW',      'category' => 'أثاث',      'unit' => 'قطعة', 'price' => 1200.00, 'cost' =>  900.00, 'stock_qty' => 10,  'min_stock' => 2],

            // Cleaning
            ['name' => 'منظف متعدد الأسطح (5 لتر)',   'sku' => 'CLN-MULTI-5L',  'category' => 'مواد تنظيف', 'unit' => 'جالون', 'price' =>  35.00, 'cost' =>  22.00, 'stock_qty' => 100, 'min_stock' => 20],
            ['name' => 'مناديل ورقية (كرتون)',         'sku' => 'TSS-BOX-CTN',   'category' => 'مواد تنظيف', 'unit' => 'كرتون', 'price' =>  80.00, 'cost' =>  55.00, 'stock_qty' => 50,  'min_stock' => 10],

            // Low-stock items to test alerts
            ['name' => 'حبر طابعة HP أسود',           'sku' => 'INK-HP-BLK',   'category' => 'إلكترونيات', 'unit' => 'خرطوشة', 'price' => 180.00, 'cost' => 120.00, 'stock_qty' => 2,  'min_stock' => 5],
        ];

        foreach ($products as $data) {
            Product::updateOrCreate(
                ['sku' => $data['sku'], 'company_id' => $company->id],
                array_merge($data, ['company_id' => $company->id, 'is_active' => true])
            );
        }
    }
}
