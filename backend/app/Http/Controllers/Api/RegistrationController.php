<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\Company;
use App\Models\User;
use App\Services\TenantProvisioningService;
use App\Traits\ApiResponse;
use App\Traits\HandlesTransactions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * @group Registration
 *
 * Public tenant self-registration — creates a new company + admin user and starts a trial.
 */
class RegistrationController extends Controller
{
    use ApiResponse, HandlesTransactions;

    public function __construct(private readonly TenantProvisioningService $provisioner) {}

    /**
     * Register a new company (tenant)
     *
     * Creates the company, the first admin user, and starts a trial subscription.
     * No authentication required.
     *
     * @unauthenticated
     * @bodyParam company_name string required The company display name. Example: شركة الأمل للتجارة
     * @bodyParam name string required Admin full name. Example: محمد أحمد
     * @bodyParam email string required Admin email (used to log in). Example: admin@company.com
     * @bodyParam password string required Min 8 chars. Example: Secret@1234
     * @bodyParam password_confirmation string required Must match password. Example: Secret@1234
     * @bodyParam currency string optional ISO 4217 code, default SAR. Example: SAR
     * @bodyParam timezone string optional Default Asia/Riyadh. Example: Africa/Cairo
     * @bodyParam locale string optional ar or en, default ar. Example: ar
     *
     * @response 201 {"success":true,"message":"تم إنشاء حسابك بنجاح","data":{"token":"1|abc...","user":{...},"company":{...}}}
     * @response 422 {"success":false,"message":"بيانات غير صحيحة","errors":{...}}
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'company_name' => ['required', 'string', 'max:255'],
            'name'         => ['required', 'string', 'max:255'],
            'email'        => ['required', 'email', 'unique:users,email'],
            'password'     => ['required', 'string', 'min:8', 'confirmed'],
            'currency'     => ['sometimes', 'string', 'size:3'],
            'timezone'     => ['sometimes', 'string', 'max:50'],
            'locale'       => ['sometimes', 'in:ar,en'],
        ]);

        [$token, $user, $company] = $this->transaction(function () use ($validated) {
            $company = Company::create([
                'name'      => $validated['company_name'],
                'slug'      => Str::slug($validated['company_name']) . '-' . Str::lower(Str::random(6)),
                'currency'  => $validated['currency'] ?? 'SAR',
                'timezone'  => $validated['timezone'] ?? 'Asia/Riyadh',
                'locale'    => $validated['locale'] ?? 'ar',
                'is_active' => true,
                'status'    => 'trial',
            ]);

            $user = User::create([
                'name'       => $validated['name'],
                'email'      => $validated['email'],
                'password'   => $validated['password'],
                'company_id' => $company->id,
                'is_active'  => true,
            ]);

            $this->provisioner->provision($company, $user);

            $token = $user->createToken('erp-token', ['*'], now()->addDays(30))->plainTextToken;

            return [$token, $user, $company];
        });

        return $this->success([
            'token'   => $token,
            'user'    => new UserResource($user),
            'company' => $company,
        ], 'تم إنشاء حسابك بنجاح', 201);
    }
}
