<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<title>{{ $title ?? 'مستند ERP' }}</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'DejaVu Sans', sans-serif;
    font-size: 11px;
    color: #1a1a2e;
    background: #fff;
    direction: rtl;
    line-height: 1.5;
  }
  .page { padding: 20mm 15mm; }

  /* ── Header ── */
  .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; }
  .company-name { font-size: 18px; font-weight: bold; color: #16213e; }
  .company-sub  { font-size: 10px; color: #666; margin-top: 2px; }
  .doc-badge {
    background: #16213e; color: #fff;
    padding: 6px 16px; border-radius: 4px;
    font-size: 14px; font-weight: bold; text-align: center;
  }
  .doc-badge-sub { font-size: 10px; color: #aaa; text-align: center; margin-top: 3px; }

  .divider { border: none; border-top: 2px solid #16213e; margin: 10px 0; }
  .divider-thin { border: none; border-top: 1px solid #ddd; margin: 8px 0; }

  /* ── Metadata grid ── */
  .meta-grid { display: flex; justify-content: space-between; margin-bottom: 14px; font-size: 10px; }
  .meta-block { min-width: 45%; }
  .meta-label { color: #888; margin-bottom: 1px; }
  .meta-value { font-weight: bold; }

  /* ── Table ── */
  table { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 10px; }
  thead tr { background: #16213e; color: #fff; }
  thead th { padding: 7px 10px; text-align: center; font-weight: bold; }
  tbody tr:nth-child(even) { background: #f5f6fa; }
  tbody td { padding: 6px 10px; text-align: center; border-bottom: 1px solid #eee; }

  /* ── Totals ── */
  .totals { float: left; min-width: 220px; margin-top: 6px; }
  .totals table { font-size: 10px; }
  .totals td { padding: 4px 10px; }
  .totals .total-row td { font-size: 12px; font-weight: bold; background: #16213e; color: #fff; }

  /* ── Footer ── */
  .footer { margin-top: 30px; font-size: 9px; color: #999; text-align: center; border-top: 1px solid #eee; padding-top: 6px; }

  /* ── Status badge ── */
  .badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 9px; font-weight: bold; }
  .badge-success { background: #d4edda; color: #155724; }
  .badge-warning { background: #fff3cd; color: #856404; }
  .badge-danger  { background: #f8d7da; color: #721c24; }
  .badge-info    { background: #d1ecf1; color: #0c5460; }
</style>
</head>
<body>
<div class="page">
  @yield('content')
  <div class="footer">
    {{ config('app.name', 'ERP System') }} &bull; تم إنشاء هذا المستند بتاريخ {{ now()->format('Y-m-d H:i') }}
  </div>
</div>
</body>
</html>
