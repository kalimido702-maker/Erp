<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Plan;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * @group Subscription
 *
 * View and manage the current company's subscription.
 */
class SubscriptionController extends Controller
{
    use ApiResponse;

    /**
     * Current subscription
     *
     * Returns the active subscription and plan details for the authenticated company.
     *
     * @response 200 {"success":true,"message":"Success","data":{"status":"trial","trial_ends_at":"2026-06-16T00:00:00Z","plan":{"name":"Starter","modules":["inventory","sales"]}}}
     */
    public function show(Request $request): JsonResponse
    {
        $company = Company::with('subscription.plan')
            ->findOrFail($request->user()->company_id);

        return $this->success($company->subscription);
    }

    /**
     * Available plans
     *
     * Returns all publicly available subscription plans.
     *
     * @unauthenticated
     */
    public function plans(): JsonResponse
    {
        return $this->success(Plan::where('is_active', true)->get());
    }
}
