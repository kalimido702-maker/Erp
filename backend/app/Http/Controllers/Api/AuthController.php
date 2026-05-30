<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/**
 * @group Auth
 *
 * Endpoints for authentication and session management.
 */
class AuthController extends Controller
{
    use ApiResponse;

    /**
     * Login
     *
     * Authenticate with email + password and receive a Sanctum bearer token.
     * The token expires after 30 days. Any previous token for the same device is revoked.
     *
     * @unauthenticated
     * @response 200 {"success":true,"message":"تم تسجيل الدخول بنجاح","data":{"token":"1|abc...","user":{"id":1,"name":"Admin","email":"admin@erp.local","company_id":1}}}
     * @response 401 {"success":false,"message":"بيانات الدخول غير صحيحة"}
     * @response 403 {"success":false,"message":"الحساب موقوف، تواصل مع المسؤول"}
     * @response 429 {"success":false,"message":"Too Many Requests"}
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return $this->error('بيانات الدخول غير صحيحة', 401);
        }

        if (! $user->is_active) {
            return $this->error('الحساب موقوف، تواصل مع المسؤول', 403);
        }

        $user->tokens()->where('name', 'erp-token')->delete();

        $token = $user->createToken('erp-token', ['*'], now()->addDays(30))->plainTextToken;

        return $this->success([
            'token' => $token,
            'user'  => new UserResource($user),
        ], 'تم تسجيل الدخول بنجاح');
    }

    /**
     * Logout
     *
     * Revoke the current access token.
     *
     * @response 200 {"success":true,"message":"تم تسجيل الخروج","data":null}
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->success(null, 'تم تسجيل الخروج');
    }

    /**
     * Get authenticated user
     *
     * Returns the profile of the currently authenticated user.
     *
     * @response 200 {"success":true,"message":"Success","data":{"id":1,"name":"Admin","email":"admin@erp.local","company_id":1}}
     */
    public function me(Request $request): JsonResponse
    {
        return $this->success(new UserResource($request->user()));
    }

    /**
     * Refresh token
     *
     * Revoke the current token and issue a new one with a fresh 30-day expiry.
     *
     * @response 200 {"success":true,"message":"تم تجديد الجلسة","data":{"token":"2|xyz..."}}
     */
    public function refresh(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->currentAccessToken()->delete();

        $token = $user->createToken('erp-token', ['*'], now()->addDays(30))->plainTextToken;

        return $this->success(['token' => $token], 'تم تجديد الجلسة');
    }
}
