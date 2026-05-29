<?php

use Illuminate\Support\Facades\Route;
use Modules\Purchases\Http\Controllers\PurchasesController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('purchases', PurchasesController::class)->names('purchases');
});
