<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\BilliardTable;

class TableSession extends Model
{
    const STATUS_IDLE     = 'tersedia';
    const STATUS_ACTIVE   = 'aktif';
    const STATUS_FINISHED = 'selesai';

    protected $table = 'tb_table_sessions';

    protected $fillable = [
        'id_billiards',
        'id_packages',
        'id_reservations',
        'customer_name',
        'start_time',
        'end_time',
        'duration_minutes',
        'session_mode',
        'session_status',
        'payment_method',  // ✅ tambah
        'price',           // ✅ tambah (khusus mode manual)
    ];

    protected $casts = [
        'start_time' => 'datetime',
        'end_time'   => 'datetime',
    ];

    // 🔗 RELASI
    public function billiard()
    {
        return $this->belongsTo(BilliardTable::class, 'id_billiards');
    }

    public function package()
    {
        return $this->belongsTo(\App\Models\Package::class, 'id_packages');
    }

    public function user()
    {
        return $this->belongsTo(\App\Models\User::class, 'created_by');
    }

    public function reservation()
    {
        return $this->belongsTo(\App\Models\Reservation::class, 'id_reservations');
    }

    // 🔥 HELPER — Ambil harga final
    public function getHargaFinal(): int
    {
        if ($this->session_mode === 'manual') {
            return $this->price ?? 0;
        }

        return optional($this->package)->price ?? 0;
    }

    // 🔥 HELPER — Hitung harga manual dari durasi
    public function hitungHargaManual(): int
    {
        if (!$this->start_time || !$this->end_time) return 0;

        $detik = $this->start_time->diffInSeconds($this->end_time);
        return (int) round(7000 / 3600 * $detik);
    }

    // 🔥 EVENT MODEL
    protected static function booted()
    {
        // // AUTO ISI CREATED_BY
        // static::creating(function ($session) {
        //     if (auth()->check()) {
        //         $session->created_by = auth()->id();
        //     } else {
        //         $session->created_by = 1;
        //     }
        // });

        // LOG SAAT MAU UPDATE
        static::updating(function ($session) {
            \Log::info('UPDATING SESSION', [
                'id'         => $session->id,
                'old_status' => $session->getOriginal('session_status'),
                'new_status' => $session->session_status,
                'start_time' => $session->start_time,
                'end_time'   => $session->end_time,
            ]);
        });

        // SAAT SESI SELESAI — simpan harga & payment_method
        static::updated(function ($session) {

            if ($session->wasChanged('session_status') &&
                $session->session_status === self::STATUS_FINISHED) {

                \Log::info('SESSION FINISHED: ' . $session->id);

                // Hitung & simpan harga untuk mode manual
                if ($session->session_mode === 'manual') {
                    $total = $session->hitungHargaManual();

                    $session->updateQuietly([
                        'price'          => $total,
                        'payment_method' => $session->payment_method ?? 'cash',
                    ]);

                } else {
                    // Mode paket — harga dari tb_package, hanya simpan payment_method
                    $session->updateQuietly([
                        'payment_method' => $session->payment_method ?? 'cash',
                    ]);
                }

                \Log::info('SESSION PRICE SAVED', [
                    'session_id' => $session->id,
                    'mode'       => $session->session_mode,
                    'price'      => $session->price,
                ]);
            }
        });
    }
}