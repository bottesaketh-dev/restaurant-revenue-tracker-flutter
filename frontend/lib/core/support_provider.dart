import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'restaurant_provider.dart';

class SupportDeskInfo {
  final String helpline;
  final String tollFree;
  final String whatsapp;
  final String email;
  final String hours;
  final String sla;
  final String serviceStatus;
  final String uptime;
  final String version;

  const SupportDeskInfo({
    this.helpline = '+91 40 4000 3600',
    this.tollFree = '1800-IOR-360',
    this.whatsapp = '+91 98490 12345',
    this.email = 'ops-emergency@ior360.com',
    this.hours = '24/7 Operations Support Desk (Priority rush-hour coverage 12:00-15:30 & 19:00-23:30)',
    this.sla = 'Under 5 minutes during active rush hours, < 30 mins off-peak',
    this.serviceStatus = 'All Core Systems Operational',
    this.uptime = '99.98%',
    this.version = 'IOR 360 v2.4.0 (Build 2026.10)',
  });

  factory SupportDeskInfo.fromJson(Map<String, dynamic> json) {
    return SupportDeskInfo(
      helpline: json['helpline'] ?? '+91 40 4000 3600',
      tollFree: json['toll_free'] ?? '1800-IOR-360',
      whatsapp: json['whatsapp'] ?? '+91 98490 12345',
      email: json['email'] ?? 'ops-emergency@ior360.com',
      hours: json['hours'] ?? '24/7 Operations Support Desk',
      sla: json['sla'] ?? '< 5 mins rush hours',
      serviceStatus: json['service_status'] ?? 'Operational',
      uptime: json['uptime'] ?? '99.98%',
      version: json['version'] ?? 'IOR 360 v2.4.0',
    );
  }
}

class SupportTicketItem {
  final int ticketId;
  final String ticketNumber;
  final int? restaurantId;
  final int? branchId;
  final int? userId;
  final String? userName;
  final String category;
  final String priority;
  final String subject;
  final String description;
  final String? contactPhone;
  final String status;
  final String? resolutionNotes;
  final String? metadataJson;
  final String? createdAt;

  SupportTicketItem({
    required this.ticketId,
    required this.ticketNumber,
    this.restaurantId,
    this.branchId,
    this.userId,
    this.userName,
    required this.category,
    required this.priority,
    required this.subject,
    required this.description,
    this.contactPhone,
    required this.status,
    this.resolutionNotes,
    this.metadataJson,
    this.createdAt,
  });

  factory SupportTicketItem.fromJson(Map<String, dynamic> json) {
    return SupportTicketItem(
      ticketId: json['ticket_id'] ?? 0,
      ticketNumber: json['ticket_number'] ?? '',
      restaurantId: json['restaurant_id'],
      branchId: json['branch_id'],
      userId: json['user_id'],
      userName: json['user_name'],
      category: json['category'] ?? 'General',
      priority: json['priority'] ?? 'MEDIUM',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      contactPhone: json['contact_phone'],
      status: json['status'] ?? 'OPEN',
      resolutionNotes: json['resolution_notes'],
      metadataJson: json['metadata_json'],
      createdAt: json['created_at'],
    );
  }
}

class SupportNotifier extends StateNotifier<AsyncValue<List<SupportTicketItem>>> {
  final Dio dio;
  final int? userId;
  final int? restaurantId;

  SupportNotifier({
    required this.dio,
    this.userId,
    this.restaurantId,
  }) : super(const AsyncValue.loading()) {
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final queryParams = restaurantId != null ? {'restaurant_id': restaurantId} : null;
      final res = await dio.get('/support/tickets', queryParameters: queryParams);
      final list = (res.data as List).map((e) => SupportTicketItem.fromJson(e)).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<SupportTicketItem?> createTicket({
    required String category,
    required String priority,
    required String subject,
    required String description,
    String? contactPhone,
    String? metadataJson,
  }) async {
    try {
      final res = await dio.post('/support/tickets', data: {
        'category': category,
        'priority': priority,
        'subject': subject,
        'description': description,
        'contact_phone': contactPhone,
        'metadata_json': metadataJson,
        if (restaurantId != null) 'restaurant_id': restaurantId,
      });
      final newTicket = SupportTicketItem.fromJson(res.data);
      final current = state.value ?? [];
      state = AsyncValue.data([newTicket, ...current]);
      return newTicket;
    } catch (e) {
      rethrow;
    }
  }
}

final supportTicketsProvider = StateNotifierProvider<SupportNotifier, AsyncValue<List<SupportTicketItem>>>((ref) {
  final dio = ref.watch(dioProvider);
  final authState = ref.watch(authStateProvider);
  final selectedRestaurantId = ref.watch(selectedRestaurantIdProvider);

  final userId = authState.user?['id'] as int? ?? authState.user?['user_id'] as int?;
  final restaurantId = selectedRestaurantId ?? authState.restaurantId;

  return SupportNotifier(
    dio: dio,
    userId: userId,
    restaurantId: restaurantId,
  );
});

final supportInfoProvider = FutureProvider<SupportDeskInfo>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get('/support/info');
    return SupportDeskInfo.fromJson(res.data);
  } catch (_) {
    return const SupportDeskInfo();
  }
});

