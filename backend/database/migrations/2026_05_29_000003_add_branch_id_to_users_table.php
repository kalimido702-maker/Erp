<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the users.branch_id foreign key.
 *
 * Split out from the original update_users_table migration because the FK
 * references the `branches` table, which is created in 2026_05_29_000002.
 * Defining the FK before its target table exists is rejected by MySQL
 * (error 1824 "Failed to open the referenced table 'branches'").
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('branch_id')
                ->nullable()
                ->after('is_active')
                ->constrained('branches')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['branch_id']);
            $table->dropColumn('branch_id');
        });
    }
};
