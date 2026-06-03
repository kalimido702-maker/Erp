<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            // The languages this tenant offers its users. `locale` (existing)
            // stays the tenant default; this is the dynamic, per-subscriber set.
            $table->json('supported_locales')->nullable()->after('locale');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn('supported_locales');
        });
    }
};
