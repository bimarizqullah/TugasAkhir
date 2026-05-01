<?php

namespace App\Filament\Resources\BilliardTables\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\Hidden;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;



class BilliardTableForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->placeholder('Masukkan Nama Meja')
                    ->required(),
                TextInput::make('size')
                    ->placeholder('Contoh: 7')
                    ->numeric()
                    ->default(null),
                Select::make('status')
                    ->options(['aktif' => 'Aktif', 'nonaktif' => 'Nonaktif'])
                    ->default('aktif'),
                Hidden::make('created_by')
                    ->default(auth()->id())
                    ->required(),
            ]);
    }
}
