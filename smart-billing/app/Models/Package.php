<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Package extends Model
{
    protected $table = 'tb_package';

    protected $fillable = [
        'package_name',
        'time',
        'price',
    ];
}
