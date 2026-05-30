<?php

namespace App\Traits;

use App\Models\Attachment;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Auth;

/**
 * Drop this trait on ANY model to give it file attachments — no per-model
 * configuration, no extra tables. Storage and tenant stamping are handled
 * centrally.
 */
trait HasAttachments
{
    public function attachments(): MorphMany
    {
        return $this->morphMany(Attachment::class, 'attachable');
    }

    /**
     * Store an uploaded file and link it to this model.
     */
    public function attachFile(UploadedFile $file, string $collection = 'default', string $disk = 'public'): Attachment
    {
        $path = $file->store('attachments/'.$this->getTable(), $disk);

        return $this->attachments()->create([
            'company_id'    => $this->company_id ?? Auth::user()?->company_id,
            'uploaded_by'   => Auth::id(),
            'collection'    => $collection,
            'disk'          => $disk,
            'path'          => $path,
            'original_name' => $file->getClientOriginalName(),
            'mime_type'     => $file->getClientMimeType(),
            'size'          => $file->getSize(),
        ]);
    }

    /**
     * Delete every attachment (and its file) when the parent is removed.
     */
    protected static function bootHasAttachments(): void
    {
        static::deleting(function ($model): void {
            // Skip when the parent is only being soft-deleted.
            if (method_exists($model, 'isForceDeleting') && ! $model->isForceDeleting()) {
                return;
            }
            $model->attachments->each->delete();
        });
    }
}
