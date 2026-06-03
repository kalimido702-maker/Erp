<?php

namespace App\Models;

use App\Traits\Auditable;
use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A tenant-scoped UI string override. See the translations migration.
 */
class Translation extends Model
{
    use Auditable;
    use BelongsToTenant;
    use HasFactory;

    protected $fillable = ['company_id', 'locale', 'key', 'value'];
}
