<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('phone')->nullable()->after('email');
            $table->string('avatar')->nullable()->after('phone');
            $table->boolean('is_active')->default(true)->after('avatar');
            // NOTE: branch_id + its FK are added in a separate later migration,
            // AFTER the `branches` table is created. MySQL refuses a foreign key
            // that references a table which does not yet exist; SQLite silently
            // allowed it, which is why this only surfaced in CI on MySQL.
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'avatar', 'is_active']);
        });
    }
};
