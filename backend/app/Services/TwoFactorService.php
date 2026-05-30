<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use PragmaRX\Google2FA\Google2FA;

/**
 * TOTP-based two-factor authentication (compatible with Google Authenticator,
 * Authy, 1Password, …). Secrets and recovery codes are encrypted at rest via
 * the User model's `encrypted` casts.
 */
class TwoFactorService
{
    public function __construct(private readonly Google2FA $engine) {}

    /** Generate a new base32 secret (not yet persisted/confirmed). */
    public function generateSecret(): string
    {
        return $this->engine->generateSecretKey();
    }

    /** Build the otpauth:// URI used to render the QR code on the client. */
    public function qrCodeUrl(User $user, string $secret): string
    {
        return $this->engine->getQRCodeUrl(
            config('app.name', 'ERP'),
            $user->email,
            $secret,
        );
    }

    /** Verify a 6-digit TOTP code against the user's secret. */
    public function verify(string $secret, string $code): bool
    {
        return $this->engine->verifyKey($secret, $code);
    }

    /** Generate a fresh batch of single-use recovery codes. */
    public function generateRecoveryCodes(int $count = 8): array
    {
        return Collection::times($count, fn () =>
            Str::upper(Str::random(5) . '-' . Str::random(5))
        )->all();
    }

    /**
     * Consume a recovery code if it matches; returns the remaining codes,
     * or null when the code is invalid.
     */
    public function consumeRecoveryCode(array $codes, string $candidate): ?array
    {
        $candidate = Str::upper(trim($candidate));
        if (! in_array($candidate, $codes, true)) {
            return null;
        }

        return array_values(array_filter($codes, fn ($c) => $c !== $candidate));
    }
}
