<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'         => $this->id,
            'name'       => $this->name,
            'email'      => $this->email,
            'phone'      => $this->phone,
            'avatar'     => $this->avatar ? asset('storage/'.$this->avatar) : null,
            'is_active'  => $this->is_active,
            'branch_id'  => $this->branch_id,
            'roles'      => $this->getRoleNames(),
            'permissions'=> $this->getAllPermissions()->pluck('name'),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
