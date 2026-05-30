<?php

namespace Modules\Inventory\Policies;

use App\Models\User;
use App\Policies\BasePolicy;
use Modules\Inventory\Models\Product;

/**
 * Authorization for the Product resource.
 *
 * Super-admins bypass everything via BasePolicy::before(). For everyone else
 * the action is allowed only when (a) the user holds the matching permission
 * AND (b) the record belongs to the user's own company (defence in depth on
 * top of TenantScope).
 */
class ProductPolicy extends BasePolicy
{
    public function viewAny(User $user): bool
    {
        return $this->hasPermission($user, 'products.view');
    }

    public function view(User $user, Product $product): bool
    {
        return $this->hasPermission($user, 'products.view')
            && $this->sameCompany($user, $product);
    }

    public function create(User $user): bool
    {
        return $this->hasPermission($user, 'products.create');
    }

    public function update(User $user, Product $product): bool
    {
        return $this->hasPermission($user, 'products.edit')
            && $this->sameCompany($user, $product);
    }

    public function delete(User $user, Product $product): bool
    {
        return $this->hasPermission($user, 'products.delete')
            && $this->sameCompany($user, $product);
    }
}
