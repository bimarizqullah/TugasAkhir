<?php

namespace App\Filament\Resources\Reservations\Schemas;

use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class ReservationForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Select::make('id_billiards')
                    ->label('Meja')
                    ->options(\App\Models\BilliardTable::pluck('name', 'id'))
                    ->preload()
                    ->searchable(),
                Select::make('id_packages')
                    ->label('Paket Bermain')
                    ->options(\App\Models\Package::pluck('package_name', 'id'))
                    ->preload()
                    ->searchable(),
                TextInput::make('customer_name')
                    ->default(null),
                TextInput::make('customer_phone')
                    ->tel()
                    ->numeric()
                    ->default(null),
                DatePicker::make('reservation_date'),
                Select::make('reservation_status')
                    ->options(['berhasil' => 'Berhasil', 'pending' => 'Pending', 'gagal' => 'Gagal'])
                    ->default('pending'),
            ]);
    }
}
