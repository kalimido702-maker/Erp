import 'package:go_router/go_router.dart';

abstract class AppRoutes {
  static const String login     = '/login';
  static const String dashboard = '/';

  // HR Module
  static const String employees   = '/hr/employees';
  static const String departments = '/hr/departments';
  static const String payroll     = '/hr/payroll';
  static const String attendance  = '/hr/attendance';

  // Inventory Module
  static const String products      = '/inventory/products';
  static const String categories    = '/inventory/categories';
  static const String warehouses    = '/inventory/warehouses';
  static const String stockMovements = '/inventory/movements';

  // Sales Module
  static const String salesOrders = '/sales/orders';
  static const String customers   = '/sales/customers';
  static const String invoices    = '/sales/invoices';

  // Purchases Module
  static const String purchaseOrders = '/purchases/orders';
  static const String suppliers      = '/purchases/suppliers';

  // Finance Module
  static const String accounts     = '/finance/accounts';
  static const String transactions = '/finance/transactions';
  static const String reports      = '/finance/reports';

  // Settings
  static const String settings = '/settings';

  // Module routes (registered in router)
  static List<RouteBase> get moduleRoutes => [];
}
