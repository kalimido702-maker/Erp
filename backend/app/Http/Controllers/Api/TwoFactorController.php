<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\TwoFactorService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * @group Auth
 *
 * Two-factor authentication (TOTP) enrolment and management.
 * The login challenge itself is handled by AuthController@login.
 */
class TwoFactorController extends Controller
{
    use ApiResponse;

    public function __construct(private readonly TwoFactorService $twoFactor) {}

    /**
     * Begin 2FA enrolment
     *
     * Generates a secret + QR URL. 2FA is NOT active until confirmed via /confirm.
     *
     * @response 200 {"success":true,"message":"Success","data":{"secret":"ABC...","qr_url":"otpauth://totp/..."}}
     */
    public function enable(Request $request): JsonResponse
    {
        $user = $request->user();
        $secret = $this->twoFactor->generateSecret();

        // Store the secret but leave confirmed_at null until the user proves they can generate a code.
        $user->forceFill(['two_factor_secret' => $secret])->save();

        return $this->success([
            'secret' => $secret,
            'qr_url' => $this->twoFactor->qrCodeUrl($user, $secret),
        ]);
    }

    /**
     * Confirm 2FA enrolment
     *
     * Validates the first TOTP code, activates 2FA, and returns recovery codes.
     *
     * @bodyParam code string required The 6-digit code from the authenticator app. Example: 123456
     * @response 200 {"success":true,"message":"تم تفعيل المصادقة الثنائية","data":{"recovery_codes":["ABCDE-FGHIJ"]}}
     * @response 422 {"success":false,"message":"الرمز غير صحيح"}
     */
    public function confirm(Request $request): JsonResponse
    {
        $request->validate(['code' => ['required', 'string']]);
        $user = $request->user();

        if (! $user->two_factor_secret ||
            ! $this->twoFactor->verify($user->two_factor_secret, $request->code)) {
            return $this->error('الرمز غير صحيح', 422);
        }

        $recoveryCodes = $this->twoFactor->generateRecoveryCodes();

        $user->forceFill([
            'two_factor_recovery_codes' => $recoveryCodes,
            'two_factor_confirmed_at'   => now(),
        ])->save();

        return $this->success(
            ['recovery_codes' => $recoveryCodes],
            'تم تفعيل المصادقة الثنائية'
        );
    }

    /**
     * Disable 2FA
     *
     * Requires the current password to prevent a hijacked session from disabling it.
     *
     * @bodyParam password string required The user's current password. Example: secret123
     * @response 200 {"success":true,"message":"تم إلغاء المصادقة الثنائية","data":null}
     */
    public function disable(Request $request): JsonResponse
    {
        $request->validate(['password' => ['required', 'string']]);

        if (! \Illuminate\Support\Facades\Hash::check($request->password, $request->user()->password)) {
            return $this->error('كلمة المرور غير صحيحة', 422);
        }

        $request->user()->forceFill([
            'two_factor_secret'         => null,
            'two_factor_recovery_codes' => null,
            'two_factor_confirmed_at'   => null,
        ])->save();

        return $this->success(null, 'تم إلغاء المصادقة الثنائية');
    }
}
