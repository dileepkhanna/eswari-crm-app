import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

const Color _cvtPrimary = Color(0xFF1565C0);

const _cvtGstServices  = ['gst_registration','gst_filing_monthly','gst_filing_quarterly',
  'gst_amendment','gst_cancellation','lut_filing','eway_bill','gst_consultation'];
const _cvtMsmeServices = ['msme_registration','msme_certificate','msme_amendment'];
const _cvtItrServices  = ['itr_filing','itr_notice'];

const _cvtServiceTypes = [
  ('gst_registration','GST Registration'), ('gst_filing_monthly','GST Filing (Monthly)'),
  ('gst_filing_quarterly','GST Filing (Quarterly)'), ('gst_amendment','GST Amendment'),
  ('gst_cancellation','GST Cancellation'), ('lut_filing','LUT Filing'),
  ('eway_bill','E-Way Bill'), ('gst_consultation','GST Consultation'),
  ('msme_registration','MSME Registration'), ('msme_certificate','MSME Certificate'),
  ('msme_amendment','MSME Amendment'), ('itr_filing','Income Tax Filing'),
  ('itr_notice','Income Tax Notice'), ('company_registration','Company Registration'),
  ('trademark','Trademark Registration'), ('other','Other'),
];
const _cvtSvcStatuses = [
  ('inquiry','Inquiry'), ('documents_pending','Docs Pending'),
  ('in_progress','In Progress'), ('completed','Completed'), ('rejected','Rejected'),
];
const _cvtLoanTypes = [
  ('personal','Personal Loan'), ('business','Business Loan'), ('home','Home Loan'),
  ('vehicle','Vehicle Loan'), ('education','Education Loan'), ('gold','Gold Loan'),
  ('mortgage','Mortgage Loan'), ('property','Property Loan'), ('other','Other'),
];
const _cvtLoanStatuses = [
  ('inquiry','Inquiry'), ('documents_pending','Docs Pending'),
  ('under_review','Under Review'), ('approved','Approved'),
  ('disbursed','Disbursed'), ('rejected','Rejected'),
];

String _cvtCleanPhone(String raw) {
  if (raw.isEmpty) return raw;
  final d = double.tryParse(raw);
  if (d != null) return d.toInt().toString();
  return raw.replaceAll('.0', '');
}

bool _isValidEmail(dynamic val) {
  if (val == null || val.toString().isEmpty) return false;
  return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val.toString());
}

// ── Entry point ───────────────────────────────────────────────────────────────

void showConvertSheet(
  BuildContext context,
  Map<String, dynamic> customer,
  Map<String, dynamic> userData,
  VoidCallback onConverted,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConvertPickerSheet(
      customer: customer,
      userData: userData,
      onConverted: onConverted,
    ),
  );
}

// ── Picker ────────────────────────────────────────────────────────────────────

class _ConvertPickerSheet extends StatelessWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> userData;
  final VoidCallback onConverted;

  const _ConvertPickerSheet({
    required this.customer,
    required this.userData,
    required this.onConverted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final name = (customer['name'] ?? customer['phone'] ?? 'this customer').toString();

    return Container(
      decoration: BoxDecoration(color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Convert Customer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 6),
        Text('What does $name need?',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600])),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _PickerCard(
            emoji: '🏦', title: 'Loan',
            subtitle: 'Personal, Home,\nBusiness…',
            color: Colors.blue, isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => _LoanFormSheet(customer: customer, userData: userData, onSaved: onConverted),
              );
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: _PickerCard(
            emoji: '📋', title: 'Service',
            subtitle: 'GST, MSME,\nIncome Tax…',
            color: Colors.orange, isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => _ServiceFormSheet(customer: customer, userData: userData, onSaved: onConverted),
              );
            },
          )),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _PickerCard({required this.emoji, required this.title, required this.subtitle,
      required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[600])),
        ]),
      ),
    );
  }
}


// ── Loan Form ─────────────────────────────────────────────────────────────────

class _LoanFormSheet extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> userData;
  final VoidCallback onSaved;
  const _LoanFormSheet({required this.customer, required this.userData, required this.onSaved});
  @override
  State<_LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends State<_LoanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name   = TextEditingController(text: widget.customer['name'] ?? '');
  late final _phone  = TextEditingController(text: _cvtCleanPhone(widget.customer['phone'] ?? ''));
  late final _email  = TextEditingController(text: _isValidEmail(widget.customer['email']) ? (widget.customer['email'] ?? '') : '');
  late final _amount = TextEditingController();
  late final _bank   = TextEditingController();
  late final _notes  = TextEditingController(text: widget.customer['notes'] ?? '');
  String _loanType = 'personal';
  String _status   = 'inquiry';
  bool   _saving   = false;

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _email.dispose();
    _amount.dispose(); _bank.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = widget.userData['id'];
      final assignedTo = uid is int ? uid : int.tryParse(uid.toString());
      final res = await ApiService.post('/capital/loans/', {
        'applicant_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'loan_type': _loanType,
        if (_amount.text.trim().isNotEmpty) 'loan_amount': _amount.text.trim(),
        if (_bank.text.trim().isNotEmpty) 'bank_name': _bank.text.trim(),
        'status': _status,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (assignedTo != null) 'assigned_to': assignedTo,
      });
      if (res['success'] == true) {
        await ApiService.request(
          endpoint: '/capital/customers/${widget.customer['id']}/',
          method: 'PATCH', body: {'is_converted': true},
        );
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Converted to Loan successfully'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          final data = res['data'];
          String msg = 'Failed';
          if (data is Map && data.isNotEmpty) {
            final k = data.keys.first;
            final v = data[k];
            msg = '$k: ${v is List ? v.first : v}';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final ts = TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87);

    InputDecoration dec(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700]),
      filled: true, fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cvtPrimary)),
    );

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Add Loan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
            IconButton(icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(children: [
              TextFormField(controller: _name, style: ts, decoration: dec('Applicant Name *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, style: ts, keyboardType: TextInputType.phone,
                  decoration: dec('Phone *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _email, style: ts, keyboardType: TextInputType.emailAddress,
                  decoration: dec('Email')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _loanType, style: ts,
                dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                decoration: dec('Loan Type'),
                items: _cvtLoanTypes.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                onChanged: (v) => setState(() => _loanType = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _amount, style: ts,
                    keyboardType: TextInputType.number, decoration: dec('Amount (₹)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _bank, style: ts, decoration: dec('Bank Name'))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status, style: ts,
                dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                decoration: dec('Status'),
                items: _cvtLoanStatuses.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, style: ts, maxLines: 3, decoration: dec('Notes')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _cvtPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Loan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          ),
        ),
      ]),
    );
  }
}

// ── Service Form (full with conditional fields) ───────────────────────────────

class _ServiceFormSheet extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> userData;
  final VoidCallback onSaved;
  const _ServiceFormSheet({required this.customer, required this.userData, required this.onSaved});
  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name  = TextEditingController(text: widget.customer['name'] ?? '');
  late final _phone = TextEditingController(text: _cvtCleanPhone(widget.customer['phone'] ?? ''));
  late final _email = TextEditingController(text: _isValidEmail(widget.customer['email']) ? (widget.customer['email'] ?? '') : '');
  late final _biz   = TextEditingController(text: widget.customer['company_name'] ?? '');
  late final _city  = TextEditingController();
  late final _pan   = TextEditingController();
  late final _fy    = TextEditingController();
  late final _fee   = TextEditingController();
  late final _notes = TextEditingController(text: widget.customer['notes'] ?? '');
  late final _gstin = TextEditingController();
  late final _udyam = TextEditingController();
  late final _dob   = TextEditingController();

  late String _svcType;
  String _status       = 'inquiry';
  String _bizType      = '';
  String _turnover     = '';
  String _existingGst  = '';
  String _existingMsme = '';
  String _incomeSlab   = '';
  List<String> _incomeNature = [];
  bool _saving = false;

  bool get _isGST  => _cvtGstServices.contains(_svcType);
  bool get _isMSME => _cvtMsmeServices.contains(_svcType);
  bool get _isITR  => _cvtItrServices.contains(_svcType);

  @override
  void initState() {
    super.initState();
    final interest = widget.customer['interest'] ?? 'none';
    _svcType = interest == 'gst'  ? 'gst_registration'
             : interest == 'msme' ? 'msme_registration'
             : interest == 'itr'  ? 'itr_filing'
             : 'gst_registration';
  }

  @override
  void dispose() {
    for (final c in [_name,_phone,_email,_biz,_city,_pan,_fy,_fee,_notes,_gstin,_udyam,_dob]) c.dispose();
    super.dispose();
  }

  void _toggleNature(String val) => setState(() {
    _incomeNature.contains(val) ? _incomeNature.remove(val) : _incomeNature.add(val);
  });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = widget.userData['id'];
      final assignedTo = uid is int ? uid : int.tryParse(uid.toString());
      final body = <String, dynamic>{
        'client_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'service_type': _svcType,
        'status': _status,
        'financial_year': _fy.text.trim(),
        if (_biz.text.trim().isNotEmpty) 'business_name': _biz.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city_state': _city.text.trim(),
        if (_pan.text.trim().isNotEmpty) 'pan_number': _pan.text.trim(),
        if (_fee.text.trim().isNotEmpty) 'service_fee': _fee.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (assignedTo != null) 'assigned_to': assignedTo,
        if ((_isGST || _isMSME) && _bizType.isNotEmpty) 'business_type': _bizType,
        if (_isGST && _turnover.isNotEmpty) 'turnover_range': _turnover,
        if (_isGST && _existingGst.isNotEmpty) 'existing_gst_number': _existingGst == 'true',
        if (_isGST && _existingGst == 'true' && _gstin.text.trim().isNotEmpty) 'gstin': _gstin.text.trim(),
        if (_isMSME && _existingMsme.isNotEmpty) 'existing_msme_number': _existingMsme == 'true',
        if (_isMSME && _existingMsme == 'true' && _udyam.text.trim().isNotEmpty) 'udyam_number': _udyam.text.trim(),
        if (_isITR && _dob.text.trim().isNotEmpty) 'date_of_birth': _dob.text.trim(),
        if (_isITR && _incomeNature.isNotEmpty) 'income_nature': _incomeNature,
        if (_isITR && _incomeSlab.isNotEmpty) 'income_slab': _incomeSlab,
      };
      final res = await ApiService.post('/capital/services/', body);
      if (res['success'] == true) {
        await ApiService.request(
          endpoint: '/capital/customers/${widget.customer['id']}/',
          method: 'PATCH', body: {'is_converted': true},
        );
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Converted to Service successfully'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          final data = res['data'];
          String msg = 'Failed';
          if (data is Map && data.isNotEmpty) {
            final k = data.keys.first;
            final v = data[k];
            msg = '$k: ${v is List ? v.first : v}';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final ts = TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87);

    InputDecoration dec(String label, {String? hint}) => InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700]),
      hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[400]),
      filled: true, fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cvtPrimary)),
    );

    Widget ddField(String label, String val, List<(String,String)> opts, void Function(String) onChange) {
      return DropdownButtonFormField<String>(
        value: val.isEmpty ? null : val,
        style: ts, dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        decoration: dec(label),
        items: [
          DropdownMenuItem(value: '', child: Text('Select...', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]))),
          ...opts.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2))),
        ],
        onChanged: (v) => setState(() => onChange(v ?? '')),
      );
    }

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Add Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
            IconButton(icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                value: _svcType, style: ts,
                dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                decoration: dec('Service Type *'),
                items: _cvtServiceTypes.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                onChanged: (v) => setState(() { _svcType = v!; _existingGst = ''; _existingMsme = ''; }),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _name, style: ts, decoration: dec('Client Name *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, style: ts, keyboardType: TextInputType.phone,
                  decoration: dec('Phone *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _email, style: ts,
                    keyboardType: TextInputType.emailAddress, decoration: dec('Email'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _city, style: ts, decoration: dec('City / State'))),
              ]),
              if (_isGST || _isMSME) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _biz, style: ts, decoration: dec('Business Name')),
                const SizedBox(height: 12),
                ddField('Type of Business', _bizType, [
                  ('proprietor','Proprietor'), ('partnership','Partnership'), ('company','Company'),
                ], (v) => _bizType = v),
              ],
              if (_isGST) ...[
                const SizedBox(height: 12),
                ddField('Turnover Range', _turnover, [
                  ('below_20l','Below ₹20 Lakhs'), ('20l_1cr','₹20L – ₹1 Cr'), ('above_1cr','Above ₹1 Cr'),
                ], (v) => _turnover = v),
                const SizedBox(height: 12),
                ddField('Existing GST Number?', _existingGst, [('false','No'), ('true','Yes')], (v) => _existingGst = v),
                if (_existingGst == 'true') ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _gstin, style: ts,
                      decoration: dec('GSTIN', hint: '15-digit GSTIN'),
                      maxLength: 15, textCapitalization: TextCapitalization.characters),
                ],
              ],
              if (_isMSME) ...[
                const SizedBox(height: 12),
                ddField('Existing MSME Number?', _existingMsme, [('false','No'), ('true','Yes')], (v) => _existingMsme = v),
                if (_existingMsme == 'true') ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _udyam, style: ts,
                      decoration: dec('Udyam Number', hint: 'UDYAM-XX-00-0000000')),
                ],
              ],
              if (_isITR) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _dob, style: ts,
                    decoration: dec('Date of Birth', hint: 'YYYY-MM-DD'),
                    keyboardType: TextInputType.datetime),
                const SizedBox(height: 12),
                Text('Income Nature', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ('salaried','Salaried'), ('shares','Shares'), ('rental','Rental'), ('other','Other'),
                ].map((o) {
                  final active = _incomeNature.contains(o.$1);
                  return GestureDetector(
                    onTap: () => _toggleNature(o.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? _cvtPrimary : (isDark ? Colors.white10 : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? _cvtPrimary : Colors.transparent),
                      ),
                      child: Text(o.$2, style: TextStyle(fontSize: 12,
                          color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                ddField('Income Slab', _incomeSlab, [
                  ('0_5l','0 to ₹5 Lakh'), ('5l_10l','₹5L to ₹10L'),
                  ('10l_18l','₹10L to ₹18L'), ('above_18l','Above ₹18L'),
                ], (v) => _incomeSlab = v),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _pan, style: ts,
                    decoration: dec('PAN Number', hint: 'ABCDE1234F'),
                    maxLength: 10, textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _fy, style: ts,
                    decoration: dec('Financial Year', hint: '2024-25'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _status, style: ts,
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Status'),
                  items: _cvtSvcStatuses.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _fee, style: ts,
                    keyboardType: TextInputType.number, decoration: dec('Service Fee (₹)'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, style: ts, maxLines: 3, decoration: dec('Notes')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _cvtPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          ),
        ),
      ]),
    );
  }
}
