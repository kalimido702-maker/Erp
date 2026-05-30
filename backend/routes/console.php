<?php

use Illuminate\Support\Facades\Schedule;

// Daily database backup at 02:00, keeping the last 7 dumps.
Schedule::command('backup:run --keep=7')
    ->dailyAt('02:00')
    ->withoutOverlapping()
    ->onOneServer();

// Prune Telescope entries older than 48h to keep the dev DB small.
Schedule::command('telescope:prune --hours=48')
    ->daily();
