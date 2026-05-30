<?php

namespace App\Notifications;

use App\Events\ErpEvent;
use Illuminate\Notifications\Notification;

class LowStockNotification extends Notification
{
    public function __construct(
        private readonly string $productName,
        private readonly float $currentQty,
        private readonly float $minQty,
        private readonly int $companyId,
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toDatabase(object $notifiable): array
    {
        $payload = [
            'type'         => 'low_stock',
            'product_name' => $this->productName,
            'current_qty'  => $this->currentQty,
            'min_qty'      => $this->minQty,
        ];

        ErpEvent::dispatch(
            $this->companyId,
            'low_stock',
            'تحذير: مخزون منخفض',
            "المنتج «{$this->productName}» وصل إلى {$this->currentQty} (الحد الأدنى: {$this->minQty})",
            'warning',
            $payload,
        );

        return $payload;
    }
}
