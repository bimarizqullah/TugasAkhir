<?php

namespace App\Filament\Resources\BilliardTables\Tables;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Actions\Action;
use Filament\Actions\EditAction;
use Filament\Notifications\Notification;
use App\Models\BilliardTable;
use App\Models\Reservation;
use App\Models\Package;
use App\Models\TableSession;
use Carbon\Carbon;
use App\Events\TableStatusUpdated;

class BilliardTablesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->poll('1s')
            ->columns([
                TextColumn::make('name')
                    ->label('Meja')
                    ->formatStateUsing(function ($state, $record) {
                        $isActive = $record->sessions()->where('session_status', 'aktif')->exists();
                        return $isActive 
                            ? '<span style="display:flex; align-items:center; gap:6px;"><span style="width:8px; height:8px; background:#22c55e; border-radius:50%; display:inline-block;"></span>' . $state . '</span>' 
                            : $state;
                    })->html(),

                TextColumn::make('antrian')
                    ->label('Antrian (Lunas)')
                    ->badge()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->getStateUsing(function (BilliardTable $record) {
                        // ANTRIAN HANYA MUNCUL JIKA STATUS MASIH 'berhasil' (Lunas tapi belum main)
                        return Reservation::where('id_billiards', $record->id)
                            ->where('payment_status', 'settlement')
                            ->where('reservation_status', 'berhasil') 
                            ->count();
                    }),

                TextColumn::make('waktu_berjalan')
                    ->label('Sisa/Durasi')
                    ->getStateUsing(function ($record) {
                        $session = $record->sessions()->where('session_status', 'aktif')->latest()->first();
                        if (!$session) return '-';
                        $now = Carbon::now();
                        if ($session->session_mode === 'paket' && $session->end_time) {
                            $end = Carbon::parse($session->end_time);
                            return $now->greaterThanOrEqualTo($end) ? 'Waktu Habis' : $now->diff($end)->format('%H:%I:%S');
                        } 
                        return Carbon::parse($session->start_time)->diff($now)->format('%H:%I:%S');
                    }),

                TextColumn::make('harga_berjalan')
                    ->label('Harga')
                    ->money('IDR')
                    ->getStateUsing(function ($record) {
                        $session = $record->sessions()->where('session_status', 'aktif')->latest()->first();
                        if (!$session) return 0;
                        if ($session->session_mode === 'manual') {
                            $detik = Carbon::parse($session->start_time)->diffInSeconds(now());
                            return (int) round((7000 / 3600) * $detik);
                        }
                        return $session->package?->price ?? 0;
                    }),

                TextColumn::make('sessions.session_status')
                    ->label('Status Meja')
                    ->badge()
                    ->color(fn ($state) => $state === 'aktif' ? 'success' : 'warning')
                    ->getStateUsing(fn ($record) => $record->sessions()->where('session_status', 'aktif')->exists() ? 'aktif' : 'tersedia'),
            ])
            ->recordActions([
                // ==================== ACTION START ====================
                Action::make('start')
                    ->label('Mulai')
                    ->icon('heroicon-o-play')
                    ->color('success')
                    ->form(function (BilliardTable $record) {
                        $reservations = Reservation::where('id_billiards', $record->id)
                            ->where('payment_status', 'settlement')
                            ->where('reservation_status', 'berhasil')
                            ->get();

                        $options = $reservations->mapWithKeys(fn($res) => [
                            $res->id => "{$res->customer_name} (Jam " . substr($res->start_time, 0, 5) . ")"
                        ])->toArray();

                        return [
                            Select::make('id_reservations')
                                ->label('Pilih dari Antrian (Lunas)')
                                ->options($options)
                                ->placeholder('Pilih antrian...')
                                ->searchable()->live()
                                ->afterStateUpdated(function ($state, callable $set) {
                                    if ($state && $res = Reservation::find($state)) {
                                        $set('customer_name', $res->customer_name);
                                        $set('id_packages', $res->id_packages);
                                        $set('session_mode', $res->id_packages ? 'paket' : 'manual');
                                    }
                                }),
                            TextInput::make('customer_name')->label('Nama Customer')->required(),
                            Select::make('session_mode')
                                ->label('Mode Billing')
                                ->options(['paket' => 'Paket', 'manual' => 'Manual'])
                                ->default('paket')->live()->required(),
                            Select::make('id_packages')
                                ->label('Pilih Paket')
                                ->options(Package::pluck('package_name', 'id'))
                                ->visible(fn ($get) => $get('session_mode') === 'paket')
                                ->required(fn ($get) => $get('session_mode') === 'paket'),
                        ];
                    })
                    ->action(function ($record, array $data) {
                    $endTime = null;
                    if ($data['session_mode'] === 'paket' && !empty($data['id_packages'])) {
                        $pkg = Package::find($data['id_packages']);
                        $endTime = now()->addMinutes($pkg->time);
                    }

                    $session = TableSession::create([
                        'id_billiards' => $record->id,
                        'id_packages' => $data['id_packages'] ?? null,
                        'id_reservations' => $data['id_reservations'] ?? null,
                        'customer_name' => $data['customer_name'],
                        'start_time' => now(),
                        'end_time' => $endTime,
                        'session_mode' => $data['session_mode'],
                        'session_status' => 'aktif',
                    ]);

                    if (!empty($data['id_reservations'])) {
                        Reservation::where('id', $data['id_reservations'])->update(['reservation_status' => 'pending']);
                    }
                    
                    // 🔥 TAMBAHKAN INI: Trigger broadcast ke Flutter
                    event(new TableStatusUpdated($record));

                    Notification::make()->title('Sesi dimulai')->success()->send();
                })
                    ->visible(fn ($record) => $record->status === 'aktif' && !$record->sessions()->where('session_status', 'aktif')->exists()),

                // ==================== ACTION STOP ====================
                Action::make('stop')
                    ->label('Stop')
                    ->icon('heroicon-o-stop')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->action(function ($record) {
                        $session = $record->sessions()->where('session_status', 'aktif')->latest()->first();
                        if ($session) {
                            $finalPrice = $session->session_mode === 'manual' 
                                ? (int) round((7000 / 3600) * Carbon::parse($session->start_time)->diffInSeconds(now())) 
                                : $session->package?->price;
                            
                            $session->update([
                                'session_status' => 'selesai',
                                'end_time' => now(),
                                'price' => $finalPrice
                            ]);

                            // Opsional: Tandai reservasi benar-benar gagal/selesai jika ingin
                            if ($session->id_reservations) {
                                Reservation::where('id', $session->id_reservations)->update(['reservation_status' => 'gagal']);
                            }

                            event(new TableStatusUpdated($record));
                        }
                        Notification::make()->title('Sesi berakhir')->danger()->send();
                    })
                    ->visible(fn ($record) => $record->sessions()->where('session_status', 'aktif')->exists()),
            ]);
    }
}