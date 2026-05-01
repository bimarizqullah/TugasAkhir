<?php

namespace App\Filament\Resources\Users\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\FileUpload;
use Filament\Schemas\Schema;

class UserForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->required(),
                TextInput::make('email')
                    ->label('Email address')
                    ->email()
                    ->required(),
                Select::make('user_role')
                    ->label('User Role')
                    ->options([
                        'admin' => 'Admin',
                        'superadmin' => 'Super Admin',
                        'customer' => 'Customer'
                    ])
                    ->required(),
                Select::make('status')
                    ->label('User Status')
                    ->options([
                        'aktif' => 'Aktif',
                        'nonaktif' => 'Nonaktif',
                    ])
                    ->required(),
                TextInput::make('password')
                    ->password()
                    ->visibleOn('create')
                    ->revealable()
                    ->required(fn ($livewire) => $livewire instanceof CreateRecord),
            ]);
    }
}
