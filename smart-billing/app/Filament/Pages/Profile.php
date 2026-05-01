<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Livewire\WithFileUploads;
use BackedEnum;
use UnitEnum;

class Profile extends Page implements HasForms
{
    use InteractsWithForms;
    use WithFileUploads;

    protected static BackedEnum|string|null $navigationIcon = 'heroicon-o-user-circle';
    protected string $view = 'filament.pages.profile';
    protected static string|UnitEnum|null $navigationGroup = 'Pengaturan Akun';
    protected static ?string $navigationLabel = 'Profil Saya';
    protected static ?string $title = 'Profil Saya';

    public $user;

    public ?string $name = '';
    public ?string $email = '';
    public $photo = null;
    public ?string $current_password = '';
    public ?string $new_password = '';
    public ?string $new_password_confirmation = '';

    public function mount(): void
    {
        $this->user  = Auth::user();
        $this->name  = $this->user->name;
        $this->email = $this->user->email;
    }

    public function saveProfile(): void
    {
        $this->validate([
            'name'  => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email,' . $this->user->id],
            'photo' => ['nullable', 'image', 'max:2048'],
        ]);

        $data = [
            'name'  => $this->name,
            'email' => $this->email,
        ];

        if ($this->photo) {
            $path = $this->photo->store('avatars', 'public');
            $data['photo_path'] = $path;
        }

        $this->user->update($data);
        $this->user->refresh();
        $this->photo = null;

        Notification::make()
            ->title('Profil berhasil diperbarui!')
            ->success()
            ->send();
    }

    public function savePassword(): void
    {
        $this->validate([
            'current_password' => ['required'],
            'new_password'     => ['required', 'confirmed', Password::defaults()],
        ]);

        if (! Hash::check($this->current_password, $this->user->password)) {
            $this->addError('current_password', 'Password saat ini tidak sesuai.');
            return;
        }

        $this->user->update([
            'password' => Hash::make($this->new_password),
        ]);

        $this->current_password          = '';
        $this->new_password              = '';
        $this->new_password_confirmation = '';

        Notification::make()
            ->title('Password berhasil diubah!')
            ->success()
            ->send();
    }
}