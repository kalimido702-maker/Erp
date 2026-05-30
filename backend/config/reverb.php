<?php

return [
    'servers' => [
        'reverb' => [
            'host'    => env('REVERB_HOST', '0.0.0.0'),
            'port'    => env('REVERB_PORT', 8080),
            'scheme'  => env('REVERB_SCHEME', 'http'),
            'options' => [
                'tls' => [],
            ],
        ],
    ],

    'apps' => [
        'provider' => 'config',
        'apps' => [
            [
                'key'              => env('REVERB_APP_KEY', 'local'),
                'secret'           => env('REVERB_APP_SECRET', 'secret'),
                'app_id'           => env('REVERB_APP_ID', '1'),
                'options'          => [
                    'host'     => env('REVERB_HOST', 'localhost'),
                    'port'     => env('REVERB_PORT', 8080),
                    'scheme'   => env('REVERB_SCHEME', 'http'),
                    'useTLS'   => env('REVERB_SCHEME', 'http') === 'https',
                ],
                'allowed_origins'  => ['*'],
                'ping_interval'    => env('REVERB_PING_INTERVAL', 60),
                'ping_timeout'     => env('REVERB_PING_TIMEOUT', 10),
                'max_message_size' => env('REVERB_MAX_MESSAGE_SIZE', 10_000),
            ],
        ],
    ],
];
