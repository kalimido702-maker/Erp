<?php

namespace Modules\Settings\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Modules\Settings\Models\Setting;

class SettingsController extends Controller
{
    use ApiResponse;

    public function index(): JsonResponse
    {
        $settings = Setting::all()->groupBy('group');

        return $this->success($settings);
    }

    public function update(Request $request): JsonResponse
    {
        $request->validate([
            'settings'         => ['required', 'array'],
            'settings.*.key'   => ['required', 'string'],
            'settings.*.value' => ['required'],
            'settings.*.group' => ['nullable', 'string'],
        ]);

        foreach ($request->settings as $item) {
            Setting::set($item['key'], $item['value'], $item['group'] ?? 'general');
        }

        return $this->success(null, 'تم حفظ الإعدادات بنجاح');
    }
}
