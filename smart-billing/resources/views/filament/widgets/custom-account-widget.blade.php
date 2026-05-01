<x-filament-widgets::widget class="fi-account-widget">
    <x-filament::section>
        <div style="display:flex;align-items:center;justify-content:space-between;gap:0.75rem;">

            {{-- Kiri: Avatar + Info --}}
            <div style="display:flex;align-items:center;gap:0.75rem;min-width:0;flex:1;">

                {{-- Avatar --}}
                <div style="position:relative;flex-shrink:0;">
                    <div style="width:2.75rem;height:2.75rem;border-radius:50%;overflow:hidden;box-shadow:0 0 0 2px rgba(59,130,246,0.3);">
                        <img
                            src="{{ auth()->user()->photo_path
                                    ? asset('storage/' . auth()->user()->photo_path)
                                    : asset('storage/avatars/default.jpg') }}"
                            alt="{{ auth()->user()->name }}"
                            style="width:100%;height:100%;object-fit:cover;"
                        />
                    </div>
                    <span style="position:absolute;bottom:1px;right:1px;width:0.6rem;height:0.6rem;border-radius:50%;background:#4ade80;border:1.5px solid white;"></span>
                </div>

                {{-- Info --}}
                <div style="min-width:0;">
                    <p style="font-size:0.875rem;font-weight:700;color:#111827;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;" class="dark:!text-white">
                        {{ auth()->user()->name }}
                    </p>
                    <p style="font-size:0.75rem;color:#6b7280;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;" class="dark:!text-gray-400">
                        {{ auth()->user()->email }}
                    </p>
                    <div style="margin-top:0.35rem;">
                        <span style="display:inline-flex;align-items:center;gap:0.3rem;padding:0.15rem 0.6rem;border-radius:9999px;font-size:0.65rem;font-weight:700;background:rgba(59,130,246,0.1);color:#2563eb;" class="dark:!bg-blue-900/30 dark:!text-blue-400">
                            <svg style="width:0.6rem;height:0.6rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"/>
                            </svg>
                            {{ ucfirst(str_replace('_', ' ', auth()->user()->user_role ?? 'User')) }}
                        </span>
                    </div>
                </div>

            </div>

            {{-- Kanan: Logout --}}
            <form action="{{ route('filament.admin.auth.logout') }}" method="POST" style="flex-shrink:0;">
                @csrf
                <button type="submit" title="Logout"
                    style="display:flex;align-items:center;justify-content:center;width:2rem;height:2rem;border-radius:0.5rem;border:none;background:rgba(239,68,68,0.08);color:#ef4444;cursor:pointer;transition:background 0.2s;"
                    onmouseover="this.style.background='rgba(239,68,68,0.15)'"
                    onmouseout="this.style.background='rgba(239,68,68,0.08)'"
                >
                    <svg style="width:0.9rem;height:0.9rem;" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15M12 9l-3 3m0 0 3 3m-3-3h12.75"/>
                    </svg>
                </button>
            </form>

        </div>
    </x-filament::section>
</x-filament-widgets::widget>