<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->decimal('price', 10, 2)->default(0);
            $table->enum('billing_cycle', ['monthly', 'yearly', 'lifetime'])->default('monthly');
            $table->json('modules');        // ["inventory","sales","hr",…]
            $table->integer('max_users')->default(5);
            $table->integer('max_branches')->default(1);
            $table->integer('storage_mb')->default(500);
            $table->boolean('is_active')->default(true);
            $table->integer('trial_days')->default(14);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('plans');
    }
};
