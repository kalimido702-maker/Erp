<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Per-tenant UI string OVERRIDES. The platform ships authoritative base
     * strings as JSON files; rows here let a tenant override or add keys for
     * their own subscribers (e.g. rename "العملاء" to "المرضى" for a clinic).
     * Scoped by company_id via BelongsToTenant.
     */
    public function up(): void
    {
        Schema::create('translations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->nullable()->constrained('companies')->cascadeOnDelete();
            $table->string('locale', 8);
            $table->string('key', 191);      // dotted key, e.g. "auth.login"
            $table->text('value');
            $table->timestamps();

            $table->unique(['company_id', 'locale', 'key']);
            $table->index(['company_id', 'locale']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('translations');
    }
};
