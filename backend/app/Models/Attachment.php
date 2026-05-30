<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Support\Facades\Storage;

class Attachment extends Model
{
    use BelongsToTenant;

    protected $fillable = [
        'company_id', 'uploaded_by', 'collection', 'disk', 'path',
        'original_name', 'mime_type', 'size',
    ];

    protected $casts = [
        'size' => 'integer',
    ];

    protected $appends = ['url'];

    public function attachable(): MorphTo
    {
        return $this->morphTo();
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function getUrlAttribute(): ?string
    {
        return Storage::disk($this->disk)->url($this->path);
    }

    /**
     * Remove the underlying file when the record is deleted, so storage never
     * drifts out of sync with the database.
     */
    protected static function booted(): void
    {
        static::deleting(function (self $attachment): void {
            Storage::disk($attachment->disk)->delete($attachment->path);
        });
    }
}
