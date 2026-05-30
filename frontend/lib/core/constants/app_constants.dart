abstract class AppConstants {
  static const String appName = 'ERP System';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String localeKey = 'app_locale';
}

abstract class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String twoFactorEnable = '/auth/2fa/enable';
  static const String twoFactorConfirm = '/auth/2fa/confirm';
  static const String twoFactorDisable = '/auth/2fa/disable';

  // Settings
  static const String settings = '/settings';

  // HR
  static const String employees = '/hr/employees';
  static const String departments = '/hr/departments';
  static const String positions = '/hr/positions';
  static const String attendance = '/hr/attendance';
  static const String payroll = '/hr/payroll';

  // Inventory
  static const String products = '/inventory/products';
  static const String categories = '/inventory/categories';
  static const String warehouses = '/inventory/warehouses';
  static const String stockMovements = '/inventory/movements';

  // Sales
  static const String salesOrders = '/sales/orders';
  static const String customers = '/sales/customers';
  static const String invoices = '/sales/invoices';

  // Purchases
  static const String purchaseOrders = '/purchases/orders';
  static const String suppliers = '/purchases/suppliers';

  // Finance
  static const String accounts = '/finance/accounts';
  static const String transactions = '/finance/transactions';
  static const String reports = '/finance/reports';
}
