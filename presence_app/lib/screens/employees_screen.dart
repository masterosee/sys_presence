/// Écran Liste des Employés
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  List<EmployeeModel> _employees = [];
  bool _loading = true;
  String _search = '';
  int _total = 0;
  int _page = 1;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _employees = [];
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.listEmployees(
        search: _search.isEmpty ? null : _search,
        page: _page,
        limit: 20,
      );
      final list = (data['employees'] as List)
          .map((e) => EmployeeModel.fromJson(e))
          .toList();
      setState(() {
        _employees = reset ? list : [..._employees, ...list];
        _total = data['total'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _loading && _employees.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _employees.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _employees.length +
                                (_employees.length < _total ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _employees.length) {
                                return _buildLoadMore();
                              }
                              return _buildEmployeeCard(_employees[i]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeSheet(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employés', style: AppTheme.heading1),
                Text('$_total employés actifs', style: AppTheme.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Chercher par nom, code ou email...',
          prefixIcon: Icon(Icons.search, color: AppTheme.primary),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                    _load(reset: true);
                  },
                )
              : null,
        ),
        onChanged: (v) {
          setState(() => _search = v);
          // Debounce : attendre 500ms avant de chercher
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_search == v) _load(reset: true);
          });
        },
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel emp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          backgroundImage:
              emp.photoUrl != null ? NetworkImage(emp.photoUrl!) : null,
          child: emp.photoUrl == null
              ? Text(
                  emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                )
              : null,
        ),
        title: Text(emp.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${emp.employeeCode} · ${emp.department?['name'] ?? '--'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (emp.position != null)
              Text(emp.position!['title'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emp.isRemote)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Distance',
                    style: TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
        onTap: () => _showEmployeeDetail(emp),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(
          onPressed: () {
            _page++;
            _load();
          },
          child: _loading
              ? const CircularProgressIndicator()
              : Text('Charger plus', style: TextStyle(color: AppTheme.primary)),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'Aucun résultat pour "$_search"'
                : 'Aucun employé trouvé',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ─── Fiche détail employé ─────────────────────────────
  void _showEmployeeDetail(EmployeeModel emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeDetailSheet(employee: emp),
    );
  }

  // ─── Formulaire ajout employé ─────────────────────────
  void _showAddEmployeeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEmployeeSheet(
        onAdded: () => _load(reset: true),
      ),
    );
  }
}

// ─── Fiche détaillée ──────────────────────────────────────────
class _EmployeeDetailSheet extends StatelessWidget {
  final EmployeeModel employee;
  const _EmployeeDetailSheet({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + nom
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          backgroundImage: employee.photoUrl != null
                              ? NetworkImage(employee.photoUrl!)
                              : null,
                          child: employee.photoUrl == null
                              ? Text(employee.fullName[0].toUpperCase(),
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(employee.fullName, style: AppTheme.heading2),
                        Text(employee.employeeCode,
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if (employee.isRemote)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Télétravail',
                                style: TextStyle(
                                    color: AppTheme.secondary, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Infos
                  _InfoRow(Icons.email_outlined, 'Email', employee.email),
                  _InfoRow(Icons.phone_outlined, 'Téléphone',
                      employee.phone ?? '--'),
                  _InfoRow(Icons.business_outlined, 'Département',
                      employee.department?['name'] ?? '--'),
                  _InfoRow(Icons.work_outline, 'Poste',
                      employee.position?['title'] ?? '--'),
                  _InfoRow(Icons.calendar_today_outlined, 'Date d\'embauche',
                      employee.hireDate ?? '--'),
                  _InfoRow(Icons.description_outlined, 'Contrat',
                      employee.contractType ?? '--'),

                  if (employee.statsThisMonth != null) ...[
                    const SizedBox(height: 20),
                    Text('Ce mois-ci', style: AppTheme.heading2),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _StatCard(
                                '${employee.statsThisMonth!['days_present'] ?? 0}',
                                'Jours présent',
                                AppTheme.success)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _StatCard(
                                '${employee.statsThisMonth!['days_late'] ?? 0}',
                                'Retards',
                                AppTheme.warning)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Formulaire ajout employé ─────────────────────────────────
class _AddEmployeeSheet extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddEmployeeSheet({required this.onAdded});

  @override
  ConsumerState<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<_AddEmployeeSheet> {
  final _codeCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _isRemote = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (var c in [
      _codeCtrl,
      _firstCtrl,
      _lastCtrl,
      _emailCtrl,
      _phoneCtrl,
      _pinCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if ([_codeCtrl, _firstCtrl, _lastCtrl, _emailCtrl]
        .any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Veuillez remplir tous les champs obligatoires');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      await api.createEmployee({
        'employee_code': _codeCtrl.text.trim(),
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'hire_date': DateTime.now().toIso8601String().split('T')[0],
        'is_remote': _isRemote,
        if (_pinCtrl.text.trim().isNotEmpty) 'pin_code': _pinCtrl.text.trim(),
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
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
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
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
            Text('Nouvel Employé', style: AppTheme.heading2),
            const SizedBox(height: 20),
            _field(
                _codeCtrl, 'Code employé *', 'CNT-001', Icons.badge_outlined),
            _field(_firstCtrl, 'Prénom *', 'Jean', Icons.person_outline),
            _field(_lastCtrl, 'Nom *', 'Dupont', Icons.person_outline),
            _field(
                _emailCtrl, 'Email *', 'jean@conatel.ht', Icons.email_outlined,
                keyboard: TextInputType.emailAddress),
            _field(
                _phoneCtrl, 'Téléphone', '+509 xxxx-xxxx', Icons.phone_outlined,
                keyboard: TextInputType.phone),
            _field(
                _pinCtrl, 'Code PIN (4-6 chiffres)', '****', Icons.lock_outline,
                keyboard: TextInputType.number),
            SwitchListTile(
              value: _isRemote,
              onChanged: (v) => setState(() => _isRemote = v),
              title: const Text('Travaille à distance'),
              subtitle: const Text('Pointage via GPS'),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
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
                    : const Text('Créer l\'employé'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary),
        ),
      ),
    );
  }
}
