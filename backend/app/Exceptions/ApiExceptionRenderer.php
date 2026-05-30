<?php

namespace App\Exceptions;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;
use Throwable;

/**
 * Translates any thrown exception into a single, consistent JSON envelope
 * for every /api/* response:
 *
 *   { "success": false, "message": "...", "errors": { ... } }
 *
 * Centralising this means every controller, module and future endpoint
 * speaks the same error language to the Flutter client — no leaking stack
 * traces, no inconsistent shapes.
 */
class ApiExceptionRenderer
{
    public function render(Throwable $e, Request $request): ?JsonResponse
    {
        if (! $request->is('api/*') && ! $request->expectsJson()) {
            return null;
        }

        [$status, $message, $errors] = $this->map($e);

        $payload = [
            'success' => false,
            'message' => $message,
        ];

        if ($errors !== null) {
            $payload['errors'] = $errors;
        }

        // Expose debugging detail only when the app is in debug mode.
        if (config('app.debug') && $status === 500) {
            $payload['exception'] = [
                'type' => get_class($e),
                'file' => $e->getFile().':'.$e->getLine(),
            ];
        }

        // Error responses are produced outside the middleware pipeline, so
        // attach the same hardening headers here for consistency.
        return response()->json($payload, $status)
            ->withHeaders(\App\Http\Middleware\SecurityHeaders::headers());
    }

    /**
     * @return array{0:int,1:string,2:array|null}
     */
    private function map(Throwable $e): array
    {
        return match (true) {
            $e instanceof ValidationException => [
                422,
                'البيانات المدخلة غير صحيحة',
                $e->errors(),
            ],
            $e instanceof AuthenticationException => [
                401,
                'يجب تسجيل الدخول للمتابعة',
                null,
            ],
            $e instanceof AuthorizationException => [
                403,
                'ليس لديك صلاحية لتنفيذ هذا الإجراء',
                null,
            ],
            $e instanceof ModelNotFoundException,
            $e instanceof NotFoundHttpException => [
                404,
                'العنصر المطلوب غير موجود',
                null,
            ],
            $e instanceof MethodNotAllowedHttpException => [
                405,
                'الإجراء غير مسموح به',
                null,
            ],
            $e instanceof TooManyRequestsHttpException => [
                429,
                'عدد المحاولات كبير جداً، حاول مرة أخرى لاحقاً',
                null,
            ],
            $e instanceof HttpExceptionInterface => [
                $e->getStatusCode(),
                $e->getMessage() ?: 'حدث خطأ في الطلب',
                null,
            ],
            default => [
                500,
                config('app.debug') ? $e->getMessage() : 'حدث خطأ غير متوقع، حاول لاحقاً',
                null,
            ],
        };
    }
}
