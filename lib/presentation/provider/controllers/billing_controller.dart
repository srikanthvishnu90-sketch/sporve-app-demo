import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/models/subscription.dart';

class BillingController extends ChangeNotifier {
  final AppRepository _repository;

  BillingController(this._repository);

  List<SubscriptionPlan> _plans = const [];
  ProviderSubscription? _subscription;
  bool _loading = false;
  bool _acting = false;
  String? _error;

  List<SubscriptionPlan> get plans => List.unmodifiable(_plans);
  ProviderSubscription? get subscription => _subscription;
  bool get loading => _loading;
  bool get acting => _acting;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.getSubscriptionPlans(),
        _repository.getProviderSubscription(),
      ]);
      _plans = results[0] as List<SubscriptionPlan>;
      _subscription = results[1] as ProviderSubscription;
    } on BillingException catch (error) {
      _error = error.message;
    } catch (error) {
      debugPrint('BillingController.load failed: $error');
      _error = 'Billing could not be loaded. Try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Uri?> startCheckout({
    required SubscriptionTier plan,
    required Uri successUrl,
    required Uri cancelUrl,
  }) async {
    if (_acting) return null;
    final subscription = _subscription;
    if (subscription == null) {
      _error = 'Load the current workspace plan before starting checkout.';
      notifyListeners();
      return null;
    }
    SubscriptionPlan? selectedPlan;
    for (final candidate in _plans) {
      if (candidate.tier == plan) {
        selectedPlan = candidate;
        break;
      }
    }
    if (selectedPlan == null ||
        !selectedPlan.purchasable ||
        plan == SubscriptionTier.free) {
      _error = 'That plan is not available for self-serve purchase.';
      notifyListeners();
      return null;
    }
    if (subscription.tier == plan &&
        subscription.hasEntitlementAt(DateTime.now())) {
      _error = '${plan.displayName} is already active for this workspace.';
      notifyListeners();
      return null;
    }
    if (subscription.tier != SubscriptionTier.free &&
        subscription.tier != plan &&
        subscription.hasEntitlementAt(DateTime.now())) {
      _error = 'Manage your active plan before choosing another one.';
      notifyListeners();
      return null;
    }
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      return await _repository.createSubscriptionCheckout(
        plan: plan,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
    } on BillingException catch (error) {
      _error = error.message;
      return null;
    } catch (error) {
      debugPrint('BillingController.startCheckout failed: $error');
      _error = 'Billing could not be started. Try again.';
      return null;
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  Future<Uri?> openPortal({required Uri returnUrl}) async {
    if (_acting) return null;
    if (_subscription?.canManageBilling != true) {
      _error = 'No Stripe billing history is available for this workspace.';
      notifyListeners();
      return null;
    }
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      return await _repository.createBillingPortal(returnUrl: returnUrl);
    } on BillingException catch (error) {
      _error = error.message;
      return null;
    } catch (error) {
      debugPrint('BillingController.openPortal failed: $error');
      _error = 'Billing management is temporarily unavailable.';
      return null;
    } finally {
      _acting = false;
      notifyListeners();
    }
  }
}
