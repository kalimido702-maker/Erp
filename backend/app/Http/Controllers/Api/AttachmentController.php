<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attachment;
use App\Traits\ApiResponse;
use App\Traits\HasAttachments;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class AttachmentController extends Controller
{
    use ApiResponse;

    /** List attachments for a given parent model. */
    public function index(Request $request, string $type, string $id): JsonResponse
    {
        $parent = $this->resolveParent($type, $id);

        return $this->success($parent->attachments()->latest()->get());
    }

    /** Upload and attach a file to a parent model. */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'type'       => 'required|string',
            'id'         => 'required',
            'file'       => 'required|file|max:10240', // 10 MB
            'collection' => 'nullable|string|max:100',
        ]);

        $parent = $this->resolveParent($validated['type'], $validated['id']);

        $attachment = $parent->attachFile(
            $request->file('file'),
            $validated['collection'] ?? 'default',
        );

        return $this->success($attachment, 'تم رفع الملف', 201);
    }

    /** Delete an attachment (and its underlying file). */
    public function destroy(Attachment $attachment): JsonResponse
    {
        // Tenant scope on Attachment already prevents cross-company access,
        // returning a 404 before we reach here for foreign records.
        $attachment->delete();

        return $this->success(null, 'تم حذف الملف');
    }

    /**
     * Resolve and authorize the parent model from a morph alias + id.
     * Tenant scoping on the parent guarantees cross-company isolation.
     */
    private function resolveParent(string $type, string|int $id): Model
    {
        $class = Relation::getMorphedModel($type);

        if ($class === null || ! class_exists($class)) {
            throw ValidationException::withMessages([
                'type' => "نوع العنصر «{$type}» غير مدعوم للمرفقات",
            ]);
        }

        $model = $class::query()->findOrFail($id);

        if (! in_array(HasAttachments::class, class_uses_recursive($model), true)) {
            throw ValidationException::withMessages([
                'type' => "نوع العنصر «{$type}» لا يدعم المرفقات",
            ]);
        }

        return $model;
    }
}
