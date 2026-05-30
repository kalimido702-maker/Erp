# CLAUDE.md — ERP Project Rules & Development Guide

> **READ THIS FIRST.** This is the single source of truth for anyone (human or AI)
> working on this project. It contains the architecture, the **non-negotiable rules**,
> and a step-by-step recipe for building any module. If something here conflicts with
> what you *think* is right, follow this file — or raise the conflict explicitly.

---

## 1. What this project is

A **large, cross-platform ERP system** built to be production-grade from the
foundation up. It is **offline-first**, **multi-tenant**, and **fully audited**.

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (mobile + desktop + web), Riverpod, GoRouter, Dio |
| **Backend** | Laravel 13, PHP 8.3 |
| **Auth** | Laravel Sanctum (bearer tokens) + Spatie Permission (roles/permissions) + TOTP 2FA |
| **Modules** | `nwidart/laravel-modules` (HR, Inventory, Finance, Accounting, Sales, Purchases, Settings) |
| **Realtime** | Laravel Reverb (WebSocket, Pusher protocol) |
| **DB** | MySQL 8 (prod), SQLite (tests) |
| **Cache/Queue** | Redis (prod), database (default) |
| **PDF** | `barryvdh/laravel-dompdf` (server) + `printing`/`pdf` (Flutter) |
| **Monitoring** | Telescope (dev), Sentry (prod) |
| **Docs** | Scribe (OpenAPI + Postman, served at `/docs`) |

**Why these choices:** left Electron for Flutter due to performance and printing.
The base must stay **extremely solid** — features are added *on top of* the
foundation, never by weakening it.

---

## 2. The 12 Non-Negotiable Rules

These are **hard constraints**. Breaking any of them is a bug, even if the code "works".

1. **Tenant isolation is sacred.** Every tenant-owned model MUST use the
   `BelongsToTenant` trait. Never write a raw query that bypasses `TenantScope`
   to read another company's data. `company_id` is assigned automatically — never
   trust a client-supplied `company_id`.

2. **Multi-step writes MUST be transactional.** Any operation touching more than
   one row/table (invoice + items + stock) must run inside a DB transaction
   (`HandlesTransactions` trait or `BaseService`). A half-completed write is a
   data-corruption bug in an accounting system.

3. **All API responses use the envelope.** Always return via the `ApiResponse`
   trait: `{ success, message, data }` or `{ success, message, errors }`.
   Never return a raw model/array.

4. **Validate every input.** Use `FormRequest` classes or `$request->validate()`.
   No controller may touch unvalidated request data.

5. **Authorize every action.** Sensitive actions go through a Policy
   (extend `BasePolicy`). Super-admin bypasses via the `before()` hook.

6. **Never weaken auth.** Don't disable Sanctum, don't loosen the rate limiters,
   don't expose secrets. 2FA secrets/recovery codes stay encrypted at rest.

7. **Tests are mandatory.** Every new endpoint gets a Feature test. Every bug fix
   gets a regression test. **The full suite must be green before you commit.**
   Run `php artisan test`.

8. **Audit-worthy models use the `Auditable` trait.** Create/update/delete must
   be traceable.

9. **No breaking changes to `v1`.** Additions are fine; renames/removals require a
   new version prefix (see §9). Mobile clients in the wild depend on v1.

10. **Offline-first on the client.** The Flutter app must remain usable offline:
    cached reads, queued writes, automatic sync. Never assume connectivity.
    Never log the user out on a network error — only on a real `401`.

11. **Secrets only in `.env`.** Never hardcode credentials, DSNs, or keys. Add new
    config to `.env.example` with safe defaults.

12. **Match the surrounding code.** Same naming, same structure, same comment
    density. Read neighboring files before writing new ones.

---

## 3. Repository layout

```
Erp/
├── CLAUDE.md                  ← you are here
├── docker-compose.yml         ← nginx, php, queue, scheduler, reverb, mysql, redis, phpmyadmin
├── docker/                    ← Dockerfiles + configs
├── tests/load/                ← k6 load tests
├── backend/                   ← Laravel 13
│   ├── app/
│   │   ├── Http/Controllers/Api/   ← shared (cross-module) controllers
│   │   ├── Http/Middleware/        ← SecurityHeaders, SetTenantFromAuth, SentryContext
│   │   ├── Http/Resources/         ← API resources (UserResource, …)
│   │   ├── Models/                 ← Company, User, AuditLog, Attachment
│   │   ├── Services/               ← BaseService, PdfService, TwoFactorService
│   │   ├── Policies/               ← BasePolicy
│   │   ├── Jobs/                   ← BaseJob, SendPdfEmailJob
│   │   ├── Scopes/TenantScope.php
│   │   ├── Support/TenantContext.php
│   │   ├── Traits/                 ← ApiResponse, BelongsToTenant, Auditable,
│   │   │                              HasAttachments, HandlesTransactions
│   │   └── Console/Commands/       ← BackupDatabase
│   ├── config/                     ← api.php, morph_map.php, cors.php, reverb.php, …
│   ├── database/migrations|seeders|factories
│   ├── routes/api.php              ← shared routes (everything under prefix v1)
│   ├── Modules/<Name>/             ← one folder per module (see §6)
│   └── tests/Feature/…             ← grouped by domain
└── frontend/                  ← Flutter
    └── lib/
        ├── core/              ← constants, network, offline, realtime, pdf, theme, routes
        ├── features/<name>/   ← clean architecture per feature (see §7)
        └── shared/            ← widgets, pages, models reused across features
```

---

## 4. Core building blocks (use these — don't reinvent)

### Backend traits & helpers

| Tool | Purpose | How to use |
|------|---------|-----------|
| `BelongsToTenant` | Auto company scoping + auto `company_id` on create | `use BelongsToTenant;` on the model |
| `Auditable` | Logs create/update/delete to `audit_logs` | `use Auditable;` on the model |
| `HasAttachments` | Polymorphic file attachments, zero config | `use HasAttachments;` + register alias in `config/morph_map.php` |
| `HandlesTransactions` | `$this->transaction(fn () => …)` | `use HandlesTransactions;` in controller/service |
| `ApiResponse` | `$this->success()/error()/paginated()` | `use ApiResponse;` in controller |
| `BaseService` | Transactional CRUD entry-point | `extends BaseService`, implement `modelClass()` |
| `BasePolicy` | Super-admin bypass + `sameCompany()`/`hasPermission()` | `extends BasePolicy` |
| `BaseJob` | 3 retries, backoff, failure logging | `extends BaseJob` |
| `TenantContext::companyId()` | Current tenant id (container OR auth user) | Read-only, anywhere |
| `PdfService` | `stream()/download()/base64()/bytes()` from a Blade view | inject in controller |

### `ApiResponse` shapes

```php
$this->success($data, 'msg', 200);          // { success:true, message, data }
$this->error('msg', 422, ['field'=>['x']]); // { success:false, message, errors }
$this->paginated($paginator);               // { success:true, data:[…], pagination:{…} }
```

### TenantContext — why it's dual-resolution
Route-model binding runs **before** route middleware. So `TenantContext` resolves
the company from the container binding **OR** falls back to `Auth::user()->company_id`,
closing the window where a `{model}` could be resolved cross-tenant. **Don't "simplify"
this** — it's a security fix.

---

## 5. Database conventions

- Every tenant table starts with:
  ```php
  $table->id();
  $table->foreignId('company_id')->nullable()->constrained('companies')->cascadeOnDelete();
  ```
- Money: `decimal(15, 2)`. Quantities: `decimal(15, 3)`.
- Add `$table->softDeletes();` to anything a user can "delete".
- Composite uniques are tenant-scoped: `$table->unique(['company_id', 'sku']);`
- Index the common filters: `$table->index(['company_id', 'is_active']);`
- Migration filenames: `YYYY_MM_DD_HHMMSS_verb_subject.php`.

---

## 6. How to build a BACKEND module (step by step)

> Example: adding a `Customer` entity to the **Sales** module.

**1. Scaffold (if the module doesn't exist):**
```bash
php artisan module:make Sales
```

**2. Migration** — `Modules/Sales/database/migrations/xxxx_create_customers_table.php`:
```php
Schema::create('customers', function (Blueprint $table) {
    $table->id();
    $table->foreignId('company_id')->nullable()->constrained('companies')->cascadeOnDelete();
    $table->string('name');
    $table->string('email')->nullable();
    $table->string('phone')->nullable();
    $table->boolean('is_active')->default(true);
    $table->timestamps();
    $table->softDeletes();
    $table->index(['company_id', 'is_active']);
});
```

**3. Model** — `Modules/Sales/app/Models/Customer.php`:
```php
class Customer extends Model
{
    use BelongsToTenant, Auditable, HasAttachments, SoftDeletes;

    protected $fillable = ['company_id', 'name', 'email', 'phone', 'is_active'];
    protected $casts = ['is_active' => 'boolean'];
}
```

**4. Policy** (if access needs restricting) — `app/Policies/CustomerPolicy.php` extending `BasePolicy`.

**5. Controller** — `Modules/Sales/app/Http/Controllers/CustomerController.php`:
- `use ApiResponse, HandlesTransactions;`
- Add `@group Sales` + Scribe docblocks (`@bodyParam`, `@response`).
- Validate via a private `rules()` method or a FormRequest.
- Wrap writes in `$this->transaction(...)`.
- Return through `$this->success()/paginated()`.

**6. Routes** — `Modules/Sales/routes/api.php`:
```php
Route::middleware(['auth:sanctum', 'tenant'])->prefix('v1')->group(function () {
    Route::apiResource('sales/customers', CustomerController::class);
});
```
> **Always** include both `auth:sanctum` and `tenant` middleware.

**7. Factory + Seeder** for tests and demo data (add realistic Arabic data to `DemoSeeder`).

**8. Tests** — `tests/Feature/Sales/CustomerCrudTest.php`:
- Create, update (assert it modifies, not duplicates), delete, validation, **cross-tenant isolation**.

**9. If the model needs attachments:** register it in `config/morph_map.php`:
```php
return ['products' => Product::class, 'customers' => Customer::class];
```

**10. Run `php artisan test` — must be green — then commit.**

---

## 7. How to build a FRONTEND feature (Flutter)

Each feature follows **clean architecture** under `lib/features/<name>/`:

```
features/customers/
├── data/
│   ├── datasources/customer_remote_datasource.dart  ← Dio calls, throws via handleDioError
│   ├── models/customer_model.dart                   ← JSON (@JsonSerializable) + toEntity()
│   └── repositories/customer_repository.dart        ← implements domain repo
├── domain/
│   ├── entities/customer_entity.dart                ← pure Dart, Equatable
│   ├── repositories/customer_repository.dart        ← abstract interface
│   └── usecases/                                     ← one class per action (optional for simple CRUD)
└── presentation/
    ├── pages/                                        ← screens
    ├── providers/                                    ← Riverpod (@riverpod codegen)
    └── widgets/                                       ← feature-local widgets
```

**Rules for the client:**
- All network goes through `ApiClient` (`apiClientProvider`) — never a bare `Dio()`.
  It already wires Auth + Offline + logging interceptors.
- Reads/writes that should work offline go through the offline layer
  (`OfflineInterceptor` + `SyncManager`) — don't bypass it.
- State via Riverpod with codegen (`@riverpod` / `@Riverpod(keepAlive: true)`).
- Persist auth: cache the user; on launch, only clear session on a real `401`.
- Endpoints live in `AppConstants`/`ApiEndpoints` — add new ones there.
- PDFs use `core/pdf/` builders + `PrintingService` (offline font fallback already handled).
- After editing codegen-annotated files, run:
  `dart run build_runner build --delete-conflicting-outputs`

---

## 8. Auth, roles & 2FA

- **Login:** `POST /v1/auth/login` → `{ token, user }`. Tokens expire in 30 days.
- **2FA (TOTP):** if a user has confirmed 2FA, login returns `422` with
  `errors.two_factor_required = [true]`; resend with `code` (TOTP or a single-use
  recovery code). Manage via `/v1/auth/2fa/{enable,confirm,disable}`.
- **Roles/permissions:** Spatie, guard `sanctum`. Seeded roles: `super-admin`,
  `admin`, `employee`. Check with `$user->hasRole(...)` / `hasPermissionTo(...)`
  or `role:`/`permission:` middleware.
- **Rate limits:** `login` = 5/min per email+IP; `api` = 90/min per user. Don't loosen.

---

## 9. API versioning

- Everything is under `/api/v1`. `config/api.php` holds the current version.
- **Non-breaking** (new endpoint, new field): add to v1.
- **Breaking** (rename/remove field, change behavior): create a **new** `prefix('v2')`
  group with new controllers; keep v1 until clients migrate. Never mutate v1 semantics.
- `/v1/health` reports `version` + `release`.

---

## 10. Errors, security & monitoring

- `ApiExceptionRenderer` converts ALL exceptions to the JSON envelope with correct
  status codes (422/401/403/404/405/429/500). Don't catch-and-swallow in controllers
  unless you have a specific reason.
- `SecurityHeaders` middleware is on every API response (incl. errors).
- **Telescope** (`/telescope`): dev inspector; restricted to local OR super-admin.
- **Sentry**: set `SENTRY_LARAVEL_DSN` in prod; `SentryContext` attaches the user.

---

## 11. Realtime (notifications)

- Server: Reverb broadcasts on private channels `company.{id}` and `user.{id}`.
- Events extend the broadcast pattern in `app/Events/ErpEvent.php`; notifications
  live in `app/Notifications/`.
- Client: `RealtimeService` does the Pusher handshake (`connection_established` →
  `/broadcasting/auth` → subscribe), with exponential-backoff reconnect.
- To push something new: create a Notification, broadcast to the company/user channel,
  ensure the Flutter `NotificationNotifier` handles the event type.

---

## 12. PDF & printing

- Server: put a Blade template in `resources/views/pdf/`, add it to the **allowlist**
  in `PdfController`, generate via `PdfService`. `POST /v1/pdf/generate` supports
  `stream | download | base64`.
- Client: build with `core/pdf/InvoiceBuilder` / `ReportBuilder`, render/print via
  `PrintingService` (handles Arabic font + offline fallback).
- Templates are **RTL Arabic**. Keep money/qty formatting consistent.

---

## 13. Background jobs, scheduling & backups

- Long/heavy work (PDF emails, bulk ops) → a Job extending `BaseJob`, dispatched
  to the queue. Never block an HTTP request on heavy work.
- Queue worker, scheduler, and Reverb run as their own `docker-compose` services.
- `php artisan backup:run` dumps the DB to `storage/app/backups` (scheduled daily 02:00,
  keeps last 7). Telescope entries pruned daily.

---

## 14. Commands you'll actually use

```bash
# Backend
php artisan test                         # run everything — MUST be green before commit
php artisan test tests/Feature/Sales/    # run one group
php artisan migrate                       # apply migrations
php artisan db:seed                       # base data (+ DemoSeeder, skipped in prod)
php artisan db:seed --class=DemoSeeder    # realistic demo data only
php artisan scribe:generate               # regenerate API docs
php artisan backup:run                    # manual DB backup
composer dev                              # serve + queue + logs + vite together

# Frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after editing codegen files
flutter analyze
flutter test test/unit/

# Load testing
k6 run -e BASE_URL=http://localhost:8000/api/v1 tests/load/api_load_test.js

# Docker (full stack)
docker compose up -d
```

---

## 15. Definition of Done (checklist for every change)

- [ ] Tenant isolation respected (new model uses `BelongsToTenant`).
- [ ] Multi-step writes wrapped in a transaction.
- [ ] Inputs validated; sensitive actions authorized via a Policy.
- [ ] Responses use the `ApiResponse` envelope.
- [ ] Auditable model uses the `Auditable` trait.
- [ ] Scribe docblocks added to new endpoints.
- [ ] Feature test(s) added; bug fixes have a regression test.
- [ ] `php artisan test` is **green**.
- [ ] Flutter: codegen run, `flutter analyze` clean, offline path considered.
- [ ] New config in `.env.example` with safe defaults; no secrets committed.
- [ ] No breaking change to `v1` (or a new version was introduced).
- [ ] Commit message is clear and descriptive.

---

## 16. Current foundation status (already built — don't rebuild)

Multi-tenancy · Audit trail · Realtime notifications · Offline-first sync ·
Auth + 2FA · Rate limiting · Security headers · Centralized error handling ·
File attachments · Health checks · PDF generation · Queues + scheduler ·
Demo seeders · Base Service/Policy/Job layers · API docs (Scribe) ·
Telescope + Sentry · DB transactions · CORS · DB backups · Load tests · CI/CD.

**The foundation is production-grade. Build modules ON it — never weaken it.**
