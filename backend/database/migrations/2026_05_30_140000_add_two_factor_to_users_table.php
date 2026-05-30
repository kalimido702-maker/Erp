<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Base32 TOTP secret (encrypted at rest via model cast). Null = 2FA off.
            $table->text('two_factor_secret')->nullable()->after('password');
            // JSON array of one-time recovery codes (encrypted at rest).
            $table->text('two_factor_recovery_codes')->nullable()->after('two_factor_secret');
            // Set only once the user confirms a valid code, so half-setup never locks them out.
            $table->timestamp('two_factor_confirmed_at')->nullable()->after('two_factor_recovery_codes');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'two_factor_secret',
                'two_factor_recovery_codes',
                'two_factor_confirmed_at',
            ]);
        });
    }
};
