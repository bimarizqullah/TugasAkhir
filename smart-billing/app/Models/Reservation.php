<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Events\ReservationUpdated;

class Reservation extends Model
{
    protected $table = 'tb_reservation';

    protected $fillable = [
        'id_users',
        'id_billiards',
        'id_packages',
        'customer_name',
        'customer_phone',
        'reservation_date',
        'reservation_status',
        'start_time',
        'end_time',
        // Kolom payment Midtrans (ditambah via migration)
        'payment_order_id',
        'payment_qr_string',
        'payment_qr_url',
        'payment_status',
        'payment_expired_at',
        'payment_raw',
    ];

    protected $casts = [
        'reservation_date'   => 'date',
        'payment_expired_at' => 'datetime',
        'payment_raw'        => 'array',
    ];

    // ── Relasi ──────────────────────────────────────────────────────────

    public function user()
    {
        return $this->belongsTo(User::class, 'id_users');
    }

    public function billiard()
    {
        return $this->belongsTo(BilliardTable::class, 'id_billiards');
    }

    public function package()
    {
        return $this->belongsTo(Package::class, 'id_packages');
    }

    // ── Helper ──────────────────────────────────────────────────────────

    /**
     * Cek apakah QR masih berlaku (belum expired dan status masih pending)
     */
    public function isQrActive(): bool
    {
        return $this->payment_qr_string !== null
            && $this->payment_expired_at !== null
            && now()->lt($this->payment_expired_at)
            && $this->payment_status === 'pending';
    }

    // ── Broadcast ────────────────────────────────────────────────────────
    // CATATAN: Broadcast dilakukan secara eksplisit di:
    //   - ReservationController (store, cancel, handleWebhook, paymentStatus)
    //   - ReservationsTable (approve, tolak)
    //
    // Observer booted() DIHAPUS karena menyebabkan:
    //   1. Double/triple broadcast (observer + manual broadcast bersamaan)
    //   2. Race condition — generateQris() update payment fields → observer
    //      fired lagi dengan data belum lengkap, mengirim payload lama ke Flutter
    //   3. $reservation->load() di dalam ReservationUpdated constructor
    //      men-trigger touch internal yang bisa memicu observer ulang
}