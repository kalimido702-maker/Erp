<?php

namespace App\Notifications;

use App\Events\ErpEvent;
use Illuminate\Notifications\Notification;

class OrderApprovedNotification extends Notification
{
    public function __construct(
        private readonly string $orderNumber,
        private readonly string $orderType,
        private readonly int $companyId,
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toDatabase(object $notifiable): array
    {
        $payload = [
            'type'         => 'order_approved',
            'order_number' => $this->orderNumber,
            'order_type'   => $this->orderType,
        ];

        ErpEvent::dispatch(
            $this->companyId,
            'order_approved',
            'تمت الموافقة على الطلب',
            "تمت الموافقة على {$this->orderType} رقم {$this->orderNumber}",
            'success',
            $payload,
        );

        return $payload;
    }
}
