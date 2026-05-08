<?php

namespace App\Filament\Resources\BilliardTables;

use App\Filament\Resources\BilliardTables\Pages\CreateBilliardTable;
use App\Filament\Resources\BilliardTables\Pages\EditBilliardTable;
use App\Filament\Resources\BilliardTables\Pages\ListBilliardTables;
use App\Filament\Resources\BilliardTables\Schemas\BilliardTableForm;
use App\Filament\Resources\BilliardTables\Tables\BilliardTablesTable;
use App\Models\BilliardTable;
use BackedEnum;
use UnitEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class BilliardTableResource extends Resource
{
    protected static ?string $model = BilliardTable::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedSquares2x2;
    protected static string|UnitEnum|null $navigationGroup = 'Master Data';
    protected static ?string $navigationLabel = 'Meja';
    protected static ?string $pluralModelLabel = 'Meja';


    public static function form(Schema $schema): Schema
    {
        return BilliardTableForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return BilliardTablesTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListBilliardTables::route('/'),
            'create' => CreateBilliardTable::route('/create'),
            'edit' => EditBilliardTable::route('/{record}/edit'),
        ];
    }

    public static function canEdit(\Illuminate\Database\Eloquent\Model $record): bool
    {
        return auth()->user()?->user_role === 'superadmin';
    }

    public static function canView(\Illuminate\Database\Eloquent\Model $record): bool
    {
        return auth()->check();
    }

    public static function canDelete(\Illuminate\Database\Eloquent\Model $record): bool
    {
        return auth()->user()?->user_role === 'superadmin';
    }
    public static function canCreate(): bool
    {
        return auth()->user()?->user_role === 'superadmin';
    }

}
