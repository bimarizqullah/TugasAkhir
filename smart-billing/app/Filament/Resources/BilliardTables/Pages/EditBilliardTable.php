<?php

namespace App\Filament\Resources\BilliardTables\Pages;

use App\Filament\Resources\BilliardTables\BilliardTableResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditBilliardTable extends EditRecord
{
    protected static string $resource = BilliardTableResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }
}
