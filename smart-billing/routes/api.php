<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Log;
use App\Models\BilliardTable;
use App\Models\TableSession;
use App\Models\Package;
use App\Models\User;
use App\Http\Controllers\Api\ReservationController;

// ==========================
// START SESSION
// ==========================
Route::post('/start-session', function (Request $request) {
    $request->validate([
        'table_id'      => 'required|exists:tb_billiards,id',
        'mode'          => 'required|in:manual,paket',
        'duration'      => 'required_if:mode,manual|integer|min:1',
        'id_packages'   => 'required_if:mode,paket|exists:tb_package,id',
        'customer_name' => 'nullable|string|max:100',
    ]);

    $table = BilliardTable::findOrFail($request->table_id);

    $activeSession = $table->sessions()->where('session_status', 'aktif')->first();
    if ($activeSession) {
        return response()->json(['message' => 'Meja sedang digunakan'], 400);
    }

    $mode     = $request->mode;
    $endTime  = null;
    $duration = null;

    if ($mode === 'manual') {
        $duration = (int) $request->duration;
        $endTime  = now()->addMinutes($duration);
    } else {
        $package  = Package::find($request->id_packages);
        $duration = $package?->time ?? 60;
        $endTime  = now()->addMinutes($duration);
    }

    $session = TableSession::create([
        'id_billiards'     => $table->id,
        'id_packages'      => $request->id_packages ?? null,
        'customer_name'    => $request->customer_name ?? 'Mobile User',
        'start_time'       => now(),
        'end_time'         => $endTime,
        'duration_minutes' => $duration,
        'session_mode'     => $mode,
        'session_status'   => 'aktif',
        'created_by'       => 1,
    ]);

    $table->refresh();
    broadcast(new \App\Events\TableStatusUpdated($table));
    Log::info('🔥 BROADCAST SENT', ['table_id' => $table->id]);

    return response()->json([
        'message' => 'Sesi dimulai',
        'data'    => $session,
    ]);
});

// ==========================
// TABLE STATUS
// ==========================
Route::get('/table-status/{id}', function ($id) {
    $table = BilliardTable::find($id);
    if (!$table) {
        return response()->json(['message' => 'Meja tidak ditemukan'], 404);
    }

    $session = $table->sessions()
        ->where('session_status', 'aktif')
        ->latest()->first();

    if (!$session) {
        return response()->json([
            'table_name' => $table->name,
            'active'     => false,
        ]);
    }

    $remaining = now()->diffInSeconds($session->end_time, false);

    if ($remaining <= 0) {
        $session->update(['session_status' => 'selesai']);
        return response()->json([
            'table_name' => $table->name,
            'active'     => false,
            'remaining'  => 0,
        ]);
    }

    return response()->json([
        'table_name'        => $table->name,
        'active'            => true,
        'session_mode'      => $session->session_mode,
        'remaining_seconds' => $remaining,
        'elapsed_seconds'   => now()->diffInSeconds($session->start_time),
    ]);
});

// ==========================
// STOP SESSION
// ==========================
Route::post('/stop-session', function (Request $request) {
    $request->validate(['table_id' => 'required|exists:tb_billiards,id']);

    $table   = BilliardTable::findOrFail($request->table_id);
    $session = $table->sessions()->where('session_status', 'aktif')->latest()->first();

    if (!$session) {
        return response()->json(['message' => 'Tidak ada sesi aktif'], 404);
    }

    $session->update(['end_time' => now(), 'session_status' => 'selesai']);

    $table->refresh();
    broadcast(new \App\Events\TableStatusUpdated($table));

    return response()->json(['message' => 'Sesi selesai']);
});

// ==========================
// TABLES
// ==========================
Route::middleware('auth:sanctum')->get('/tables', function () {
    $tables = BilliardTable::with(['sessions' => function ($q) {
        $q->where('session_status', 'aktif')->latest()->limit(1);
    }])->get(['id', 'name', 'size', 'status']);

    return response()->json(['data' => $tables->map(function ($table) {
        $s = $table->sessions->first();
        return [
            'id'             => $table->id,
            'name'           => $table->name,
            'size'           => $table->size,
            'table_status'   => $table->status,
            'session_status' => $s ? 'aktif' : 'tersedia',
            'session'        => $s ? [
                'id'               => $s->id,
                'customer_name'    => $s->customer_name,
                'start_time'       => $s->start_time,
                'end_time'         => $s->end_time,
                'duration_minutes' => $s->duration_minutes,
                'session_mode'     => $s->session_mode,
            ] : null,
        ];
    })]);
});

Route::get('/tables', function () {
    $tables = BilliardTable::with(['sessions' => function ($q) {
        $q->where('session_status', 'aktif')->latest()->limit(1);
    }])->get(['id', 'name', 'size', 'status']);

    return response()->json(['data' => $tables->map(function ($table) {
        $s = $table->sessions->first();
        return [
            'id'             => $table->id,
            'name'           => $table->name,
            'size'           => $table->size,
            'table_status'   => $table->status,
            'session_status' => $s ? 'aktif' : 'tersedia',
            'session'        => $s ? [
                'id'               => $s->id,
                'customer_name'    => $s->customer_name,
                'start_time'       => $s->start_time,
                'end_time'         => $s->end_time,
                'duration_minutes' => $s->duration_minutes,
                'session_mode'     => $s->session_mode,
            ] : null,
        ];
    })]);
});

Route::get('/tables/{id}/queue', function ($id) {
    $table = \App\Models\BilliardTable::find($id);
    if (!$table) {
        return response()->json(['message' => 'Meja tidak ditemukan'], 404);
    }

    $queue = \App\Models\Reservation::with(['package'])
        ->where('id_billiards', $id)
        ->whereNotIn('reservation_status', ['gagal'])
        ->orderBy('reservation_date', 'asc')
        ->orderBy('start_time', 'asc')
        ->get()
        ->map(fn ($r) => [
            'id'                 => $r->id,
            'queue_number'       => null,
            'customer_name'      => $r->customer_name,
            'customer_phone'     => $r->customer_phone,
            'reservation_date'   => $r->reservation_date?->format('Y-m-d'),
            // 🔥 Handle null start_time/end_time dengan aman
            'start_time'         => $r->start_time && $r->start_time !== '00:00:00'
                                        ? substr($r->start_time, 0, 5)
                                        : null,
            'end_time'           => $r->end_time && $r->end_time !== '00:00:00'
                                        ? substr($r->end_time, 0, 5)
                                        : null,
            'reservation_status' => $r->reservation_status,
            'package_name'       => $r->package?->package_name ?? 'Tanpa Paket',
            'created_at'         => $r->created_at?->toIso8601String(),
            'id_users'           => $r->id_users,
        ])
        ->values()
        ->map(function ($item, $index) {
            $item['queue_number'] = $index + 1;
            return $item;
        });

    return response()->json([
        'table_id'   => (int) $id,
        'table_name' => $table->name,
        'total'      => $queue->count(),
        'data'       => $queue,
    ]);
});

// ==========================
// AUTH
// ==========================
Route::post('/register', function (Request $request) {
    $request->validate([
        'name'     => 'required|string|max:45',
        'email'    => 'required|email|max:35|unique:users,email',
        'password' => 'required|string|min:8|confirmed',
    ]);

    $user  = User::create([
        'name'      => $request->name,
        'email'     => $request->email,
        'password'  => bcrypt($request->password),
        'user_role' => 'customer',
        'status'    => 'aktif',
    ]);
    $token = $user->createToken('mobile-app')->plainTextToken;

    return response()->json([
        'message' => 'Registrasi berhasil',
        'token'   => $token,
        'user'    => ['id' => $user->id, 'name' => $user->name,
                      'email' => $user->email, 'role' => $user->user_role],
    ], 201);
});

Route::post('/login', function (Request $request) {
    $request->validate(['email' => 'required|email', 'password' => 'required|string']);

    $user = User::where('email', $request->email)->first();
    if (!$user || !Hash::check($request->password, $user->password)) {
        return response()->json(['message' => 'Email atau password salah'], 401);
    }
    if ($user->status !== 'aktif') {
        return response()->json(['message' => 'Akun tidak aktif'], 403);
    }

    $user->tokens()->where('name', 'mobile-app')->delete();
    $token = $user->createToken('mobile-app')->plainTextToken;

    return response()->json([
        'message' => 'Login berhasil',
        'token'   => $token,
        'user'    => ['id' => $user->id, 'name' => $user->name,
                      'email' => $user->email, 'role' => $user->user_role],
    ]);
});

Route::post('/auth/google', function (Request $request) {
    $request->validate([
        'google_id'  => 'required|string',
        'name'       => 'required|string|max:45',
        'email'      => 'required|email|max:35',
        'photo_path' => 'nullable|string',
    ]);

    $user = User::where('email', $request->email)->first();
    if ($user) {
        if ($user->status !== 'aktif') {
            return response()->json(['message' => 'Akun tidak aktif'], 403);
        }
    } else {
        $user = User::create([
            'name'       => $request->name,
            'email'      => $request->email,
            'password'   => bcrypt(\Str::random(32)),
            'user_role'  => 'customer',
            'status'     => 'aktif',
            'photo_path' => $request->photo_path ?? 'avatars/default.jpg',
        ]);
    }

    $user->tokens()->where('name', 'mobile-app')->delete();
    $token = $user->createToken('mobile-app')->plainTextToken;

    return response()->json([
        'message' => 'Login dengan Google berhasil',
        'token'   => $token,
        'user'    => ['id' => $user->id, 'name' => $user->name,
                      'email' => $user->email, 'role' => $user->user_role,
                      'photo' => $user->getFilamentAvatarUrl()],
    ]);
});

Route::middleware('auth:sanctum')->post('/logout', function (Request $request) {
    $request->user()->tokens()->where('name', 'mobile-app')->delete();
    return response()->json(['message' => 'Logout berhasil']);
});

Route::middleware('auth:sanctum')->get('/profile', function (Request $request) {
    $user = $request->user();
    return response()->json(['user' => [
        'id'    => $user->id,
        'name'  => $user->name,
        'email' => $user->email,
        'role'  => $user->user_role,
        'photo' => $user->getFilamentAvatarUrl(),
    ]]);
});

// ==========================
// PACKAGES
// ==========================
Route::get('/packages', function () {
    try {
        $packages = \App\Models\Package::all(['id', 'package_name', 'time', 'price']);
        return response()->json(['data' => $packages]);
    } catch (\Exception $e) {
        \Illuminate\Support\Facades\Log::error('Package error: '.$e->getMessage());
        return response()->json(['data' => [], 'error' => $e->getMessage()], 500);
    }
});

// ==========================
// MIDTRANS WEBHOOK
// ==========================
Route::post('/midtrans/webhook', [ReservationController::class, 'handleWebhook'])
    ->name('midtrans.webhook');

// ==========================
// 🔥 RESERVASI — semua via ReservationController
//    Route lama (closure) DIHAPUS agar start_time/end_time tersimpan
// ==========================
Route::middleware('auth:sanctum')->group(function () {
    Route::prefix('reservations')->group(function () {
        Route::get('/',                  [ReservationController::class, 'index']);
        Route::post('/',                 [ReservationController::class, 'store']);
        Route::get('/available-slots',   [ReservationController::class, 'availableSlots']);
        Route::patch('/{id}/cancel',     [ReservationController::class, 'cancel']);
        Route::post('/{id}/pay',         [ReservationController::class, 'initiatePayment']);
        Route::get('/{id}/pay/status',   [ReservationController::class, 'paymentStatus']);
    });
});