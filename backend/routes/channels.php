<?php

use Illuminate\Support\Facades\Broadcast;

// Company-wide channel — only authenticated users of the same company
Broadcast::channel('company.{companyId}', function ($user, $companyId) {
    return (int) $user->company_id === (int) $companyId;
});

// Private user channel
Broadcast::channel('user.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});
