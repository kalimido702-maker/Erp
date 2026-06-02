<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\CompanySubscription;
use App\Models\Plan;
use App\Traits\ApiResponse;
use App\Traits\HandlesTransactions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * @group Platform Admin
 *
 * Manage all tenants. Requires is_platform_admin = true.
 * These endpoints are NOT accessible by regular company users.
 */
class PlatformAdminController extends Controller
{
    use ApiResponse, HandlesTransactions;

    /**
     * List all companies
     *
     * @queryParam search string optional Filter by company name or email. Example: أمل
     * @queryParam status string optional Filter by status: trial|active|suspended|cancelled. Example: active
     * @queryParam per_page integer optional Default 20. Example: 15
     */
    public function listCompanies(Request $request): JsonResponse
    {
        $query = Company::with('subscription.plan')
            ->when($request->filled('search'), fn ($q) =>
                $q->where(fn ($sub) =>
                    $sub->where('name', 'like', '%' . $request->search . '%')
                        ->orWhere('email', 'like', '%' . $request->search . '%')
                )
            )
            ->when($request->filled('status'), fn ($q) =>
                $q->where('status', $request->status)
            )
            ->latest();

        return $this->paginated($query->paginate($request->integer('per_page', 20)));
    }

    /**
     * Get a single company
     *
     * @urlParam company integer required Company ID. Example: 1
     */
    public function showCompany(Company $company): JsonResponse
    {
        return $this->success($company->load('subscription.plan', 'users'));
    }

    /**
     * Suspend a company
     *
     * Blocks all users of the company from accessing the API.
     *
     * @urlParam company integer required. Example: 1
     */
    public function suspendCompany(Company $company): JsonResponse
    {
        $this->transaction(function () use ($company) {
            $company->update(['is_active' => false, 'status' => 'suspended']);
            $company->subscription?->update(['status' => 'suspended']);
        });

        return $this->success(null, 'تم إيقاف الشركة');
    }

    /**
     * Activate a suspended/cancelled company
     *
     * @urlParam company integer required. Example: 1
     */
    public function activateCompany(Company $company): JsonResponse
    {
        $this->transaction(function () use ($company) {
            $company->update(['is_active' => true, 'status' => 'active']);
            $company->subscription?->update(['status' => 'active']);
        });

        return $this->success(null, 'تم تفعيل الشركة');
    }

    /**
     * Assign (or switch) a plan for a company
     *
     * @urlParam company integer required. Example: 1
     * @bodyParam plan_id integer required. Example: 2
     * @bodyParam expires_at string optional ISO 8601. Example: 2027-01-01T00:00:00Z
     */
    public function assignPlan(Request $request, Company $company): JsonResponse
    {
        $validated = $request->validate([
            'plan_id'    => ['required', 'exists:plans,id'],
            'expires_at' => ['nullable', 'date'],
        ]);

        $plan = Plan::findOrFail($validated['plan_id']);

        $this->transaction(function () use ($company, $plan, $validated) {
            $company->subscriptions()->update(['status' => 'cancelled']);

            CompanySubscription::create([
                'company_id' => $company->id,
                'plan_id'    => $plan->id,
                'status'     => 'active',
                'started_at' => now(),
                'expires_at' => $validated['expires_at'] ?? null,
            ]);

            $company->update(['status' => 'active']);
        });

        return $this->success($company->fresh('subscription.plan'), 'تم تغيير الخطة');
    }

    /**
     * List all plans
     */
    public function listPlans(): JsonResponse
    {
        return $this->success(Plan::where('is_active', true)->get());
    }
}
