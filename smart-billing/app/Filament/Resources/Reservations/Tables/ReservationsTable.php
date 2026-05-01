<?php

namespace App\Filament\Resources\Reservations\Tables;

use App\Models\Reservation;
use App\Events\ReservationUpdated;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Actions\Action;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ReservationsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->poll('3s')
            ->columns([
                TextColumn::make('customer_name')
                    ->label('Nama')
                    ->searchable(),

                TextColumn::make('billiard.name')
                    ->label('Meja')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('package.package_name')
                    ->label('Paket')
                    ->default('-')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('customer_phone')
                    ->label('Telepon')
                    ->searchable(),

                TextColumn::make('reservation_date')
                    ->label('Tanggal')
                    ->date('d M Y')
                    ->sortable(),

                // Jam bermain
                TextColumn::make('start_time')
                    ->label('Jam Mulai')
                    ->formatStateUsing(fn ($state) => $state ? substr($state, 0, 5) : '-'),

                TextColumn::make('end_time')
                    ->label('Jam Selesai')
                    ->formatStateUsing(fn ($state) => $state ? substr($state, 0, 5) : '-'),

                TextColumn::make('reservation_status')
                    ->label('Status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'berhasil'            => 'success',
                        'dikonfirmasi'        => 'info',
                        'menunggu_konfirmasi' => 'warning',
                        'pending'             => 'warning',
                        'gagal'               => 'danger',
                        default               => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'menunggu_konfirmasi' => 'Menunggu Konfirmasi',
                        'dikonfirmasi'        => 'Dikonfirmasi',
                        'berhasil'            => 'Berhasil',
                        'gagal'               => 'Gagal',
                        'pending'             => 'Pending',
                        default               => $state,
                    }),

                TextColumn::make('payment_status')
                    ->label('Pembayaran')
                    ->badge()
                    ->color(fn (?string $state): string => match ($state) {
                        'settlement' => 'success',
                        'pending'    => 'warning',
                        'expire'     => 'danger',
                        'cancel'     => 'danger',
                        default      => 'gray',
                    })
                    ->default('-'),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([])
            ->recordActions([

                // ── APPROVE: konfirmasi + generate QRIS ──
                Action::make('approve')
                    ->label('Approve & Generate QR')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('Konfirmasi & Generate QRIS')
                    ->modalDescription('Reservasi akan dikonfirmasi dan QRIS otomatis dibuat untuk dikirim ke pelanggan.')
                    ->modalSubmitActionLabel('Ya, Approve')
                    ->visible(fn (Reservation $record): bool =>
                        $record->reservation_status === 'menunggu_konfirmasi'
                    )
                    ->action(function (Reservation $record): void {
                        // 1. Update status → dikonfirmasi
                        $record->update(['reservation_status' => 'dikonfirmasi']);

                        // 2. Generate QRIS via Midtrans
                        self::generateQris($record);

                        // 3. Broadcast ke Flutter
                        $record->refresh();
                        broadcast(new ReservationUpdated($record->load(['billiard', 'package'])));
                    }),

                // ── TOLAK ──
                Action::make('tolak')
                    ->label('Tolak')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('Tolak Reservasi')
                    ->modalDescription('Status akan diubah menjadi Gagal dan reservasi tidak dapat dilanjutkan.')
                    ->modalSubmitActionLabel('Ya, Tolak')
                    ->visible(fn (Reservation $record): bool =>
                        in_array($record->reservation_status, ['menunggu_konfirmasi', 'dikonfirmasi'])
                    )
                    ->action(function (Reservation $record): void {
                        $record->update(['reservation_status' => 'gagal']);
                        $record->refresh();
                        broadcast(new ReservationUpdated($record->load(['billiard', 'package'])));
                    }),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    // ────────────────────────────────────────────────────
    //  Helper: panggil Midtrans Core API untuk generate QR
    // ────────────────────────────────────────────────────

    private static function generateQris(Reservation $record): void
    {
        // Jika QR masih aktif, tidak perlu generate ulang
        if ($record->isQrActive()) {
            return;
        }

        $isSandbox = config('services.midtrans.is_sandbox', true);
        $baseUrl   = $isSandbox
            ? 'https://api.sandbox.midtrans.com/v2'
            : 'https://api.midtrans.com/v2';
        $serverKey = config('services.midtrans.server_key');

        $amount  = self::resolveAmount($record);
        $orderId = 'RESERVATION-' . $record->id . '-' . time();

        $payload = [
            'payment_type'        => 'qris',
            'transaction_details' => [
                'order_id'     => $orderId,
                'gross_amount' => $amount,
            ],
            'qris' => ['acquirer' => 'gopay'],
            'customer_details' => [
                'first_name' => $record->customer_name,
                'phone'      => $record->customer_phone,
            ],
            'item_details' => [[
                'id'       => 'RESERVATION-' . $record->id,
                'price'    => $amount,
                'quantity' => 1,
                'name'     => 'Reservasi Meja Billiard',
            ]],
        ];

        try {
            $response = Http::withBasicAuth($serverKey, '')
                ->post($baseUrl . '/charge', $payload);

            if ($response->successful()) {
                $data = $response->json();
                $record->update([
                    'payment_order_id'   => $orderId,
                    'payment_qr_string'  => $data['qr_string']  ?? null,
                    'payment_qr_url'     => $data['qris_url']   ?? ($data['actions'][0]['url'] ?? null),
                    'payment_status'     => 'pending',
                    'payment_expired_at' => now()->addMinutes(15),
                    'payment_raw'        => $data,
                ]);
            } else {
                Log::error('Midtrans QRIS generate failed (admin approve)', [
                    'reservation_id' => $record->id,
                    'response'       => $response->body(),
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Midtrans QRIS exception', [
                'reservation_id' => $record->id,
                'error'          => $e->getMessage(),
            ]);
        }
    }

    private static function resolveAmount(Reservation $record): int
    {
        $record->loadMissing('package');
        if ($record->package && $record->package->price) {
            return (int) $record->package->price;
        }
        return (int) config('services.midtrans.default_dp', 50000);
    }
}