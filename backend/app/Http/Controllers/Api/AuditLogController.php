<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::query()
            ->when(app()->bound('tenant.company_id'), fn ($q) =>
                $q->where('company_id', app('tenant.company_id'))
            )
            ->when($request->filled('user_id'), fn ($q) =>
                $q->where('user_id', $request->user_id)
            )
            ->when($request->filled('event'), fn ($q) =>
                $q->where('event', $request->event)
            )
            ->when($request->filled('model'), fn ($q) =>
                $q->where('auditable_type', 'like', '%' . $request->model . '%')
            )
            ->when($request->filled('date_from'), fn ($q) =>
                $q->whereDate('created_at', '>=', $request->date_from)
            )
            ->when($request->filled('date_to'), fn ($q) =>
                $q->whereDate('created_at', '<=', $request->date_to)
            )
            ->latest()
            ->paginate($request->integer('per_page', 50));

        return $this->paginated($query);
    }

    public function forModel(Request $request, string $type, string $id): JsonResponse
    {
        $logs = AuditLog::where('auditable_type', 'like', '%' . $type . '%')
            ->where('auditable_id', $id)
            ->when(app()->bound('tenant.company_id'), fn ($q) =>
                $q->where('company_id', app('tenant.company_id'))
            )
            ->latest()
            ->get();

        return $this->success($logs);
    }
}
