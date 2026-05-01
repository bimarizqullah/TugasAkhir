<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\TableSession;
use Illuminate\Http\Request;

class TableSessionController extends Controller
{
    // 🔹 GET status meja
    public function status($tableId)
    {
        $session = TableSession::where('id_billiard', $tableId)
            ->where('session_status', 'aktif')
            ->latest()
            ->first();

        if (!$session) {
            return response()->json([
                'session_status' => 'tersedia',
                'end_time' => 0
            ]);
        }

        return response()->json([
            'session_status' => 'aktif',
            'end_time' => strtotime($session->end_time) * 1000
        ]);
    }

    // 🔹 Update ketika waktu habis
    public function finish($tableId)
    {
        $session = TableSession::where('id_billiard', $tableId)
            ->where('session_status', 'aktif')
            ->latest()
            ->first();

        if ($session) {
            $session->update([
                'session_status' => 'selesai'
            ]);
        }

        return response()->json([
            'message' => 'Session finished'
        ]);
    }
}
