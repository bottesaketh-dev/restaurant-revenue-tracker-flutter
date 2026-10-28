import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'restaurant_provider.dart';

class AppSettings {
  // Printer & Hardware
  final String printerName;
  final String paperWidth; // '80mm' or '58mm'
  final bool autoCut;
  final bool printCustomerCopy;
  final bool printMerchantCopy;

  // POS Workflow Rules
  final bool autoPrintOnSettle;
  final bool autoReleaseTable;
  final bool requirePhoneForTakeaway;
  final String defaultPaymentMethod; // 'UPI', 'CASH', 'CARD'
  final bool enableKitchenTickets;

  // UI & Terminals
  final bool isDarkMode;
  final bool enableSoundAlerts;
  final bool compactView;

  const AppSettings({
    this.printerName = 'Retsol_POS_80',
    this.paperWidth = '80mm',
    this.autoCut = true,
    this.printCustomerCopy = true,
    this.printMerchantCopy = false,
    this.autoPrintOnSettle = true,
    this.autoReleaseTable = true,
    this.requirePhoneForTakeaway = true,
    this.defaultPaymentMethod = 'UPI',
    this.enableKitchenTickets = true,
    this.isDarkMode = false,
    this.enableSoundAlerts = true,
    this.compactView = false,
  });

  AppSettings copyWith({
    String? printerName,
    String? paperWidth,
    bool? autoCut,
    bool? printCustomerCopy,
    bool? printMerchantCopy,
    bool? autoPrintOnSettle,
    bool? autoReleaseTable,
    bool? requirePhoneForTakeaway,
    String? defaultPaymentMethod,
    bool? enableKitchenTickets,
    bool? isDarkMode,
    bool? enableSoundAlerts,
    bool? compactView,
  }) {
    return AppSettings(
      printerName: printerName ?? this.printerName,
      paperWidth: paperWidth ?? this.paperWidth,
      autoCut: autoCut ?? this.autoCut,
      printCustomerCopy: printCustomerCopy ?? this.printCustomerCopy,
      printMerchantCopy: printMerchantCopy ?? this.printMerchantCopy,
      autoPrintOnSettle: autoPrintOnSettle ?? this.autoPrintOnSettle,
      autoReleaseTable: autoReleaseTable ?? this.autoReleaseTable,
      requirePhoneForTakeaway: requirePhoneForTakeaway ?? this.requirePhoneForTakeaway,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
      enableKitchenTickets: enableKitchenTickets ?? this.enableKitchenTickets,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      enableSoundAlerts: enableSoundAlerts ?? this.enableSoundAlerts,
      compactView: compactView ?? this.compactView,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final dio = ref.watch(dioProvider);
  return SettingsNotifier(dio, ref);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Dio _dio;
  final Ref _ref;

  SettingsNotifier(this._dio, this._ref) : super(const AppSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        printerName: prefs.getString('settings_printer_name') ?? 'Retsol_POS_80',
        paperWidth: prefs.getString('settings_paper_width') ?? '80mm',
        autoCut: prefs.getBool('settings_auto_cut') ?? true,
        printCustomerCopy: prefs.getBool('settings_print_customer_copy') ?? true,
        printMerchantCopy: prefs.getBool('settings_print_merchant_copy') ?? false,
        autoPrintOnSettle: prefs.getBool('settings_auto_print_settle') ?? true,
        autoReleaseTable: prefs.getBool('settings_auto_release_table') ?? true,
        requirePhoneForTakeaway: prefs.getBool('settings_require_phone_takeaway') ?? true,
        defaultPaymentMethod: prefs.getString('settings_default_payment') ?? 'UPI',
        enableKitchenTickets: prefs.getBool('settings_enable_kot') ?? true,
        isDarkMode: prefs.getBool('settings_dark_mode') ?? false,
        enableSoundAlerts: prefs.getBool('settings_sound_alerts') ?? true,
        compactView: prefs.getBool('settings_compact_view') ?? false,
      );
    } catch (_) {
      // Fall back gracefully to defaults
    }
  }

  Future<void> updatePrinterSettings({
    String? printerName,
    String? paperWidth,
    bool? autoCut,
    bool? printCustomerCopy,
    bool? printMerchantCopy,
  }) async {
    state = state.copyWith(
      printerName: printerName,
      paperWidth: paperWidth,
      autoCut: autoCut,
      printCustomerCopy: printCustomerCopy,
      printMerchantCopy: printMerchantCopy,
    );
    final prefs = await SharedPreferences.getInstance();
    if (printerName != null) await prefs.setString('settings_printer_name', printerName);
    if (paperWidth != null) await prefs.setString('settings_paper_width', paperWidth);
    if (autoCut != null) await prefs.setBool('settings_auto_cut', autoCut);
    if (printCustomerCopy != null) await prefs.setBool('settings_print_customer_copy', printCustomerCopy);
    if (printMerchantCopy != null) await prefs.setBool('settings_print_merchant_copy', printMerchantCopy);
  }

  Future<void> updatePosWorkflow({
    bool? autoPrintOnSettle,
    bool? autoReleaseTable,
    bool? requirePhoneForTakeaway,
    String? defaultPaymentMethod,
    bool? enableKitchenTickets,
  }) async {
    state = state.copyWith(
      autoPrintOnSettle: autoPrintOnSettle,
      autoReleaseTable: autoReleaseTable,
      requirePhoneForTakeaway: requirePhoneForTakeaway,
      defaultPaymentMethod: defaultPaymentMethod,
      enableKitchenTickets: enableKitchenTickets,
    );
    final prefs = await SharedPreferences.getInstance();
    if (autoPrintOnSettle != null) await prefs.setBool('settings_auto_print_settle', autoPrintOnSettle);
    if (autoReleaseTable != null) await prefs.setBool('settings_auto_release_table', autoReleaseTable);
    if (requirePhoneForTakeaway != null) await prefs.setBool('settings_require_phone_takeaway', requirePhoneForTakeaway);
    if (defaultPaymentMethod != null) await prefs.setString('settings_default_payment', defaultPaymentMethod);
    if (enableKitchenTickets != null) await prefs.setBool('settings_enable_kot', enableKitchenTickets);
  }

  Future<void> updateUiPreferences({
    bool? isDarkMode,
    bool? enableSoundAlerts,
    bool? compactView,
  }) async {
    state = state.copyWith(
      isDarkMode: isDarkMode,
      enableSoundAlerts: enableSoundAlerts,
      compactView: compactView,
    );
    final prefs = await SharedPreferences.getInstance();
    if (isDarkMode != null) await prefs.setBool('settings_dark_mode', isDarkMode);
    if (enableSoundAlerts != null) await prefs.setBool('settings_sound_alerts', enableSoundAlerts);
    if (compactView != null) await prefs.setBool('settings_compact_view', compactView);
  }

  Future<Map<String, dynamic>> testThermalPrinter([String? customPrinterName]) async {
    final nameToUse = customPrinterName ?? state.printerName;
    try {
      final response = await _dio.post('/billing/printer/test', data: {'printer_name': nameToUse});
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to connect to printer bridge: $e',
      };
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      final detail = e.response?.data['detail'] ?? 'Password update failed';
      throw Exception(detail);
    } catch (e) {
      throw Exception('Password update failed: $e');
    }
  }

  Future<Map<String, dynamic>> pingHealth() async {
    final start = DateTime.now();
    try {
      final response = await _dio.get('/health');
      final duration = DateTime.now().difference(start).inMilliseconds;
      return {
        'status': 'healthy',
        'latencyMs': duration,
        'data': response.data,
      };
    } catch (e) {
      final duration = DateTime.now().difference(start).inMilliseconds;
      return {
        'status': 'error',
        'latencyMs': duration,
        'error': e.toString(),
      };
    }
  }

  Future<void> saveReceiptConfig({
    required int restaurantId,
    required String receiptHeader,
    required String receiptFooter,
    required double taxRate,
  }) async {
    try {
      await _dio.put('/restaurants/$restaurantId', data: {
        'receipt_header': receiptHeader,
        'receipt_footer': receiptFooter,
        'tax_rate': taxRate,
      });
      _ref.invalidate(restaurantListProvider);
      _ref.invalidate(currentRestaurantProvider);
    } catch (e) {
      throw Exception('Failed to save receipt configuration: $e');
    }
  }
}

