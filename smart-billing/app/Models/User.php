<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Filament\Models\Contracts\HasAvatar;
use Illuminate\Notifications\Notifiable;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;

class User extends Authenticatable implements HasAvatar, FilamentUser
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'photo_path',
        'name',
        'email',
        'password',
        'user_role',
        'status'
    ];
    protected $hidden = [
        'password',
        'remember_token',
    ];
    protected $attributes = [
        'photo_path' => 'avatars/default.jpg',
    ];
    protected function casts(): array
    {
        return [
            'password' => 'hashed',
        ];
    }

    public function canAccessPanel(Panel $panel): bool
    {
        return $this->status === 'aktif';
    }

    public function getFilamentAvatarUrl(): ?string
    {
        return $this->photo_path
            ? asset('storage/' . $this->photo_path)
            : asset('storage/avatars/default.jpg');
    }
    
    public function getRoleLabelAttribute()
    {
        return ucfirst($this->user_role);
    }
}
