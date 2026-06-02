<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->string('timezone')->default('Asia/Riyadh')->after('currency');
            $table->string('locale')->default('ar')->after('timezone');
            $table->enum('status', ['active', 'trial', 'suspended', 'cancelled'])->default('trial')->after('is_active');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn(['timezone', 'locale', 'status']);
        });
    }
};
