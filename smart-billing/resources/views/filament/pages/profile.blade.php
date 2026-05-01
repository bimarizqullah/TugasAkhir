<x-filament-panels::page>
    @php
        $isActive = $user->status === 'aktif';
        $avatarUrl = $photo
            ? $photo->temporaryUrl()
            : ($user->photo_path ? asset('storage/' . $user->photo_path) : null);

        $initials = strtoupper(substr($user->name, 0, 2));
    @endphp

    <style>
        .profile-hero-card {
            background: linear-gradient(160deg, var(--color-primary-700, #1d4ed8) 0%, var(--color-primary-500, #3b82f6) 55%, var(--color-primary-400, #60a5fa) 100%);
            border-radius: 1rem;
            padding: 2rem 1.75rem;
            position: relative;
            overflow: hidden;
            box-shadow: 0 20px 60px -10px rgba(30,64,175,0.4);
            height: 100%;
            display: flex;
            flex-direction: column;
            gap: 1.5rem;
        }
        .profile-hero-card::before {
            content: '';
            position: absolute;
            top: -70px; right: -70px;
            width: 200px; height: 200px;
            border-radius: 50%;
            background: rgba(255,255,255,0.08);
            pointer-events: none;
        }
        .profile-hero-card::after {
            content: '';
            position: absolute;
            bottom: -50px; left: -30px;
            width: 180px; height: 180px;
            border-radius: 50%;
            background: rgba(255,255,255,0.05);
            pointer-events: none;
        }
        .hero-deco-sm {
            position: absolute;
            top: 55%; right: 15%;
            width: 70px; height: 70px;
            border-radius: 50%;
            background: rgba(255,255,255,0.04);
            pointer-events: none;
        }
        .avatar-wrap {
            position: relative;
            width: 90px;
            flex-shrink: 0;
        }
        .avatar-img {
            width: 90px; height: 90px;
            border-radius: 50%;
            overflow: hidden;
            box-shadow: 0 0 0 3px rgba(255,255,255,0.35), 0 8px 24px rgba(0,0,0,0.2);
        }
        .avatar-img img { width: 100%; height: 100%; object-fit: cover; }
        .avatar-fallback {
            width: 100%; height: 100%;
            display: flex; align-items: center; justify-content: center;
            background: rgba(255,255,255,0.18);
            backdrop-filter: blur(10px);
            font-size: 1.75rem;
            font-weight: 800;
            color: white;
            letter-spacing: -0.03em;
        }
        .avatar-dot {
            position: absolute;
            bottom: 4px; right: 4px;
            width: 15px; height: 15px;
            border-radius: 50%;
            background: #4ade80;
            border: 2.5px solid white;
            box-shadow: 0 0 0 2px rgba(74,222,128,0.35);
        }
        .hero-divider {
            height: 1px;
            background: rgba(255,255,255,0.12);
        }
        .hero-meta-row { display: flex; flex-direction: column; gap: 0.75rem; }
        .hero-meta-item { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }
        .hero-meta-label {
            font-size: 0.7rem;
            color: rgba(255,255,255,0.5);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            display: flex; align-items: center; gap: 0.35rem;
        }
        .hero-meta-value { font-size: 0.8rem; color: white; font-weight: 600; text-align: right; }
        .stat-pill {
            display: inline-flex; align-items: center; gap: 0.35rem;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.7rem; font-weight: 700; letter-spacing: 0.02em;
        }
        .profile-main-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 1.5rem;
        }
        @media (min-width: 1024px) {
            .profile-main-grid { grid-template-columns: 300px 1fr; }
        }
        .form-right-col { display: flex; flex-direction: column; gap: 1.5rem; }
        .form-input-custom {
            display: block; width: 100%;
            border-radius: 0.625rem;
            border: 1.5px solid rgba(209,213,219,1);
            background: white;
            padding: 0.625rem 0.75rem 0.625rem 2.5rem;
            font-size: 0.875rem; color: #111827;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
            transition: border-color 0.15s, box-shadow 0.15s;
            outline: none; box-sizing: border-box;
        }
        .form-input-custom:focus {
            border-color: var(--color-primary-500, #3b82f6);
            box-shadow: 0 0 0 3px rgba(59,130,246,0.12);
        }
        .dark .form-input-custom {
            background: rgba(255,255,255,0.06);
            border-color: rgba(255,255,255,0.1);
            color: white;
        }
        .dark .form-input-custom:focus {
            border-color: var(--color-primary-400, #60a5fa);
            box-shadow: 0 0 0 3px rgba(96,165,250,0.15);
        }
        .input-icon {
            position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%);
            width: 1rem; height: 1rem; color: #9ca3af; pointer-events: none;
        }
        .upload-zone {
            display: flex; align-items: center; gap: 0.5rem;
            padding: 0.5rem 0.875rem;
            border-radius: 0.625rem;
            border: 1.5px dashed rgba(209,213,219,1);
            font-size: 0.8rem; color: #6b7280;
            cursor: pointer; transition: all 0.2s;
            background: rgba(249,250,251,1);
        }
        .upload-zone:hover {
            border-color: var(--color-primary-400, #60a5fa);
            color: var(--color-primary-600, #2563eb);
            background: rgba(239,246,255,1);
        }
        .dark .upload-zone {
            background: rgba(255,255,255,0.03);
            border-color: rgba(255,255,255,0.1);
            color: rgba(255,255,255,0.4);
        }
        .dark .upload-zone:hover {
            border-color: var(--color-primary-400, #60a5fa);
            color: var(--color-primary-300, #93c5fd);
            background: rgba(255,255,255,0.05);
        }
        .section-icon-wrap {
            width: 2rem; height: 2rem; border-radius: 0.5rem;
            display: flex; align-items: center; justify-content: center; flex-shrink: 0;
        }
        .warning-info-box {
            display: flex; align-items: flex-start; gap: 0.625rem;
            border-radius: 0.75rem; padding: 0.75rem 0.875rem;
            background: rgba(255,251,235,1);
            border: 1px solid rgba(253,230,138,0.8);
        }
        .dark .warning-info-box {
            background: rgba(120,80,0,0.12);
            border-color: rgba(180,120,0,0.2);
        }
        .form-label {
            display: block; font-size: 0.8125rem; font-weight: 600;
            color: #374151; margin-bottom: 0.5rem;
        }
        .dark .form-label { color: #d1d5db; }
        .name-email-grid { display: grid; grid-template-columns: 1fr; gap: 1rem; }
        @media (min-width: 640px) { .name-email-grid { grid-template-columns: 1fr 1fr; } }
        .pass-grid { display: grid; grid-template-columns: 1fr; gap: 1rem; }
        @media (min-width: 768px) { .pass-grid { grid-template-columns: 1fr 1fr 1fr; } }
    </style>

    <div class="profile-main-grid">

        {{-- ══ KIRI: HERO ══ --}}
        <div>
            <div class="profile-hero-card">
                <div class="hero-deco-sm"></div>

                {{-- Avatar & Name --}}
                <div style="position:relative;display:flex;flex-direction:column;align-items:center;gap:1rem;text-align:center;">
                    <div class="avatar-wrap">
                        <div class="avatar-img">
                            @if ($avatarUrl)
                                <img src="{{ $avatarUrl }}" alt="{{ $user->name }}" />
                            @else
                                <div class="avatar-fallback">{{ $initials }}</div>
                            @endif
                        </div>
                        <span class="avatar-dot"></span>
                    </div>
                    <div>
                        <h2 style="font-size:1.25rem;font-weight:800;color:white;letter-spacing:-0.02em;line-height:1.2;">
                            {{ $user->name }}
                        </h2>
                        <p style="font-size:0.8rem;color:rgba(255,255,255,0.6);margin-top:0.25rem;">
                            {{ $user->email }}
                        </p>
                        <div style="display:flex;flex-wrap:wrap;justify-content:center;gap:0.375rem;margin-top:0.75rem;">
                            <span class="stat-pill" style="background:rgba(255,255,255,0.18);color:white;">
                                <svg style="width:0.65rem;height:0.65rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"/>
                                </svg>
                                {{ ucfirst(str_replace('_', ' ', $user->user_role ?? 'User')) }}
                            </span>
                            <span class="stat-pill" style="{{ $isActive ? 'background:rgba(74,222,128,0.2);color:#bbf7d0;' : 'background:rgba(248,113,113,0.2);color:#fecaca;' }}">
                                <span style="width:0.4rem;height:0.4rem;border-radius:50%;display:inline-block;background:{{ $isActive ? '#4ade80' : '#f87171' }};"></span>
                                {{ $isActive ? 'Aktif' : 'Nonaktif' }}
                            </span>
                        </div>
                    </div>
                </div>

                <div class="hero-divider"></div>

                {{-- Meta info --}}
                <div class="hero-meta-row">
                    <div class="hero-meta-item">
                        <span class="hero-meta-label">
                            <svg style="width:0.7rem;height:0.7rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5"/>
                            </svg>
                            Bergabung
                        </span>
                        <span class="hero-meta-value">{{ $user->created_at?->translatedFormat('d M Y') ?? '-' }}</span>
                    </div>
                    <div class="hero-meta-item">
                        <span class="hero-meta-label">
                            <svg style="width:0.7rem;height:0.7rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>
                            </svg>
                            Lama
                        </span>
                        <span class="hero-meta-value">{{ $user->created_at?->diffForHumans() ?? '-' }}</span>
                    </div>
                    <div class="hero-meta-item">
                        <span class="hero-meta-label">
                            <svg style="width:0.7rem;height:0.7rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"/>
                            </svg>
                            Diperbarui
                        </span>
                        <span class="hero-meta-value">{{ $user->updated_at?->translatedFormat('d M Y') ?? '-' }}</span>
                    </div>
                    <div class="hero-meta-item">
                        <span class="hero-meta-label">
                            <svg style="width:0.7rem;height:0.7rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"/>
                            </svg>
                            Foto
                        </span>
                        <span class="hero-meta-value" style="color:{{ $user->photo_path ? '#4ade80' : 'rgba(255,255,255,0.4)' }};">
                            {{ $user->photo_path ? '✓ Tersedia' : '— Belum' }}
                        </span>
                    </div>
                </div>

            </div>
        </div>

        {{-- ══ KANAN: FORM ══ --}}
        <div class="form-right-col">

            {{-- Edit Profil --}}
            <x-filament::section>
                <x-slot name="heading">
                    <div style="display:flex;align-items:center;gap:0.625rem;">
                        <div class="section-icon-wrap" style="background:rgba(59,130,246,0.1);">
                            <svg style="width:1rem;height:1rem;color:#3b82f6;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Z"/>
                            </svg>
                        </div>
                        <span>Edit Profil</span>
                    </div>
                </x-slot>
                <x-slot name="description">Perbarui nama, email, dan foto profil kamu.</x-slot>

                <form wire:submit.prevent="saveProfile" class="space-y-4">

                    {{-- Photo --}}
                    <div>
                        <label class="form-label">Foto Profil</label>
                        <div style="display:flex;align-items:center;gap:1rem;">
                            <div style="width:2.75rem;height:2.75rem;border-radius:50%;overflow:hidden;flex-shrink:0;box-shadow:0 0 0 2px rgba(59,130,246,0.25),0 2px 8px rgba(0,0,0,0.08);">
                                @if ($avatarUrl)
                                    <img src="{{ $avatarUrl }}" style="width:100%;height:100%;object-fit:cover;" />
                                @else
                                    <div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#60a5fa,#3b82f6);">
                                        <span style="font-size:0.8rem;font-weight:800;color:white;">{{ $initials }}</span>
                                    </div>
                                @endif
                            </div>
                            <div style="flex:1;">
                                <label class="upload-zone">
                                    <svg style="width:0.875rem;height:0.875rem;flex-shrink:0;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5"/>
                                    </svg>
                                    <span>{{ $photo ? $photo->getClientOriginalName() : 'Pilih foto baru…' }}</span>
                                    <input type="file" wire:model="photo" accept="image/*" class="sr-only" />
                                </label>
                                <p style="font-size:0.7rem;color:#9ca3af;margin-top:0.3rem;">JPG, PNG, GIF — maks. 2MB</p>
                                @error('photo') <p style="font-size:0.7rem;color:#ef4444;margin-top:0.25rem;">{{ $message }}</p> @enderror
                            </div>
                        </div>
                    </div>

                    {{-- Name & Email --}}
                    <div class="name-email-grid">
                        <div>
                            <label for="name" class="form-label">Nama Lengkap</label>
                            <div style="position:relative;">
                                <svg class="input-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"/>
                                </svg>
                                <input id="name" type="text" wire:model="name" class="form-input-custom" placeholder="Nama lengkap kamu" />
                            </div>
                            @error('name') <p style="font-size:0.7rem;color:#ef4444;margin-top:0.3rem;">{{ $message }}</p> @enderror
                        </div>
                        <div>
                            <label for="email" class="form-label">Alamat Email</label>
                            <div style="position:relative;">
                                <svg class="input-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"/>
                                </svg>
                                <input id="email" type="email" wire:model="email" class="form-input-custom" placeholder="email@kamu.com" />
                            </div>
                            @error('email') <p style="font-size:0.7rem;color:#ef4444;margin-top:0.3rem;">{{ $message }}</p> @enderror
                        </div>
                    </div>

                    <x-filament::button type="submit" class="w-full"
                        wire:loading.attr="disabled" wire:target="saveProfile,photo">
                        <span wire:loading.remove wire:target="saveProfile,photo" style="display:flex;align-items:center;justify-content:center;gap:0.4rem;">
                            <svg style="width:0.875rem;height:0.875rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z"/>
                            </svg>
                            Simpan Perubahan
                        </span>
                        <span wire:loading wire:target="saveProfile,photo">Menyimpan…</span>
                    </x-filament::button>

                </form>
            </x-filament::section>

            {{-- Ganti Password --}}
            <x-filament::section>
                <x-slot name="heading">
                    <div style="display:flex;align-items:center;gap:0.625rem;">
                        <div class="section-icon-wrap" style="background:rgba(245,158,11,0.1);">
                            <svg style="width:1rem;height:1rem;color:#f59e0b;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"/>
                            </svg>
                        </div>
                        <span>Ganti Password</span>
                    </div>
                </x-slot>
                <x-slot name="description">Pastikan password baru kamu kuat dan aman.</x-slot>

                <form wire:submit.prevent="savePassword" class="space-y-4">

                    <div class="pass-grid">
                        <div>
                            <label for="current_password" class="form-label">Password Saat Ini</label>
                            <div style="position:relative;">
                                <svg class="input-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 0 1 3 3m3 0a6 6 0 0 1-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 0 1 21.75 8.25Z"/>
                                </svg>
                                <input id="current_password" type="password" wire:model="current_password" class="form-input-custom" placeholder="••••••••" />
                            </div>
                            @error('current_password') <p style="font-size:0.7rem;color:#ef4444;margin-top:0.3rem;">{{ $message }}</p> @enderror
                        </div>
                        <div>
                            <label for="new_password" class="form-label">Password Baru</label>
                            <div style="position:relative;">
                                <svg class="input-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"/>
                                </svg>
                                <input id="new_password" type="password" wire:model="new_password" class="form-input-custom" placeholder="Min. 8 karakter" />
                            </div>
                            @error('new_password') <p style="font-size:0.7rem;color:#ef4444;margin-top:0.3rem;">{{ $message }}</p> @enderror
                        </div>
                        <div>
                            <label for="new_password_confirmation" class="form-label">Konfirmasi Password</label>
                            <div style="position:relative;">
                                <svg class="input-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>
                                </svg>
                                <input id="new_password_confirmation" type="password" wire:model="new_password_confirmation" class="form-input-custom" placeholder="Ulangi password baru" />
                            </div>
                            @error('new_password_confirmation') <p style="font-size:0.7rem;color:#ef4444;margin-top:0.3rem;">{{ $message }}</p> @enderror
                        </div>
                    </div>

                    <div class="warning-info-box">
                        <svg style="width:0.875rem;height:0.875rem;flex-shrink:0;margin-top:0.1rem;color:#d97706;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z"/>
                        </svg>
                        <p style="font-size:0.75rem;color:#92400e;line-height:1.5;" class="dark:!text-yellow-300">
                            Setelah mengganti password, kamu tetap login. Pastikan kamu mengingat password baru.
                        </p>
                    </div>

                    <x-filament::button type="submit" color="warning" class="w-full"
                        wire:loading.attr="disabled" wire:target="savePassword">
                        <span wire:loading.remove wire:target="savePassword" style="display:flex;align-items:center;justify-content:center;gap:0.4rem;">
                            <svg style="width:0.875rem;height:0.875rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"/>
                            </svg>
                            Ganti Password
                        </span>
                        <span wire:loading wire:target="savePassword">Menyimpan…</span>
                    </x-filament::button>

                </form>
            </x-filament::section>

        </div>
        {{-- ── END KANAN ── --}}

    </div>

</x-filament-panels::page>