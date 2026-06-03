<?php

namespace Tests\Unit;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Model;
use Tests\TestCase;

/** A throwaway model exercising the HasTranslations trait without a DB table. */
class _TranslatableStub extends Model
{
    use HasTranslations;

    protected $guarded = [];

    protected array $translatable = ['name'];
}

class HasTranslationsTest extends TestCase
{
    protected function tearDown(): void
    {
        app()->setLocale('ar');
        parent::tearDown();
    }

    public function test_resolves_value_for_current_locale(): void
    {
        $m = new _TranslatableStub();
        $m->setTranslation('name', 'ar', 'قميص')->setTranslation('name', 'en', 'Shirt');

        app()->setLocale('en');
        $this->assertSame('Shirt', $m->getTranslation('name'));

        app()->setLocale('ar');
        $this->assertSame('قميص', $m->getTranslation('name'));
    }

    public function test_falls_back_when_locale_missing(): void
    {
        config()->set('i18n.fallback', 'ar');
        $m = new _TranslatableStub();
        $m->setTranslation('name', 'ar', 'قميص');

        app()->setLocale('en'); // no English value → fall back to ar
        $this->assertSame('قميص', $m->getTranslation('name'));
    }

    public function test_to_array_exposes_localized_value_and_raw_map(): void
    {
        $m = new _TranslatableStub();
        $m->setTranslation('name', 'ar', 'قميص')->setTranslation('name', 'en', 'Shirt');

        app()->setLocale('en');
        $array = $m->toArray();

        $this->assertSame('Shirt', $array['name']);
        $this->assertSame(['ar' => 'قميص', 'en' => 'Shirt'], $array['name_i18n']);
    }
}
