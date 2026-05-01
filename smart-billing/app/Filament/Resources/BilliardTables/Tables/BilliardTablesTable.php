<?php

namespace App\Filament\Resources\BilliardTables\Tables;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Actions\Action;

class BilliardTablesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->poll('1s')
            ->columns([
                TextColumn::make('name')
                    ->label('Meja')
                    ->searchable()
                    ->formatStateUsing(function ($state, $record) {
                        $isActive = $record->sessions()
                            ->where('session_status', 'aktif')
                            ->exists();

                        if ($isActive) {
                            return '<span style="display:flex; align-items:center; gap:6px;">
                                        <span style="width:8px; height:8px; background:#22c55e; border-radius:50%; display:inline-block;"></span>
                                        ' . $state . '
                                    </span>';
                        }
                        return $state;
                    })
                    ->html(),

                TextColumn::make('size')->numeric()->sortable(),

                TextColumn::make('status')
                    ->visible(fn () => auth()->user()->user_role === 'superadmin')
                    ->color(fn (string $state): string => match ($state) {
                        'aktif' => 'success',   
                        'nonaktif' => 'danger',
                    })
                    ->badge(),

                TextColumn::make('sessions.session_status')
                    ->label('Status Meja')
                    ->visible(fn () => auth()->user()->user_role === 'admin')
                    ->badge()
                    ->color(function ($state) {
                        if ($state === 'Sedang Digunakan') return 'success';
                        if ($state === 'Tersedia') return 'warning';
                        if ($state === 'Nonaktif') return 'danger'; // 🔥 Tambah ini
                        return 'danger';
                    })
                    ->getStateUsing(function ($record) {
                        if ($record->status === 'nonaktif') return 'Nonaktif';
                        $active = $record->sessions()
                            ->where('session_status', 'aktif')
                            ->latest()->first();
                        return $active ? 'Sedang Digunakan' : 'Tersedia';
                    }),

                TextColumn::make('waktu_berjalan')
                    ->label('Waktu')
                    ->visible(fn () => auth()->user()->user_role === 'admin')
                    ->color(function ($state) {
                        if ($state === '-') return 'gray';
                        if ($state === '00:00:00') return 'danger';
                        return 'success';
                    })
                    ->getStateUsing(function ($record) {
                        $session = $record->sessions()
                            ->where('session_status', 'aktif')
                            ->latest()->first();

                        if (!$session) return '-';

                        if ($session->session_mode === 'manual') {
                            $elapsed = now()->diffInSeconds($session->start_time);
                            return gmdate('H:i:s', $elapsed);
                        }

                        if (!$session->end_time) return '-';

                        $remaining = now()->diffInSeconds($session->end_time, false);
                        if ($remaining <= 0) {
                            $session->update(['session_status' => 'selesai']);
                            return '00:00:00';
                        }
                        return gmdate('H:i:s', $remaining);
                    }),

                TextColumn::make('harga_berjalan')
                    ->label('Harga')
                    ->visible(fn () => auth()->user()->user_role === 'admin')
                    ->color(fn ($state) => $state === '' ? 'gray' : 'warning')
                    ->getStateUsing(function ($record) {
                        $session = $record->sessions()
                            ->where('session_status', 'aktif')
                            ->latest()->first();

                        if (!$session) return '-';

                        if ($session->session_mode === 'manual') {
                            $elapsed = now()->diffInSeconds($session->start_time);
                            $harga   = (int) abs(7000 / 3600 * $elapsed);
                            return 'Rp ' . number_format($harga, 0, ',', '.');
                        }

                        $harga = optional($session->package)->price ?? 0;
                        return 'Rp ' . number_format($harga, 0, ',', '.');
                    }),
            ])

            ->recordActions([
                EditAction::make()
                    ->visible(fn () =>
                        auth()->check() &&
                        auth()->user()->user_role === 'superadmin'
                    ),

                Action::make('start')
                    ->badge()
                    ->label('Mulai')
                    ->icon('heroicon-o-play')
                    ->color('success')
                    ->form([
                        TextInput::make('customer_name')
                            ->label('Nama Customer')
                            ->required(),

                        Select::make('session_mode')
                            ->label('Mode')
                            ->options([
                                'paket'  => 'Paket',
                                'manual' => 'Manual (Open Billing)',
                            ])
                            ->reactive()
                            ->required(),

                        Select::make('id_packages')
                            ->label('Paket')
                            ->options(\App\Models\Package::pluck('package_name', 'id'))
                            ->searchable()
                            ->preload()
                            ->visible(fn ($get) => $get('session_mode') === 'paket')
                            ->required(fn ($get) => $get('session_mode') === 'paket'),
                    ])
                    ->action(function ($record, $data) {
                        if ($data['session_mode'] === 'paket' && empty($data['id_packages'])) {
                            throw new \Exception('Pilih paket terlebih dahulu');
                        }

                        $endTime  = null;
                        $duration = null;

                        if ($data['session_mode'] === 'paket') {
                            $package  = \App\Models\Package::find($data['id_packages']);
                            $endTime  = now()->addMinutes($package->time);
                            $duration = $package->time;
                        }

                        \App\Models\TableSession::create([
                            'id_billiards'     => $record->id,
                            'id_packages'      => $data['id_packages'] ?? null,
                            'customer_name'    => $data['customer_name'],
                            'start_time'       => now(),
                            'end_time'         => $endTime,
                            'duration_minutes' => $duration,
                            'session_mode'     => $data['session_mode'],
                            'session_status'   => \App\Models\TableSession::STATUS_ACTIVE,
                        ]);

                        // 🔥 BROADCAST REALTIME
                        $record->refresh();
                        broadcast(new \App\Events\TableStatusUpdated($record));
                    })
                    ->visible(fn ($record) =>
                        auth()->check() &&
                        auth()->user()->user_role === 'admin' &&
                        $record->status === 'aktif' &&
                        !$record->sessions()->where('session_status', 'aktif')->exists()
                    ),

                Action::make('stop')
                    ->badge()
                    ->label('Selesai')
                    ->icon('heroicon-o-stop')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('Hentikan Sesi?')
                    ->modalDescription(function ($record) {
                        $session = $record->sessions()
                            ->where('session_status', 'aktif')
                            ->latest()->first();

                        if (!$session) return '';

                        if ($session->session_mode === 'manual') {
                            $elapsed     = $session->start_time->diffInSeconds(now());
                            $durasiMenit = round($elapsed / 60, 1);
                            $harga       = (int) abs(7000 / 3600 * $elapsed);
                            return "Durasi: {$durasiMenit} menit | Total: Rp " . number_format($harga, 0, ',', '.');
                        }

                        $harga = optional(
                            $record->sessions()
                                ->where('session_status', 'aktif')
                                ->latest()->first()?->package
                        )->price ?? 0;

                        return 'Sesi paket akan dihentikan. Total: Rp ' . number_format($harga, 0, ',', '.');
                    })
                    ->action(function ($record) {
                        $session = $record->sessions()
                            ->where('session_status', 'aktif')
                            ->latest()->first();

                        if (!$session) return;

                        $endTime      = now();
                        $durasiAktual = (int) $session->start_time->diffInMinutes($endTime);

                        $session->update([
                            'end_time'         => $endTime,
                            'duration_minutes' => $durasiAktual,
                            'session_status'   => 'selesai',
                        ]);

                        // 🔥 BROADCAST REALTIME
                        $record->refresh();
                        broadcast(new \App\Events\TableStatusUpdated($record));
                    })
                    ->visible(fn ($record) =>
                        auth()->check() &&
                        auth()->user()->user_role === 'admin' &&
                        $record->sessions()->where('session_status', 'aktif')->exists()
                    ),
            ]);
    }
}