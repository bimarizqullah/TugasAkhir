<?php

namespace App\Events;

use App\Models\Reservation;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ReservationUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Reservation $reservation;

    public function __construct(Reservation $reservation)
    {
        $this->reservation = $reservation->load(['billiard', 'package']);
    }

    public function broadcastOn(): array
    {
        return [new Channel('reservations')];
    }

    public function broadcastAs(): string
    {
        return 'reservation.updated';
    }

    public function broadcastWith(): array
    {
        $r = $this->reservation;
        return [
            'id'                 => $r->id,
            'id_users'           => $r->id_users,
            'customer_name'      => $r->customer_name,
            'customer_phone'     => $r->customer_phone,
            'reservation_date'   => $r->reservation_date,
            'start_time'         => $r->start_time ? substr($r->start_time, 0, 5) : null,
            'end_time'           => $r->end_time   ? substr($r->end_time,   0, 5) : null,
            'reservation_status' => $r->reservation_status,
            'billiard_name'      => $r->billiard?->name   ?? '-',
            'package_name'       => $r->package?->package_name ?? '-',
            'created_at'         => $r->created_at?->toIso8601String(),

            // Field payment — dikirim agar Flutter langsung tampilkan QR
            // tanpa perlu hit endpoint /pay terlebih dahulu
            'payment_status'     => $r->payment_status,
            'has_active_qr'      => $r->isQrActive(),
            'payment_expired_at' => $r->payment_expired_at?->toIso8601String(),
        ];
    }
}