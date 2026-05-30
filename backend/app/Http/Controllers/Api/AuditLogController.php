<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * @group Audit Log
 *
 * Immutable trail of create/update/delete events for all tenant models.
 */
class AuditLogController extends Controller
{
    use ApiResponse;

    /**
     * List audit logs
     *
     * Returns a paginated, filterable audit trail for the current tenant.
     *
     * @queryParam user_id integer optional Filter by acting user. Example: 1
     * @queryParam event string optional Filter by event type: created, updated, or deleted. Example: updated
     * @queryParam model string optional Filter by model class name fragment. Example: Product
     * @queryParam date_from string optional Filter from date (Y-m-d). Example: 2026-01-01
     * @queryParam date_to string optional Filter to date (Y-m-d). Example: 2026-12-31
     * @queryParam per_page integer optional Results per page. Defaults to 50. Example: 25
     *
     * @response 200 {"success":true,"message":"Success","data":[{"id":1,"event":"updated","auditable_type":"Modules\\Inventory\\Models\\Product","auditable_id":1,"user_id":1,"old_values":{"stock_qty":"10.000"},"new_values":{"stock_qty":"8.000"},"created_at":"2026-05-30T10:00:00Z"}],"pagination":{"total":42,"per_page":50,"current_page":1,"last_page":1}}
     */
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

    /**
     * Audit log for a model
     *
     * Returns the full audit history for a specific model instance.
     *
     * @urlParam type string required Model class name fragment (e.g. `Product`). Example: Product
     * @urlParam id integer required Model ID. Example: 1
     *
     * @response 200 {"success":true,"message":"Success","data":[{"id":1,"event":"created","created_at":"2026-05-30T09:00:00Z"},{"id":2,"event":"updated","created_at":"2026-05-30T10:00:00Z"}]}
     */
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
