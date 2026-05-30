@extends('pdf.layout', ['title' => 'فاتورة رقم ' . ($invoice['number'] ?? '')])

@section('content')

{{-- ── Header ─────────────────────────────────────────────────────────── --}}
<div class="header">
  <div>
    <div class="company-name">{{ $company['name'] ?? 'الشركة' }}</div>
    @if(!empty($company['address']))
      <div class="company-sub">{{ $company['address'] }}</div>
    @endif
    @if(!empty($company['phone']))
      <div class="company-sub">هاتف: {{ $company['phone'] }}</div>
    @endif
    @if(!empty($company['tax_number']))
      <div class="company-sub">الرقم الضريبي: {{ $company['tax_number'] }}</div>
    @endif
  </div>
  <div>
    <div class="doc-badge">فاتورة</div>
    <div class="doc-badge-sub"># {{ $invoice['number'] ?? '—' }}</div>
  </div>
</div>
<hr class="divider"/>

{{-- ── Meta info ────────────────────────────────────────────────────── --}}
<div class="meta-grid">
  <div class="meta-block">
    <div class="meta-label">العميل</div>
    <div class="meta-value">{{ $customer['name'] ?? '—' }}</div>
    @if(!empty($customer['address']))
      <div>{{ $customer['address'] }}</div>
    @endif
    @if(!empty($customer['phone']))
      <div>هاتف: {{ $customer['phone'] }}</div>
    @endif
  </div>
  <div class="meta-block" style="text-align:left;">
    <div>
      <span class="meta-label">تاريخ الإصدار: </span>
      <span class="meta-value">{{ $invoice['date'] ?? now()->format('Y-m-d') }}</span>
    </div>
    @if(!empty($invoice['due_date']))
      <div>
        <span class="meta-label">تاريخ الاستحقاق: </span>
        <span class="meta-value">{{ $invoice['due_date'] }}</span>
      </div>
    @endif
    <div style="margin-top:4px;">
      @php
        $statusMap = ['paid' => ['label'=>'مدفوعة','class'=>'badge-success'], 'pending'=>['label'=>'معلقة','class'=>'badge-warning'], 'overdue'=>['label'=>'متأخرة','class'=>'badge-danger']];
        $s = $statusMap[$invoice['status'] ?? 'pending'] ?? ['label'=>$invoice['status'] ?? '', 'class'=>'badge-info'];
      @endphp
      <span class="badge {{ $s['class'] }}">{{ $s['label'] }}</span>
    </div>
  </div>
</div>

{{-- ── Items ────────────────────────────────────────────────────────── --}}
<table>
  <thead>
    <tr>
      <th>#</th>
      <th>الصنف / الوصف</th>
      <th>الكمية</th>
      <th>سعر الوحدة</th>
      <th>الخصم</th>
      <th>الإجمالي</th>
    </tr>
  </thead>
  <tbody>
    @foreach(($invoice['items'] ?? []) as $i => $item)
      <tr>
        <td>{{ $i + 1 }}</td>
        <td style="text-align:right;">
          {{ $item['name'] ?? '' }}
          @if(!empty($item['description']))
            <br/><span style="color:#888;font-size:9px;">{{ $item['description'] }}</span>
          @endif
        </td>
        <td>{{ number_format($item['qty'] ?? 0, 2) }}</td>
        <td>{{ number_format($item['unit_price'] ?? 0, 2) }} {{ $currency ?? 'SAR' }}</td>
        <td>{{ number_format($item['discount'] ?? 0, 2) }} {{ $currency ?? 'SAR' }}</td>
        <td>{{ number_format($item['total'] ?? 0, 2) }} {{ $currency ?? 'SAR' }}</td>
      </tr>
    @endforeach
  </tbody>
</table>

{{-- ── Totals ───────────────────────────────────────────────────────── --}}
<div style="overflow:hidden;">
  @if(!empty($invoice['notes']))
    <div style="float:right; max-width:55%; font-size:10px; color:#555;">
      <strong>ملاحظات:</strong><br/>{{ $invoice['notes'] }}
    </div>
  @endif
  <div class="totals">
    <table>
      <tr>
        <td>المجموع الفرعي</td>
        <td style="text-align:left;">{{ number_format($invoice['subtotal'] ?? 0, 2) }} {{ $currency ?? 'SAR' }}</td>
      </tr>
      @if(isset($invoice['discount_total']) && $invoice['discount_total'] > 0)
        <tr>
          <td>الخصم الإجمالي</td>
          <td style="text-align:left;">- {{ number_format($invoice['discount_total'], 2) }} {{ $currency ?? 'SAR' }}</td>
        </tr>
      @endif
      @if(isset($invoice['tax_rate']) && $invoice['tax_rate'] > 0)
        <tr>
          <td>ضريبة القيمة المضافة ({{ $invoice['tax_rate'] }}%)</td>
          <td style="text-align:left;">{{ number_format($invoice['tax_amount'] ?? 0, 2) }} {{ $currency ?? 'SAR' }}</td>
        </tr>
      @endif
      <tr class="total-row">
        <td>الإجمالي</td>
        <td style="text-align:left;">{{ number_format($invoice['total'] ?? 0, 2) }} {{ $currency ?? 'SAR' }}</td>
      </tr>
    </table>
  </div>
  <div style="clear:both;"></div>
</div>

@endsection
