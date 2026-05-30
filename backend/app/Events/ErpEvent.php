<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ErpEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly int $companyId,
        public readonly string $type,
        public readonly string $title,
        public readonly string $message,
        public readonly string $severity = 'info',
        public readonly array $data = [],
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('company.' . $this->companyId)];
    }

    public function broadcastAs(): string
    {
        return 'erp.notification';
    }

    public function broadcastWith(): array
    {
        return [
            'type'     => $this->type,
            'title'    => $this->title,
            'message'  => $this->message,
            'severity' => $this->severity,
            'data'     => $this->data,
            'at'       => now()->toIso8601String(),
        ];
    }
}
