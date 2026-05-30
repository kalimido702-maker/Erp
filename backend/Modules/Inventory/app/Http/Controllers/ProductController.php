<?php

namespace Modules\Inventory\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Modules\Inventory\Models\Product;

class ProductController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $products = Product::query()
            ->when($request->filled('search'), fn ($q) =>
                $q->where('name', 'like', "%{$request->search}%")
                  ->orWhere('sku', 'like', "%{$request->search}%")
            )
            ->when($request->filled('category'), fn ($q) =>
                $q->where('category', $request->category)
            )
            ->when($request->boolean('low_stock'), fn ($q) =>
                $q->whereColumn('stock_qty', '<=', 'min_stock')
            )
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return $this->paginated($products);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'      => 'required|string|max:255',
            'sku'       => 'nullable|string|max:100',
            'barcode'   => 'nullable|string|max:100',
            'category'  => 'nullable|string|max:100',
            'unit'      => 'nullable|string|max:50',
            'price'     => 'required|numeric|min:0',
            'cost'      => 'nullable|numeric|min:0',
            'min_stock' => 'nullable|numeric|min:0',
        ]);

        $product = Product::create($validated);
        return $this->success($product, 'Created', 201);
    }

    public function show(Product $product): JsonResponse
    {
        return $this->success($product);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $validated = $request->validate([
            'name'      => 'sometimes|string|max:255',
            'sku'       => 'sometimes|nullable|string|max:100',
            'price'     => 'sometimes|numeric|min:0',
            'cost'      => 'sometimes|nullable|numeric|min:0',
            'category'  => 'sometimes|nullable|string|max:100',
            'min_stock' => 'sometimes|nullable|numeric|min:0',
            'is_active' => 'sometimes|boolean',
        ]);

        $product->update($validated);
        return $this->success($product);
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();
        return $this->success(null);
    }
}
