<?php

namespace App\Filament\Resources\Reports\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
// Import Action bawaan Filament v5
use Filament\Actions\Action; 
use Illuminate\Database\Eloquent\Builder;
use OpenSpout\Writer\XLSX\Writer;
use OpenSpout\Common\Entity\Row;
use OpenSpout\Common\Entity\Cell;

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
                    ->searchable()
                    // 1. Ambil state/nilai kustom berdasarkan logika relasi reservasi
                    ->getStateUsing(function ($record) {
                        // Cek apakah transaksi ini jembatan dari reservasi Flutter
                        if ($record->id_reservations && $record->reservation) {
                            $status = $record->reservation->payment_status;
                            
                            if ($status === 'settlement' || $status === 'success') {
                                return 'QRIS (Reservasi)';
                            }
                            
                            return 'QRIS (' . ucfirst($status) . ')';
                        }

                        // Jika transaksi on-the-spot / kasir manual
                        return $record->payment_method ? ucfirst($record->payment_method) : 'Cash';
                    })
                    // 2. Berikan warna badge yang berbeda agar menarik dan rapi
                    ->color(fn ($state) => str_contains($state, 'QRIS') ? 'success' : 'gray'),

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
            ->headerActions([
                Action::make('exportExcel')
                    ->label('Export Excel')
                    ->icon('heroicon-o-document-arrow-down')
                    ->color('success')
                    ->form([
                        \Filament\Forms\Components\Select::make('bulan')
                            ->label('Pilih Bulan')
                            ->options([
                                '01' => 'Januari', '02' => 'Februari', '03' => 'Maret',
                                '04' => 'April',   '05' => 'Mei',      '06' => 'Juni',
                                '07' => 'Juli',    '08' => 'Agustus',  '09' => 'September',
                                '10' => 'Oktober', '11' => 'November', '12' => 'Desember',
                            ])
                            ->default(now()->format('m'))
                            ->required(),

                        \Filament\Forms\Components\Select::make('tahun')
                            ->label('Pilih Tahun')
                            ->options(array_combine(
                                range(now()->year, now()->year - 5),
                                range(now()->year, now()->year - 5)
                            ))
                            ->default(now()->year)
                            ->required(),
                    ])
                    ->action(function ($livewire, array $data) {
                        $bulan_dipilih = $data['bulan'];
                        $tahun_dipilih = $data['tahun'];

                        $query = $livewire->getFilteredTableQuery()
                            ->whereMonth('created_at', $bulan_dipilih)
                            ->whereYear('created_at', $tahun_dipilih); 
                        
                        // 🔥 SINKRONISASI: Eager load relasi 'reservation' agar bisa ngecek pembayaran dari Flutter
                        $records = $query->with(['billiard', 'package', 'reservation'])->get();

                        if ($records->isEmpty()) {
                            \Filament\Notifications\Notification::make()
                                ->title('Data Tidak Ditemukan')
                                ->body("Tidak ada transaksi pada bulan yang dipilih.")
                                ->danger()
                                ->send();
                            return;
                        }

                        $filename = "Laporan_Transaksi_{$tahun_dipilih}_{$bulan_dipilih}.xlsx";
                        $filePath = storage_path('app/public/' . $filename);

                        $writer = new \OpenSpout\Writer\XLSX\Writer();
                        $writer->openToFile($filePath);

                        // --- FORMAT STYLING ---
                        $headerStyle = (new \OpenSpout\Common\Entity\Style\Style())
                            ->setFontBold()
                            ->setFontColor(\OpenSpout\Common\Entity\Style\Color::WHITE)
                            ->setBackgroundColor('1E3A8A')
                            ->setFontSize(11);

                        $dataStyle = (new \OpenSpout\Common\Entity\Style\Style())
                            ->setFontSize(10);

                        // Tulis Header Excel
                        $headerRow = \OpenSpout\Common\Entity\Row::fromValues([
                            'Kode Transaksi', 'Meja', 'Nama Customer', 'Mode', 
                            'Paket', 'Durasi', 'Mulai', 'Selesai', 'Metode Bayar', 'Total Harga'
                        ], $headerStyle);
                        $writer->addRow($headerRow);

                        // Looping Data
                        foreach ($records as $record) {
                            $durasi = '-';
                            if ($record->duration_minutes) {
                                $jam = intdiv($record->duration_minutes, 60);
                                $menit = $record->duration_minutes % 60;
                                $durasi = $jam > 0 ? "{$jam} jam {$menit} menit" : "{$menit} menit";
                            }

                            $harga = ($record->session_mode === 'manual') 
                                ? ($record->price ?? 0) 
                                : (optional($record->package)->price ?? 0);

                            // 🔥 LOGIKA SINKRONISASI METODE BAYAR (CASH VS QRIS FLUTTER)
                            if ($record->id_reservations && $record->reservation) {
                                // Jika ada data reservasi, cek status payment dari Midtrans
                                $status = $record->reservation->payment_status;
                                if ($status === 'settlement' || $status === 'success') {
                                    $metode_bayar = 'QRIS (Reservasi)';
                                } else {
                                    $metode_bayar = 'QRIS (' . ucfirst($status) . ')';
                                }
                            } else {
                                // Jika transaksi langsung/on the spot di meja billiard
                                $metode_bayar = $record->payment_method 
                                    ? ucfirst($record->payment_method) 
                                    : 'Cash';
                            }

                            $dataRow = \OpenSpout\Common\Entity\Row::fromValues([
                                'SM-' . str_pad($record->id, 4, '0', STR_PAD_LEFT),
                                optional($record->billiard)->name ?? '-',
                                $record->customer_name ?? '-',
                                ($record->session_mode === 'manual') ? 'Open Billing' : 'Paket',
                                optional($record->package)->package_name ?? '-',
                                $durasi,
                                $record->start_time ? $record->start_time->format('d M Y, H:i') : '-',
                                $record->end_time ? $record->end_time->format('d M Y, H:i') : '-',
                                $metode_bayar, 
                                'Rp ' . number_format($harga, 0, ',', '.')
                            ], $dataStyle);
                            
                            $writer->addRow($dataRow);
                        }

                        $writer->close();

                        return response()->download($filePath)->deleteFileAfterSend(true);
                    }),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }
}