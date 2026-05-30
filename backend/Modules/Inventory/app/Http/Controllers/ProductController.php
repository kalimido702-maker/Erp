<?php

namespace Modules\Inventory\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Traits\ApiResponse;
use App\Traits\HandlesTransactions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Modules\Inventory\Models\Product;

/**
 * @group Inventory
 *
 * Product catalogue management — tenant-scoped, audited, soft-deletable.
 */
class ProductController extends Controller
{
    use ApiResponse, HandlesTransactions;

    /**
     * List products
     *
     * @queryParam search string optional Match name, SKU or barcode. Example: laptop
     * @queryParam category string optional Filter by category. Example: إلكترونيات
     * @queryParam low_stock boolean optional Only products at or below min stock. Example: true
     * @queryParam per_page integer optional Results per page (default 20). Example: 15
     */
    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Product::class);

        $query = Product::query()
            ->when($request->filled('search'), fn ($q) =>
                $q->where(function ($sub) use ($request) {
                    $sub->where('name', 'like', '%' . $request->search . '%')
                        ->orWhere('sku', 'like', '%' . $request->search . '%')
                        ->orWhere('barcode', 'like', '%' . $request->search . '%');
                })
            )
            ->when($request->filled('category'), fn ($q) =>
                $q->where('category', $request->category)
            )
            ->when($request->boolean('low_stock'), fn ($q) =>
                $q->whereColumn('stock_qty', '<=', 'min_stock')
            )
            ->latest();

        return $this->paginated($query->paginate($request->integer('per_page', 20)));
    }

    /**
     * Create product
     *
     * @bodyParam name string required Product name. Example: لاب توب Dell
     * @bodyParam sku string required Unique stock-keeping unit (per company). Example: DELL-5540
     * @bodyParam price number required Selling price. Example: 4500
     * @bodyParam cost number optional Purchase cost. Example: 3800
     * @bodyParam stock_qty number optional Initial stock quantity. Example: 25
     * @bodyParam min_stock number optional Low-stock threshold. Example: 5
     */
    public function store(Request $request): JsonResponse
    {
        $this->authorize('create', Product::class);

        $validated = $request->validate($this->rules());

        $product = $this->transaction(fn () => Product::create($validated));

        return $this->success($product, 'تم إنشاء المنتج', 201);
    }

    /**
     * Show product
     *
     * @urlParam product integer required Product ID. Example: 1
     */
    public function show(Product $product): JsonResponse
    {
        $this->authorize('view', $product);

        return $this->success($product);
    }

    /**
     * Update product
     *
     * @urlParam product integer required Product ID. Example: 1
     */
    public function update(Request $request, Product $product): JsonResponse
    {
        $this->authorize('update', $product);

        $validated = $request->validate($this->rules($product->id, partial: true));

        $product = $this->transaction(function () use ($product, $validated) {
            $product->update($validated);
            return $product->fresh();
        });

        return $this->success($product, 'تم تحديث المنتج');
    }

    /**
     * Delete product
     *
     * Soft-deletes the product (recoverable). Attachments are cascaded.
     *
     * @urlParam product integer required Product ID. Example: 1
     */
    public function destroy(Product $product): JsonResponse
    {
        $this->authorize('delete', $product);

        $this->transaction(fn () => $product->delete());

        return $this->success(null, 'تم حذف المنتج');
    }

    /**
     * Validation rules. SKU uniqueness is scoped to the current tenant.
     */
    private function rules(?int $ignoreId = null, bool $partial = false): array
    {
        $skuUnique = Rule::unique('products')
            ->where(fn ($q) => $q->where('company_id', app('tenant.company_id')));

        if ($ignoreId !== null) {
            $skuUnique->ignore($ignoreId);
        }

        $req = $partial ? 'sometimes' : 'required';

        return [
            'name'      => "$req|string|max:255",
            // SKU is optional, but when present it must be unique within the tenant.
            'sku'       => ['nullable', 'string', 'max:100', $skuUnique],
            'barcode'   => 'nullable|string|max:100',
            'category'  => 'nullable|string|max:100',
            'unit'      => 'nullable|string|max:50',
            'price'     => "$req|numeric|min:0",
            'cost'      => 'nullable|numeric|min:0',
            'stock_qty' => 'nullable|numeric|min:0',
            'min_stock' => 'nullable|numeric|min:0',
            'is_active' => 'boolean',
        ];
    }
}
