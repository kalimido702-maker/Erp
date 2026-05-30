@extends('pdf.layout', ['title' => $report['title'] ?? 'تقرير'])

@section('content')

{{-- ── Header ── --}}
<div class="header">
  <div>
    <div class="company-name">{{ $company['name'] ?? 'الشركة' }}</div>
    @if(!empty($company['address']))
      <div class="company-sub">{{ $company['address'] }}</div>
    @endif
  </div>
  <div>
    <div class="doc-badge">{{ $report['title'] ?? 'تقرير' }}</div>
    @if(!empty($report['period']))
      <div class="doc-badge-sub">{{ $report['period'] }}</div>
    @endif
  </div>
</div>
<hr class="divider"/>

{{-- ── Summary Cards ── --}}
@if(!empty($report['summary']))
  <div style="display:flex; gap:10px; margin-bottom:14px;">
    @foreach($report['summary'] as $card)
      <div style="flex:1; background:#f5f6fa; border-radius:4px; padding:8px 12px; border-top:3px solid #16213e;">
        <div style="font-size:9px; color:#888;">{{ $card['label'] }}</div>
        <div style="font-size:16px; font-weight:bold; color:#16213e;">{{ $card['value'] }}</div>
      </div>
    @endforeach
  </div>
@endif

{{-- ── Data Table ── --}}
@if(!empty($report['columns']) && !empty($report['rows']))
  <table>
    <thead>
      <tr>
        @foreach($report['columns'] as $col)
          <th>{{ $col }}</th>
        @endforeach
      </tr>
    </thead>
    <tbody>
      @foreach($report['rows'] as $row)
        <tr>
          @foreach($row as $cell)
            <td>{{ $cell }}</td>
          @endforeach
        </tr>
      @endforeach
    </tbody>
  </table>
@endif

{{-- ── Notes ── --}}
@if(!empty($report['notes']))
  <div style="margin-top:14px; font-size:10px; color:#555; border-top:1px solid #eee; padding-top:8px;">
    {{ $report['notes'] }}
  </div>
@endif

@endsection
