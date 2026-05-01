<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tb_reservation', function (Blueprint $table) {
            // Midtrans order ID — format: RESERVATION-{id}-{timestamp}
            $table->string('payment_order_id', 64)->nullable()->after('reservation_status');

            // QR string dari Midtrans Core API (untuk di-render di Flutter)
            $table->text('payment_qr_string')->nullable()->after('payment_order_id');

            // URL QR image dari Midtrans (opsional, sebagai fallback)
            $table->string('payment_qr_url', 512)->nullable()->after('payment_qr_string');

            // Status transaksi Midtrans yang terakhir diterima
            // pending, settlement, expire, cancel, deny
            $table->string('payment_status', 20)->nullable()->after('payment_qr_url');

            // Waktu kadaluarsa QR (default 15 menit dari Midtrans)
            $table->timestamp('payment_expired_at')->nullable()->after('payment_status');

            // Raw response dari Midtrans untuk debugging/audit
            $table->json('payment_raw')->nullable()->after('payment_expired_at');
        });
    }

    public function down(): void
    {
        Schema::table('tb_reservation', function (Blueprint $table) {
            $table->dropColumn([
                'payment_order_id',
                'payment_qr_string',
                'payment_qr_url',
                'payment_status',
                'payment_expired_at',
                'payment_raw',
            ]);
        });
    }
};