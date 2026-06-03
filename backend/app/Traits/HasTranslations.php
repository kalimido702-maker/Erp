<?php

namespace App\Traits;

/**
 * Makes selected model columns translatable. Each such column stores a JSON map
 * of `{ "ar": "...", "en": "..." }` and is resolved to the current app locale
 * (see SetLocale middleware) when the model is serialized to an API response.
 *
 * Usage:
 *   class Product extends Model {
 *       use HasTranslations;
 *       protected array $translatable = ['name', 'description'];
 *   }
 *   // migration: $table->json('name'); $table->json('description')->nullable();
 *
 * API output keeps the localized string under the original key AND exposes the
 * raw map under `{field}_i18n` so edit forms can show every language.
 */
trait HasTranslations
{
    /** Auto-invoked by Eloquent for each trait on boot — registers JSON casts. */
    public function initializeHasTranslations(): void
    {
        $this->mergeCasts(
            array_fill_keys($this->translatableAttributes(), 'array')
        );
    }

    /** @return array<int, string> */
    public function translatableAttributes(): array
    {
        return property_exists($this, 'translatable') ? $this->translatable : [];
    }

    /**
     * Resolve one translatable field to [locale] (defaults to current app
     * locale), falling back to the platform locale, then any available value.
     */
    public function getTranslation(string $field, ?string $locale = null): ?string
    {
        $locale ??= app()->getLocale();
        $values = $this->getAttribute($field);

        if (! is_array($values)) {
            return is_string($values) ? $values : null;
        }

        $fallback = config('i18n.fallback', 'ar');

        return $values[$locale]
            ?? $values[$fallback]
            ?? (! empty($values) ? reset($values) : null);
    }

    /** Set one language's value for a translatable field (chainable). */
    public function setTranslation(string $field, string $locale, string $value): static
    {
        $values = $this->getAttribute($field);
        $values = is_array($values) ? $values : [];
        $values[$locale] = $value;
        $this->setAttribute($field, $values);

        return $this;
    }

    public function toArray(): array
    {
        $array = parent::toArray();

        foreach ($this->translatableAttributes() as $field) {
            if (array_key_exists($field, $array)) {
                $array["{$field}_i18n"] = is_array($array[$field]) ? $array[$field] : [];
                $array[$field] = $this->getTranslation($field);
            }
        }

        return $array;
    }
}
