<?php

namespace App\Filament\Resources\Reports\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class ReportForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('payment_method')
                    ->default(null),
                TextInput::make('id_packages')
                    ->required()
                    ->numeric(),
                TextInput::make('id_sessions')
                    ->required()
                    ->numeric(),
                TextInput::make('id_table')
                    ->required()
                    ->numeric(),
                TextInput::make('created_by')
                    ->required()
                    ->numeric(),
            ]);
    }
}
