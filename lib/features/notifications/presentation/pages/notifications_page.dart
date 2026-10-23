import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/services/inbox_service.dart';
import 'inbox_category_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _inboxService = InboxService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final ap = await LocalStorageService.getAccessPoint();
    final user = await LocalStorageService.getUser();
    final list = await _inboxService.fetchInboxSummary();

    debugPrint('====================================================');
    debugPrint('📬 [NOTIFICATIONS PAGE - INBOX SUMMARY]');
    debugPrint('🏢 AccessPoint: $ap | User: ${user?.userName} (ID: ${user?.userId})');
    debugPrint('📋 Raw Categories Count: ${list.length}');
    for (int i = 0; i < list.length; i++) {
      debugPrint('   [$i] Menu: "${list[i]['Menu']}", MenuCode: "${list[i]['MenuCode']}", MenuLinkCode: "${list[i]['MenuLinkCode']}", Cnt: "${list[i]['Cnt']}"');
    }
    debugPrint('====================================================');

    if (mounted) {
      setState(() {
        _categories = list.where((item) {
          final menuTitle = (item['Menu']?.toString() ?? '').toLowerCase();
          final menuCode = item['MenuCode']?.toString() ?? '';
          return menuCode == '19' ||
              menuCode == '15' ||
              menuTitle.contains('leave') ||
              menuTitle.contains('cancel') ||
              menuTitle.contains('cancellation') ||
              menuTitle.contains('claim') ||
              menuTitle.contains('expense') ||
              menuTitle.contains('reimbursement');
        }).toList();
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String menuName, String menuCode) {
    final name = menuName.toLowerCase();
    if (name.contains('cancel') || name.contains('cancellation')) {
      return Icons.event_busy_rounded;
    } else if (name.contains('leave')) {
      return Icons.event_note_rounded;
    } else if (name.contains('claim') || name.contains('expense')) {
      return Icons.receipt_long_rounded;
    } else if (name.contains('offer') || name.contains('letter')) {
      return Icons.description_rounded;
    } else if (name.contains('attendance')) {
      return Icons.access_time_rounded;
    } else if (name.contains('salary') || name.contains('pay')) {
      return Icons.payments_rounded;
    }
    return Icons.folder_open_rounded;
  }

  Color _getCategoryColor(int index) {
    const colors = [
      AppColors.primary,
      Colors.indigo,
      Color(0xFF0D9488),
      Color(0xFFD97706),
      Color(0xFF9333EA),
      Color(0xFFE11D48),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications & Approvals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.mark_email_read_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No pending approval requests',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 24,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final item = _categories[index];
                        final menuTitle =
                            item['Menu']?.toString() ?? 'Approval Request';
                        final menuCode = item['MenuCode']?.toString() ?? '0';
                        final menuLinkCode =
                            item['MenuLinkCode']?.toString() ?? '0';
                        final count =
                            int.tryParse(item['Cnt']?.toString() ?? '0') ?? 0;
                        final color = _getCategoryColor(index);
                        final icon = _getCategoryIcon(menuTitle, menuCode);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(
                                menuTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: count > 0
                                          ? color.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: count > 0 ? color : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InboxCategoryDetailsPage(
                                          title: menuTitle,
                                          menuCode: menuCode,
                                          menuLinkCode: menuLinkCode,
                                        ),
                                  ),
                                ).then((_) => _loadCategories());
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
