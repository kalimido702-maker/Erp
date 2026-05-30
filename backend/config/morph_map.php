<?php

use Modules\Inventory\Models\Product;

/*
|--------------------------------------------------------------------------
| Polymorphic Morph Map
|--------------------------------------------------------------------------
|
| Maps short, stable aliases to model classes for polymorphic relations
| (attachments, audit logs, …). Using aliases instead of raw class names
| keeps the API stable and avoids leaking internal namespaces. Each new
| module that needs attachments simply registers its models here.
|
*/

return [
    'products' => Product::class,
];
