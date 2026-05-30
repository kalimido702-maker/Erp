<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

/**
 * Dumps the MySQL database to storage/app/backups and prunes old dumps.
 *
 * Scheduled daily (see routes/console.php). For SQLite (tests/local) it
 * simply copies the database file. Designed to be safe and dependency-free —
 * uses mysqldump when available.
 */
class BackupDatabase extends Command
{
    protected $signature = 'backup:run {--keep=7 : Number of daily backups to retain}';

    protected $description = 'Back up the database to storage/app/backups';

    public function handle(): int
    {
        $connection = config('database.default');
        $disk = Storage::disk('local');
        $disk->makeDirectory('backups');

        $timestamp = now()->format('Y-m-d_His');

        if ($connection === 'sqlite') {
            return $this->backupSqlite($disk, $timestamp);
        }

        return $this->backupMysql($disk, $timestamp);
    }

    private function backupMysql(\Illuminate\Contracts\Filesystem\Filesystem $disk, string $timestamp): int
    {
        $db = config('database.connections.mysql');
        $filename = "backups/db_{$timestamp}.sql";
        $absolute = $disk->path($filename);

        $process = Process::fromShellCommandline(
            sprintf(
                'mysqldump --host=%s --port=%s --user=%s --password=%s --single-transaction --no-tablespaces %s > %s',
                escapeshellarg($db['host']),
                escapeshellarg((string) $db['port']),
                escapeshellarg($db['username']),
                escapeshellarg($db['password']),
                escapeshellarg($db['database']),
                escapeshellarg($absolute),
            )
        );

        $process->setTimeout(600);
        $process->run();

        if (! $process->isSuccessful()) {
            $this->error('Backup failed: ' . $process->getErrorOutput());
            return self::FAILURE;
        }

        $this->info("Database backed up to {$filename}");
        $this->prune($disk);

        return self::SUCCESS;
    }

    private function backupSqlite(\Illuminate\Contracts\Filesystem\Filesystem $disk, string $timestamp): int
    {
        $source = config('database.connections.sqlite.database');

        if (! is_string($source) || ! file_exists($source)) {
            $this->warn('SQLite database file not found — skipping backup.');
            return self::SUCCESS;
        }

        $disk->put("backups/db_{$timestamp}.sqlite", file_get_contents($source));
        $this->info("SQLite database backed up to backups/db_{$timestamp}.sqlite");
        $this->prune($disk);

        return self::SUCCESS;
    }

    /**
     * Keep only the most recent N backups; delete the rest.
     */
    private function prune(\Illuminate\Contracts\Filesystem\Filesystem $disk): void
    {
        $keep = (int) $this->option('keep');
        $files = collect($disk->files('backups'))
            ->sortDesc()
            ->values();

        $files->slice($keep)->each(function (string $file) use ($disk) {
            $disk->delete($file);
            $this->line("Pruned old backup: {$file}");
        });
    }
}
