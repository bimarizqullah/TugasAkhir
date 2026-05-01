<?php

namespace App\Filament\Widgets;

use App\Models\TableSession;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class RevenueStatsWidget extends BaseWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        // Helper closure untuk hitung total pendapatan
        $hitungTotal = function ($query) {
            return $query->get()->sum(function ($session) {
                return $session->session_mode === 'manual'
                    ? ($session->price ?? 0)
                    : (optional($session->package)->price ?? 0);
            });
        };

        $baseQuery = fn () => TableSession::where('session_status', 'selesai');

        // Hari ini
        $queryHari  = $baseQuery()->whereDate('updated_at', today());
        $hariTotal  = $hitungTotal($queryHari);
        $hariCount  = $baseQuery()->whereDate('updated_at', today())->count();

        // Minggu ini
        $queryMinggu = $baseQuery()->whereBetween('updated_at', [now()->startOfWeek(), now()->endOfWeek()]);
        $mingguTotal = $hitungTotal($queryMinggu);
        $mingguCount = $baseQuery()->whereBetween('updated_at', [now()->startOfWeek(), now()->endOfWeek()])->count();

        // Bulan ini
        $queryBulan = $baseQuery()->whereMonth('updated_at', now()->month)->whereYear('updated_at', now()->year);
        $bulanTotal = $hitungTotal($queryBulan);
        $bulanCount = $baseQuery()->whereMonth('updated_at', now()->month)->whereYear('updated_at', now()->year)->count();

        // Total keseluruhan
        $queryTotal = $baseQuery();
        $totalAll   = $hitungTotal($queryTotal);
        $totalCount = $baseQuery()->count();

        return [
            Stat::make('Pendapatan Hari Ini', 'Rp ' . number_format($hariTotal, 0, ',', '.'))
                ->description($hariCount . ' sesi selesai')
                ->descriptionIcon('heroicon-o-calendar-days')
                ->color('success')
                ->icon('heroicon-o-banknotes'),

            Stat::make('Pendapatan Minggu Ini', 'Rp ' . number_format($mingguTotal, 0, ',', '.'))
                ->description($mingguCount . ' sesi selesai')
                ->descriptionIcon('heroicon-o-calendar')
                ->color('info')
                ->icon('heroicon-o-banknotes'),

            Stat::make('Pendapatan Bulan Ini', 'Rp ' . number_format($bulanTotal, 0, ',', '.'))
                ->description($bulanCount . ' sesi selesai')
                ->descriptionIcon('heroicon-o-chart-bar')
                ->color('warning')
                ->icon('heroicon-o-banknotes'),

            Stat::make('Total Pendapatan', 'Rp ' . number_format($totalAll, 0, ',', '.'))
                ->description($totalCount . ' total sesi')
                ->descriptionIcon('heroicon-o-trophy')
                ->color('primary')
                ->icon('heroicon-o-currency-dollar'),
        ];
    }
}