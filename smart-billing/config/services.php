<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'midtrans' => [
 
        // Server Key dari dashboard Midtrans
        // Sandbox : https://dashboard.sandbox.midtrans.com/settings/config_info
        // Prod    : https://dashboard.midtrans.com/settings/config_info
        'server_key' => env('MIDTRANS_SERVER_KEY'),
 
        // Client Key (untuk dipakai Flutter jika perlu)
        'client_key' => env('MIDTRANS_CLIENT_KEY'),
 
        // true  = Sandbox (testing)
        // false = Production
        'is_sandbox'  => env('MIDTRANS_IS_SANDBOX', true),
 
        // Nominal DP default jika reservasi tanpa paket (dalam rupiah)
        'default_dp'  => env('MIDTRANS_DEFAULT_DP', 50000),
    ],

];
