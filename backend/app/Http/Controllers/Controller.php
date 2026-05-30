<?php

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;

abstract class Controller
{
    // Enables $this->authorize(...) / authorizeResource(...) in every controller.
    use AuthorizesRequests, ValidatesRequests;
}
