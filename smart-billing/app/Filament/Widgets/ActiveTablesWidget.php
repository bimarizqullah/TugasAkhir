<?php

namespace App\Filament\Widgets;

use App\Models\BilliardTable;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class ActiveTablesWidget extends BaseWidget
{
    protected static ?int $sort = 2;

    protected int | string | array $columnSpan = 'full';

    protected function getStats(): array
    {
        $totalMeja   = BilliardTable::where('status', 'aktif')->count();
        $mejaAktif   = BilliardTable::whereHas('sessions', fn ($q) =>
            $q->where('session_status', 'aktif')
        )->count();
        $mejaTersedia = $totalMeja - $mejaAktif;

        return [
            Stat::make('Total Meja', $totalMeja)
                ->description('Meja terdaftar')
                ->descriptionIcon('heroicon-o-table-cells')
                ->color('gray')
                ->icon('heroicon-o-table-cells'),

            Stat::make('Meja Aktif', $mejaAktif)
                ->description('Sedang digunakan')
                ->descriptionIcon('heroicon-o-play-circle')
                ->color('success')
                ->icon('heroicon-o-play-circle'),

            Stat::make('Meja Tersedia', $mejaTersedia)
                ->description('Siap digunakan')
                ->descriptionIcon('heroicon-o-check-circle')
                ->color('warning')
                ->icon('heroicon-o-check-circle'),
        ];
    }
}