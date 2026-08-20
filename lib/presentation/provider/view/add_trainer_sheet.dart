import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/provider_dashboard_controller.dart';

class AddTrainerSheet extends StatefulWidget {
  const AddTrainerSheet({super.key});

  @override
  State<AddTrainerSheet> createState() => _AddTrainerSheetState();
}

class _AddTrainerSheetState extends State<AddTrainerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '75');
  final _durationController = TextEditingController(text: '60');
  final _flatFeeController = TextEditingController(text: '15');

  bool _isPercentageCommission = true;
  double _commissionPercentage = 15.0; // Default 15%
  String? _selectedAvatarUrl;
  bool _accountFound = false;

  // Mock Sporve existing user registry for hybrid search
  final List<Map<String, String>> _existingSporveAccounts = [
    {
      'username': 'coach.sam',
      'email': 'sam@sporve.com',
      'name': 'Sam Alex',
      'specialty': 'Basketball & Agility',
      'description':
          'NCAA Division I player with 6+ years youth coaching experience.',
      'avatar':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      'price': '85',
      'duration': '60',
    },
    {
      'username': 'coach.sarah',
      'email': 'sarah@sporve.com',
      'name': 'Sarah Connor',
      'specialty': 'Soccer Striker Clinic',
      'description':
          'USSF B-Licensed Soccer Trainer specializing in finishing and footwork.',
      'avatar':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
      'price': '90',
      'duration': '45',
    },
    {
      'username': 'coach.david',
      'email': 'david@sporve.com',
      'name': 'David Miller',
      'specialty': 'Tennis & Footwork',
      'description':
          'Former ATP Challenger tour player focusing on junior player development.',
      'avatar':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      'price': '100',
      'duration': '60',
    },
  ];

  void _searchSporveAccount(String query) {
    if (query.trim().isEmpty) return;
    final match = _existingSporveAccounts.firstWhere(
      (acc) =>
          acc['username']!.toLowerCase().contains(query.toLowerCase()) ||
          acc['email']!.toLowerCase().contains(query.toLowerCase()),
      orElse: () => {},
    );

    if (match.isNotEmpty) {
      setState(() {
        _accountFound = true;
        _nameController.text = match['name']!;
        _specialtyController.text = match['specialty']!;
        _descriptionController.text = match['description']!;
        _priceController.text = match['price']!;
        _durationController.text = match['duration']!;
        _selectedAvatarUrl = match['avatar'];
      });
      Get.snackbar(
        'Account Linked',
        'Auto-filled details for ${match['name']}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E293B),
        colorText: Colors.white,
      );
    } else {
      setState(() {
        _accountFound = false;
      });
      Get.snackbar(
        'Account Not Found',
        'Entering custom trainer details manually',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF475569),
        colorText: Colors.white,
      );
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final double price = double.tryParse(_priceController.text) ?? 75.0;
      final int duration = int.tryParse(_durationController.text) ?? 60;
      final double flatFee = double.tryParse(_flatFeeController.text) ?? 15.0;

      final newTrainer = {
        'id': 'tr_${DateTime.now().millisecondsSinceEpoch}',
        'name': _nameController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'description': _descriptionController.text.trim(),
        'avatar':
            _selectedAvatarUrl ??
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
        'rating': 4.9,
        'reviewsCount': 18,
        'price': price,
        'durationMinutes': duration,
        'isPercentageCommission': _isPercentageCommission,
        'commissionPercentage': _commissionPercentage,
        'flatFeeCents': (flatFee * 100).toInt(),
      };

      if (Get.isRegistered<ProviderDashboardController>()) {
        Get.find<ProviderDashboardController>().addAffiliatedTrainer(
          newTrainer,
        );
      }

      Get.back();
      Get.snackbar(
        'Trainer Added',
        '${newTrainer['name']} is now listed under your organization',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF0F172A),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Affiliated Trainer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'List a trainer under your organization and configure the revenue split.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Search existing Sporve Account bar
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search Sporve username or email...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        _searchSporveAccount(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lookup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (_accountFound) ...[
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF34D399),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Sporve Verified Account Linked',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Trainer Name & Specialty
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Trainer Full Name *',
                  Icons.person,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Trainer name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specialtyController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Specialty (e.g. Shooting Coach, Striker Clinic)',
                  Icons.sports,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Specialty is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: _inputDecoration(
                  'Trainer Bio / Description',
                  Icons.description,
                ),
              ),
              const SizedBox(height: 12),

              // Price & Duration
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Session Price (\$)',
                        Icons.attach_money,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Duration (Mins)',
                        Icons.timer,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Organization revenue-share controls
              const Text(
                'Program revenue split',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set the revenue percentage or flat fee your organization retains per booking.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Commission Type Segmented Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _isPercentageCommission = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isPercentageCommission
                                ? const Color(0xFF38BDF8)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Percentage (%)',
                              style: TextStyle(
                                color: _isPercentageCommission
                                    ? Colors.black
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _isPercentageCommission = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isPercentageCommission
                                ? const Color(0xFF38BDF8)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Flat Fee (\$)',
                              style: TextStyle(
                                color: !_isPercentageCommission
                                    ? Colors.black
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isPercentageCommission) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Organization share:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '${_commissionPercentage.round()}%',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _commissionPercentage,
                  min: 0.0,
                  max: 50.0,
                  divisions: 50,
                  activeColor: const Color(0xFF38BDF8),
                  inactiveColor: Colors.white24,
                  label: '${_commissionPercentage.round()}%',
                  onChanged: (val) =>
                      setState(() => _commissionPercentage = val),
                ),
              ] else ...[
                TextFormField(
                  controller: _flatFeeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Flat organization share (\$ per session)',
                    Icons.monetization_on,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Trainer to Organization',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
