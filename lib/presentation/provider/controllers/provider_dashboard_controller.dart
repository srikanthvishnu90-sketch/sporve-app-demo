import 'package:get/get.dart';

class ProviderDashboardController extends GetxController {
  final RxList<Map<String, dynamic>> affiliatedTrainers = <Map<String, dynamic>>[
    {
      'id': 'tr_101',
      'name': 'Coach Sam Alex',
      'specialty': 'Basketball & Agility',
      'description': 'NCAA Division I player with 6+ years youth coaching experience.',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      'rating': 4.9,
      'reviewsCount': 24,
      'price': 85.0,
      'durationMinutes': 60,
      'isPercentageCommission': true,
      'commissionPercentage': 20.0, // 20% program share
      'flatFeeCents': 1500,
      'monthlyEarningsCents': 142000, // $1,420 monthly revenue to program
    },
    {
      'id': 'tr_102',
      'name': 'Coach Sarah Connor',
      'specialty': 'Soccer Striker Clinic',
      'description': 'USSF B-Licensed Soccer Trainer specializing in finishing and footwork.',
      'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
      'rating': 4.8,
      'reviewsCount': 19,
      'price': 90.0,
      'durationMinutes': 45,
      'isPercentageCommission': false,
      'commissionPercentage': 15.0,
      'flatFeeCents': 2000, // $20 flat fee per booking
      'monthlyEarningsCents': 98000, // $980 monthly revenue to program
    },
  ].obs;

  /// Total monthly revenue gained from all affiliated trainers
  double get monthlyTrainerRevenue {
    int totalCents = 0;
    for (final trainer in affiliatedTrainers) {
      totalCents += (trainer['monthlyEarningsCents'] as int? ?? 0);
    }
    return totalCents / 100.0;
  }

  void addAffiliatedTrainer(Map<String, dynamic> trainer) {
    affiliatedTrainers.add(trainer);
    update();
  }

  void updateTrainerCommission({
    required String trainerId,
    required bool isPercentage,
    required double percentage,
    required int flatFeeCents,
  }) {
    final index = affiliatedTrainers.indexWhere((t) => t['id'] == trainerId);
    if (index != -1) {
      affiliatedTrainers[index]['isPercentageCommission'] = isPercentage;
      affiliatedTrainers[index]['commissionPercentage'] = percentage;
      affiliatedTrainers[index]['flatFeeCents'] = flatFeeCents;
      affiliatedTrainers.refresh();
      update();
    }
  }

  void removeTrainer(String trainerId) {
    affiliatedTrainers.removeWhere((t) => t['id'] == trainerId);
    update();
  }
}
