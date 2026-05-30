<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * @group Company
 *
 * View and update the current tenant's company profile.
 */
class CompanyController extends Controller
{
    use ApiResponse;

    /**
     * Get company
     *
     * Returns the company profile for the authenticated user's tenant.
     *
     * @response 200 {"success":true,"message":"Success","data":{"id":1,"name":"شركة الديمو","email":"demo@erp.local","phone":"+966500000001","currency":"SAR","is_active":true}}
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user->company_id) {
            return $this->error('No company assigned', 404);
        }
        return $this->success(Company::findOrFail($user->company_id));
    }

    /**
     * Update company
     *
     * Update the current tenant's company profile. Only provided fields are changed.
     *
     * @bodyParam name string optional Company display name. Example: شركة التجارة الحديثة
     * @bodyParam email string optional Company contact email. Example: info@company.com
     * @bodyParam phone string optional Contact phone number. Example: +966500000001
     * @bodyParam address string optional Physical address.
     * @bodyParam currency string optional ISO 4217 currency code (3 chars). Example: SAR
     *
     * @response 200 {"success":true,"message":"Success","data":{"id":1,"name":"شركة التجارة الحديثة","currency":"SAR"}}
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'     => 'sometimes|string|max:255',
            'logo'     => 'sometimes|nullable|string',
            'email'    => 'sometimes|nullable|email',
            'phone'    => 'sometimes|nullable|string|max:30',
            'address'  => 'sometimes|nullable|string',
            'currency' => 'sometimes|string|size:3',
        ]);

        $user = $request->user();
        $company = Company::findOrFail($user->company_id);
        $company->update($validated);

        return $this->success($company);
    }
}
