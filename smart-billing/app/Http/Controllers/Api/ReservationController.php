<?php

namespace App\Http\Controllers\Api;

use App\Events\ReservationUpdated;
use App\Http\Controllers\Controller;
use App\Models\Reservation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * ReservationController
 *
 * Routes:
 *   POST   /api/reservations                  → store()
 *   GET    /api/reservations                  → index()
 *   PATCH  /api/reservations/{id}/cancel      → cancel()
 *   POST   /api/reservations/{id}/pay         → initiatePayment()
 *   GET    /api/reservations/{id}/pay/status  → paymentStatus()
 *   POST   /api/midtrans/webhook              → handleWebhook()
 *   GET    /api/reservations/available-slots  → availableSlots()
 */
class ReservationController extends Controller
{
    // ────────────────────────────────────────────
    //  Midtrans config helper
    // ────────────────────────────────────────────

    private function midtransServerKey(): string
    {
        return config('services.midtrans.server_key');
    }

    private function midtransBaseUrl(): string
    {
        $isSandbox = config('services.midtrans.is_sandbox', true);
        return $isSandbox
            ? 'https://api.sandbox.midtrans.com/v2'
            : 'https://api.midtrans.com/v2';
    }

    // ────────────────────────────────────────────
    //  1. Buat reservasi → status: menunggu_konfirmasi
    //     (QRIS belum dibuat — tunggu admin approve)
    // ────────────────────────────────────────────

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_billiards'     => 'required|integer|exists:tb_billiards,id',
            'id_packages'      => 'nullable|integer|exists:tb_package,id',
            'customer_name'    => 'required|string|min:3|max:45',
            'customer_phone'   => 'required|string|min:10|max:15',
            'reservation_date' => 'required|date|after_or_equal:today',
            'start_time'       => 'required|date_format:H:i',
            'end_time'         => 'required|date_format:H:i|after:start_time',
        ]);
    
        // 🔥 FIX: Cek bentrok — hanya vs reservasi yang punya jam valid
        $conflict = Reservation::where('id_billiards', $validated['id_billiards'])
            ->where('reservation_date', $validated['reservation_date'])
            ->whereNotIn('reservation_status', ['gagal'])
            ->whereNotNull('start_time')
            ->whereNotNull('end_time')
            ->where('start_time', '!=', '00:00:00')
            ->where('end_time',   '!=', '00:00:00')
            ->where(function ($q) use ($validated) {
                $q->where('start_time', '<', $validated['end_time'])
                ->where('end_time',   '>', $validated['start_time']);
            })
            ->exists();
    
        if ($conflict) {
            return response()->json([
                'message' => 'Meja sudah dipesan pada jam tersebut. Pilih jam lain.',
                'code'    => 'TIME_CONFLICT',
            ], 422);
        }
    
        $reservation = Reservation::create([
            'id_users'           => $request->user()->id,
            'id_billiards'       => $validated['id_billiards'],
            'id_packages'        => $validated['id_packages'] ?? null,
            'customer_name'      => $validated['customer_name'],
            'customer_phone'     => $validated['customer_phone'],
            'reservation_date'   => $validated['reservation_date'],
            'start_time'         => $validated['start_time'],
            'end_time'           => $validated['end_time'],
            'reservation_status' => 'menunggu_konfirmasi',
        ]);
    
        return response()->json([
            'message'        => 'Reservasi berhasil dibuat. Menunggu konfirmasi admin.',
            'reservation_id' => $reservation->id,
            'status'         => $reservation->reservation_status,
        ], 201);
    }

    // ────────────────────────────────────────────
    //  2. Slot yang sudah terpakai (untuk Flutter
    //     menampilkan jam yang tidak tersedia)
    // ────────────────────────────────────────────

    public function availableSlots(Request $request): JsonResponse
    {
        $request->validate([
            'id_billiards'     => 'required|integer|exists:tb_billiards,id',
            'reservation_date' => 'required|date',
        ]);
    
        $booked = Reservation::where('id_billiards', $request->id_billiards)
            ->where('reservation_date', $request->reservation_date)
            ->whereNotIn('reservation_status', ['gagal'])
            // 🔥 FIX: hanya ambil yang punya start_time & end_time valid
            ->whereNotNull('start_time')
            ->whereNotNull('end_time')
            ->where('start_time', '!=', '00:00:00')
            ->where('end_time',   '!=', '00:00:00')
            ->get(['start_time', 'end_time', 'reservation_status'])
            ->map(fn ($r) => [
                'start_time' => substr($r->start_time, 0, 5), // HH:MM
                'end_time'   => substr($r->end_time,   0, 5),
                'status'     => $r->reservation_status,
            ]);
    
        return response()->json(['booked_slots' => $booked]);
    }

    // ────────────────────────────────────────────
    //  3. Inisiasi pembayaran QRIS
    //     Hanya bisa jika status = 'dikonfirmasi'
    //     (admin sudah approve)
    // ────────────────────────────────────────────

    public function initiatePayment(Request $request, int $id): JsonResponse
    {
        $reservation = Reservation::with('package')
            ->where('id_users', $request->user()->id)
            ->findOrFail($id);

        // Belum dikonfirmasi admin
        if ($reservation->reservation_status === 'menunggu_konfirmasi') {
            return response()->json([
                'message' => 'Reservasi belum dikonfirmasi admin. Silakan tunggu.',
                'code'    => 'WAITING_APPROVAL',
            ], 422);
        }

        // Sudah berhasil bayar
        if ($reservation->reservation_status === 'berhasil') {
            return response()->json([
                'message' => 'Reservasi sudah berhasil dibayar.',
                'code'    => 'ALREADY_PAID',
            ], 422);
        }

        // Ditolak / gagal
        if ($reservation->reservation_status === 'gagal') {
            return response()->json([
                'message' => 'Reservasi ini telah dibatalkan.',
                'code'    => 'CANCELLED',
            ], 422);
        }

        // QR sebelumnya masih valid — kembalikan langsung
        if ($reservation->isQrActive()) {
            return response()->json([
                'order_id'   => $reservation->payment_order_id,
                'qr_string'  => $reservation->payment_qr_string,
                'qr_url'     => $reservation->payment_qr_url,
                'expired_at' => $reservation->payment_expired_at,
                'amount'     => $this->resolveAmount($reservation),
            ]);
        }

        // Generate QR baru
        $amount  = $this->resolveAmount($reservation);
        $orderId = 'RESERVATION-' . $reservation->id . '-' . time();

        $payload = [
            'payment_type'        => 'qris',
            'transaction_details' => [
                'order_id'     => $orderId,
                'gross_amount' => $amount,
            ],
            'qris' => ['acquirer' => 'gopay'],
            'customer_details' => [
                'first_name' => $reservation->customer_name,
                'phone'      => $reservation->customer_phone,
            ],
            'item_details' => [[
                'id'       => 'RESERVATION-' . $reservation->id,
                'price'    => $amount,
                'quantity' => 1,
                'name'     => 'Reservasi Meja Billiard',
            ]],
        ];

        $response = Http::withBasicAuth($this->midtransServerKey(), '')
            ->post($this->midtransBaseUrl() . '/charge', $payload);

        if ($response->failed()) {
            Log::error('Midtrans charge failed', [
                'reservation_id' => $reservation->id,
                'response'       => $response->body(),
            ]);
            return response()->json([
                'message' => 'Gagal menghubungi payment gateway',
                'detail'  => $response->json('status_message'),
            ], 502);
        }

        $data      = $response->json();
        $qrString  = $data['qr_string']  ?? null;
        $qrUrl     = $data['qris_url']   ?? ($data['actions'][0]['url'] ?? null);
        $expiredAt = now()->addMinutes(15);

        $reservation->update([
            'payment_order_id'   => $orderId,
            'payment_qr_string'  => $qrString,
            'payment_qr_url'     => $qrUrl,
            'payment_status'     => 'pending',
            'payment_expired_at' => $expiredAt,
            'payment_raw'        => $data,
        ]);

        return response()->json([
            'order_id'   => $orderId,
            'qr_string'  => $qrString,
            'qr_url'     => $qrUrl,
            'expired_at' => $expiredAt,
            'amount'     => $amount,
        ]);
    }

    // ────────────────────────────────────────────
    //  4. Cek status pembayaran (Flutter polling)
    // ────────────────────────────────────────────

    public function paymentStatus(Request $request, int $id): JsonResponse
    {
        $reservation = Reservation::where('id_users', $request->user()->id)
            ->findOrFail($id);

        return response()->json([
            'reservation_id'     => $reservation->id,
            'reservation_status' => $reservation->reservation_status,
            'payment_status'     => $reservation->payment_status,
            'payment_expired_at' => $reservation->payment_expired_at,
            'has_qr'             => $reservation->isQrActive(),
        ]);
    }

    // ────────────────────────────────────────────
    //  5. Webhook dari Midtrans
    // ────────────────────────────────────────────

    public function handleWebhook(Request $request): JsonResponse
    {
        $data = $request->all();

        $signatureInput = ($data['order_id']    ?? '') .
                          ($data['status_code']  ?? '') .
                          ($data['gross_amount'] ?? '') .
                          $this->midtransServerKey();

        if (($data['signature_key'] ?? '') !== hash('sha512', $signatureInput)) {
            Log::warning('Midtrans webhook signature mismatch', $data);
            return response()->json(['message' => 'Invalid signature'], 403);
        }

        $reservation = Reservation::where('payment_order_id', $data['order_id'] ?? null)->first();

        if (!$reservation) {
            return response()->json(['message' => 'Reservation not found'], 404);
        }

        $transactionStatus = $data['transaction_status'] ?? null;
        $fraudStatus       = $data['fraud_status']       ?? null;

        $newPaymentStatus     = $transactionStatus;
        $newReservationStatus = $reservation->reservation_status;

        if (in_array($transactionStatus, ['settlement', 'capture'])) {
            if ($fraudStatus === 'accept' || $fraudStatus === null) {
                $newReservationStatus = 'berhasil';
                $newPaymentStatus     = 'settlement';
            }
        } elseif (in_array($transactionStatus, ['cancel', 'deny', 'expire'])) {
            $newReservationStatus = 'gagal';
        }

        $reservation->update([
            'payment_status'     => $newPaymentStatus,
            'reservation_status' => $newReservationStatus,
            'payment_raw'        => $data,
        ]);

        broadcast(new ReservationUpdated($reservation->fresh(['billiard', 'package'])));

        return response()->json(['message' => 'OK']);
    }

    // ────────────────────────────────────────────
    //  6. List reservasi milik user
    // ────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $reservations = Reservation::with(['billiard', 'package'])
            ->where('id_users', $request->user()->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn ($r) => [
                'id'                 => $r->id,
                'customer_name'      => $r->customer_name,
                'customer_phone'     => $r->customer_phone,
                'reservation_date'   => $r->reservation_date,
                'start_time'         => $r->start_time ? substr($r->start_time, 0, 5) : null,
                'end_time'           => $r->end_time   ? substr($r->end_time,   0, 5) : null,
                'reservation_status' => $r->reservation_status,
                'payment_status'     => $r->payment_status,
                'has_active_qr'      => $r->isQrActive(),
                'billiard_name'      => $r->billiard?->name,
                'package_name'       => $r->package?->package_name,
                'created_at'         => $r->created_at,
            ]);

        return response()->json(['data' => $reservations]);
    }

    // ────────────────────────────────────────────
    //  7. Cancel reservasi
    // ────────────────────────────────────────────

    public function cancel(Request $request, int $id): JsonResponse
    {
        $reservation = Reservation::where('id_users', $request->user()->id)
            ->findOrFail($id);

        if (!in_array($reservation->reservation_status, ['menunggu_konfirmasi', 'dikonfirmasi'])) {
            return response()->json([
                'message' => 'Hanya reservasi dengan status menunggu konfirmasi atau dikonfirmasi yang bisa dibatalkan.',
            ], 422);
        }

        $reservation->update(['reservation_status' => 'gagal']);
        broadcast(new ReservationUpdated($reservation->fresh(['billiard', 'package'])));

        return response()->json(['message' => 'Reservasi berhasil dibatalkan']);
    }

    // ────────────────────────────────────────────
    //  Helper: hitung nominal
    // ────────────────────────────────────────────

    private function resolveAmount(Reservation $reservation): int
    {
        if ($reservation->package && $reservation->package->price) {
            return (int) $reservation->package->price;
        }
        return (int) config('services.midtrans.default_dp', 50000);
    }
}