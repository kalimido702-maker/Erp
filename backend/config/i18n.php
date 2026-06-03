<?php

return [
    /*
    | The platform's fallback language — used when a tenant/device asks for a
    | language we don't have strings for.
    */
    'fallback' => env('I18N_FALLBACK', 'ar'),

    /*
    | Default set of languages offered to a new tenant (until they customize
    | their supported_locales).
    */
    'default_locales' => ['ar', 'en'],

    /*
    | Every locale the platform ships base translation files for. A tenant can
    | only enable locales from this list.
    */
    'available_locales' => ['ar', 'en'],

    /*
    | Where the authoritative base UI strings live (JSON per locale).
    */
    'base_path' => lang_path('i18n'),
];
