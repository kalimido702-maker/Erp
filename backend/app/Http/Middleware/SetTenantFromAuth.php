<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class SetTenantFromAuth
{
    public function handle(Request $request, Closure $next): mixed
    {
        if ($user = $request->user()) {
            app()->instance('tenant.company_id', $user->company_id);
        }

        return $next($request);
    }
}
