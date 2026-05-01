<?php

namespace App\Filament\Resources\Reports\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ReportsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')
                    ->label('Kode Transaksi')
                    ->sortable()
                    ->formatStateUsing(fn ($state) => 'SM-' . str_pad($state, 4, '0', STR_PAD_LEFT)),

                TextColumn::make('billiard.name')
                    ->label('Meja')
                    ->sortable(),

                TextColumn::make('customer_name')
                    ->label('Nama Customer')
                    ->sortable()
                    ->searchable(),

                TextColumn::make('session_mode')
                    ->label('Mode')
                    ->badge()
                    ->color(fn ($state) => $state === 'manual' ? 'warning' : 'info')
                    ->formatStateUsing(fn ($state) => $state === 'manual' ? 'Open Billing' : 'Paket')
                    ->sortable(),

                TextColumn::make('package.package_name')
                    ->label('Paket')
                    ->default('-')
                    ->sortable(),

                TextColumn::make('duration_minutes')
                    ->label('Durasi')
                    ->sortable()
                    ->formatStateUsing(function ($state) {
                        if (!$state) return '-';

                        $jam   = intdiv($state, 60);
                        $menit = $state % 60;

                        return $jam > 0 ? "{$jam} jam {$menit} menit" : "{$menit} menit";
                    }),

                TextColumn::make('start_time')
                    ->label('Mulai')
                    ->dateTime('d M Y, H:i')
                    ->sortable(),

                TextColumn::make('end_time')
                    ->label('Selesai')
                    ->dateTime('d M Y, H:i')
                    ->sortable(),

                TextColumn::make('payment_method')
                    ->label('Metode Bayar')
                    ->badge()
                    ->color('gray')
                    ->searchable(),

                // 🔥 HARGA — mode manual dari kolom price, mode paket dari package.price
                TextColumn::make('total_harga')
                    ->label('Total Harga')
                    ->sortable()
                    ->getStateUsing(function ($record) {
                        if ($record->session_mode === 'manual') {
                            $harga = $record->price ?? 0;
                        } else {
                            $harga = optional($record->package)->price ?? 0;
                        }

                        return 'Rp ' . number_format($harga, 0, ',', '.');
                    }),

                TextColumn::make('created_at')
                    ->label('Dibuat')
                    ->dateTime('d M Y, H:i')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                //
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }
}