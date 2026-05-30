<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CompanyController extends Controller
{
    use ApiResponse;

    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user->company_id) {
            return $this->error('No company assigned', 404);
        }
        return $this->success(Company::findOrFail($user->company_id));
    }

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
