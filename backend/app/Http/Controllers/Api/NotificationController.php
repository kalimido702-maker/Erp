<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * @group Notifications
 *
 * In-app notifications — fetched over HTTP and pushed in real-time via Laravel Reverb.
 */
class NotificationController extends Controller
{
    use ApiResponse;

    /**
     * List notifications
     *
     * Returns paginated notifications for the authenticated user, newest first.
     *
     * @queryParam per_page integer Number of items per page. Defaults to 20. Example: 15
     *
     * @response 200 {"success":true,"message":"Success","data":[{"id":"uuid","type":"App\\Notifications\\LowStockNotification","data":{"message":"Low stock"},"read_at":null,"created_at":"2026-05-30T10:00:00Z"}],"pagination":{"total":5,"per_page":20,"current_page":1,"last_page":1}}
     */
    public function index(Request $request): JsonResponse
    {
        $notifications = $request->user()
            ->notifications()
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return $this->paginated($notifications);
    }

    /**
     * Unread count
     *
     * Returns the number of unread notifications for the current user.
     *
     * @response 200 {"success":true,"message":"Success","data":{"count":3}}
     */
    public function unreadCount(Request $request): JsonResponse
    {
        return $this->success([
            'count' => $request->user()->unreadNotifications()->count(),
        ]);
    }

    /**
     * Mark as read
     *
     * Mark a single notification as read.
     *
     * @urlParam id string required The notification UUID. Example: 9d4e1f2a-...
     * @response 200 {"success":true,"message":"Success","data":null}
     */
    public function markRead(Request $request, string $id): JsonResponse
    {
        $request->user()->notifications()->where('id', $id)->update(['read_at' => now()]);
        return $this->success(null);
    }

    /**
     * Mark all as read
     *
     * Mark all unread notifications as read.
     *
     * @response 200 {"success":true,"message":"Success","data":null}
     */
    public function markAllRead(Request $request): JsonResponse
    {
        $request->user()->unreadNotifications()->update(['read_at' => now()]);
        return $this->success(null);
    }
}
