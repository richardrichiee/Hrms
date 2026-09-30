import '../../../notifications/data/services/inbox_service.dart';

class NotificationService {
  final _inboxService = InboxService();

  Future<int> fetchNotificationCount() async {
    try {
      final list = await _inboxService.fetchInboxSummary();
      final mobileCategories = list.where((item) {
        final menuTitle = (item['Menu']?.toString() ?? '').toLowerCase();
        final menuCode = item['MenuCode']?.toString() ?? '';
        return menuCode == '19' ||
            menuCode == '15' ||
            menuTitle.contains('leave') ||
            menuTitle.contains('claim') ||
            menuTitle.contains('expense') ||
            menuTitle.contains('reimbursement');
      });

      int total = 0;
      for (final cat in mobileCategories) {
        final cnt = int.tryParse(cat['Cnt']?.toString() ?? '0') ?? 0;
        total += cnt;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}
