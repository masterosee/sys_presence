/// Écran Congés - Demandes et historique
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key});

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends ConsumerState<LeavesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<LeaveRequestModel> _myLeaves = [];
  List<dynamic> _pending = [];
  List<dynamic> _leaveTypes = [];
  bool _loading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiServiceProvider);
    _role = await api.getRole();

    try {
      final results = await Future.wait([
        api.getMyLeaves(),
        api.getLeaveTypes(),
        if (_role != null && _role != 'employee') api.getPendingLeaves(),
      ]);
      setState(() {
        _myLeaves = results[0] as List<LeaveRequestModel>;
        _leaveTypes = results[1] as List<dynamic>;
        if (results.length > 2) _pending = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _role != null && _role != 'employee';
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primary,
              tabs: [
                const Tab(text: 'Mes demandes'),
                if (isManager) Tab(text: 'À approuver (${_pending.length})'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildMyLeaves(),
                        if (isManager) _buildPending(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestSheet,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Demander un congé',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(child: Text('Congés & Absences', style: AppTheme.heading1)),
        ],
      ),
    );
  }

  // ─── Mes demandes ─────────────────────────────────────
  Widget _buildMyLeaves() {
    if (_myLeaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.beach_access_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucune demande de congé',
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _myLeaves.length,
        itemBuilder: (_, i) => _buildLeaveCard(_myLeaves[i]),
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestModel leave) {
    Color statusColor;
    IconData statusIcon;
    switch (leave.status) {
      case 'approved':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = AppTheme.warning;
        statusIcon = Icons.hourglass_empty;
    }

    final colorHex = leave.leaveTypeColor.replaceFirst('#', '');
    final typeColor = Color(int.parse('FF$colorHex', radix: 16));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
        border: Border(left: BorderSide(color: typeColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(leave.leaveTypeName,
                      style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                const Spacer(),
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 4),
                Text(
                  leave.status == 'approved'
                      ? 'Approuvé'
                      : leave.status == 'rejected'
                          ? 'Rejeté'
                          : leave.status == 'cancelled'
                              ? 'Annulé'
                              : 'En attente',
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text('${leave.startDate}  →  ${leave.endDate}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${leave.totalDays} jour(s)',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            if (leave.reason != null && leave.reason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(leave.reason!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
            if (leave.reviewComment != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Commentaire : ${leave.reviewComment}',
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Demandes à approuver ─────────────────────────────
  Widget _buildPending() {
    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 60, color: AppTheme.success.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Aucune demande en attente',
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _pending.length,
      itemBuilder: (_, i) => _buildPendingCard(_pending[i]),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> leave) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  (leave['employee_name'] ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leave['employee_name'] ?? '--',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(leave['employee_code'] ?? '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text(leave['leave_type_name'] ?? '',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              'Du ${leave['start_date']} au ${leave['end_date']} · ${leave['total_days']} jour(s)',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          if (leave['reason'] != null) ...[
            const SizedBox(height: 4),
            Text(leave['reason'],
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _review(leave['id'], 'rejected'),
                  icon: Icon(Icons.close, color: AppTheme.error, size: 16),
                  label:
                      Text('Rejeter', style: TextStyle(color: AppTheme.error)),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.error.withOpacity(0.4))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _review(leave['id'], 'approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────
  Future<void> _review(String leaveId, String status) async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.reviewLeave(leaveId: leaveId, status: status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              status == 'approved' ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestLeaveSheet(
        leaveTypes: _leaveTypes,
        onSubmitted: _load,
      ),
    );
  }
}

// ─── Formulaire demande congé ─────────────────────────────────
class _RequestLeaveSheet extends ConsumerStatefulWidget {
  final List<dynamic> leaveTypes;
  final VoidCallback onSubmitted;
  const _RequestLeaveSheet(
      {required this.leaveTypes, required this.onSubmitted});

  @override
  ConsumerState<_RequestLeaveSheet> createState() => _RequestLeaveSheetState();
}

class _RequestLeaveSheetState extends ConsumerState<_RequestLeaveSheet> {
  String? _selectedTypeId;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  int get _workingDays {
    if (_startDate == null || _endDate == null) return 0;
    int count = 0;
    var d = _startDate!;
    while (!d.isAfter(_endDate!)) {
      if (d.weekday <= 5) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedTypeId == null || _startDate == null || _endDate == null) {
      setState(() => _error = 'Veuillez remplir tous les champs obligatoires');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final r = await api.requestLeave(
        leaveTypeId: _selectedTypeId!,
        startDate: _startDate!.toIso8601String().split('T')[0],
        endDate: _endDate!.toIso8601String().split('T')[0],
        reason:
            _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      widget.onSubmitted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(r['message']),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),
            Text('Demande de congé', style: AppTheme.heading2),
            const SizedBox(height: 20),

            // Type de congé
            DropdownButtonFormField<String>(
              value: _selectedTypeId,
              decoration: InputDecoration(
                labelText: 'Type de congé *',
                prefixIcon:
                    Icon(Icons.category_outlined, color: AppTheme.primary),
              ),
              items: widget.leaveTypes.map<DropdownMenuItem<String>>((t) {
                return DropdownMenuItem(
                  value: t['id'].toString(),
                  child:
                      Text('${t['name']} (${t['max_days'] ?? '∞'} jours/an)'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedTypeId = v),
            ),
            const SizedBox(height: 14),

            // Dates
            Row(
              children: [
                Expanded(
                    child: _DateButton(
                        'Début *', _startDate, () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _DateButton('Fin *', _endDate, () => _pickDate(false))),
              ],
            ),

            if (_workingDays > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('$_workingDays jour(s) ouvrable(s)',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motif (optionnel)',
                prefixIcon: Icon(Icons.notes_outlined, color: AppTheme.primary),
                alignLabelWithHint: true,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(color: AppTheme.error, fontSize: 13)),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text('Soumettre la demande'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateButton(this.label, this.date, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Text(
                  date != null
                      ? '${date!.day}/${date!.month}/${date!.year}'
                      : 'Choisir',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: date != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
