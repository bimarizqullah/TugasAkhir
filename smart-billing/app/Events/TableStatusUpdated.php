<?php

namespace App\Events;

use App\Models\BilliardTable;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TableStatusUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $table;

    public function __construct(BilliardTable $table)
    {
        $this->table = $table->load(['sessions' => function ($query) {
            $query->where('session_status', 'aktif')->latest()->limit(1);
        }]);
    }

    public function broadcastOn(): array
    {
        return [new Channel('tables')];
    }

    public function broadcastAs(): string
    {
        return 'table.updated'; // ← Flutter listen event ini
    }

    public function broadcastWith(): array
    {
        $activeSession = $this->table->sessions->first();

        return [
            'id'             => $this->table->id,
            'name'           => $this->table->name,
            'size'           => $this->table->size,
            'table_status' => $this->table->status,
            'session_status' => $activeSession ? 'aktif' : 'tersedia',
            'session'        => $activeSession ? [
                'customer_name'    => $activeSession->customer_name ?? '-',
                'session_mode'     => strtoupper($activeSession->session_mode ?? 'NORMAL'),
                'start_time'       => $activeSession->start_time?->toIso8601String(),
                'end_time'         => optional($activeSession->end_time)->toIso8601String(),
                'duration_minutes' => $activeSession->duration_minutes,
            ] : [
                // 🔥 FIX: kirim empty session object, bukan null
                'customer_name' => '-',
                'session_mode'  => 'NORMAL',
                'start_time'    => null,
                'end_time'      => null,
            ],
        ];
    }
}