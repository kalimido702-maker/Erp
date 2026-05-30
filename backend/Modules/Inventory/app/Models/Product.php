<?php

namespace Modules\Inventory\Models;

use App\Traits\Auditable;
use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use BelongsToTenant, Auditable, SoftDeletes;

    protected $fillable = [
        'company_id', 'name', 'sku', 'barcode', 'category',
        'unit', 'price', 'cost', 'stock_qty', 'min_stock', 'image', 'is_active',
    ];

    protected $casts = [
        'price'     => 'decimal:2',
        'cost'      => 'decimal:2',
        'stock_qty' => 'decimal:3',
        'min_stock' => 'decimal:3',
        'is_active' => 'boolean',
    ];
}
