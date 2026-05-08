<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\TableSession;

class BilliardTable extends Model
{
    protected $table = 'tb_billiards';

    protected $fillable = [
        'name',
        'size',
        'status',
        'created_by'
    ];

    public function sessions()
    {
        return $this->hasMany(TableSession::class, 'id_billiards');
    }

    public function reservations()
    {
        return $this->hasMany(\App\Models\Reservation::class, 'id_billiards');
    }

    public function user()
    {
        return $this->belongsTo(\App\Models\User::class, 'created_by');
    }
}