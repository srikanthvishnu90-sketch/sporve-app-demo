import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../../core/data/app_repository.dart';

class OnboardingProvider with ChangeNotifier {
  final AppRepository _repo;
  OnboardingProvider(this._repo);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _submitError;
  String? get submitError => _submitError;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  // Sports Selection
  final List<String> _selectedSports = [];
  List<String> get selectedSports => _selectedSports;
  
  void toggleSport(String sportName) {
    if (_selectedSports.contains(sportName)) {
      _selectedSports.remove(sportName);
    } else {
      _selectedSports.add(sportName);
    }
    notifyListeners();
  }

  // Identity Selection
  String _fullName = '';
  String get fullName => _fullName;

  // Athlete profile details for Postman schema matching
  String? _athleteDob;
  String? get athleteDob => _athleteDob;

  String? _athleteGender;
  String? get athleteGender => _athleteGender;

  String? _athleteMedicalConditions;
  String? get athleteMedicalConditions => _athleteMedicalConditions;

  Map<String, String>? _athleteEmergencyContact;
  Map<String, String>? get athleteEmergencyContact => _athleteEmergencyContact;

  void setAthleteDob(String value) {
    _athleteDob = value;
    notifyListeners();
  }

  void setAthleteGender(String value) {
    _athleteGender = value;
    notifyListeners();
  }

  void setAthleteMedicalConditions(String value) {
    _athleteMedicalConditions = value;
    notifyListeners();
  }

  void setAthleteEmergencyContact(Map<String, String> value) {
    _athleteEmergencyContact = value;
    notifyListeners();
  }
  
  bool _isAthlete = true;
  bool get isAthlete => _isAthlete;
  
  String _selectedAgeRange = '8-10';
  String get selectedAgeRange => _selectedAgeRange;
  
  void setFullName(String value) {
    _fullName = value;
    notifyListeners();
  }
  
  void setRole(bool value) {
    _isAthlete = value;
    notifyListeners();
  }
  
  void setAgeRange(String value) {
    _selectedAgeRange = value;
    notifyListeners();
  }

  // Mission Selection
  String _selectedMission = 'Make the high school team';
  String get selectedMission => _selectedMission;
  
  void setMission(String value) {
    _selectedMission = value;
    notifyListeners();
  }

  // Role selection.
  //
  // PERSISTED: Google OAuth redirects the browser away and back, which rebuilds
  // this provider from scratch. Holding the role in memory silently reset a
  // "Coach or program" user to "Athlete & family" on return, landing them in the
  // wrong portal. Storing it keeps the explicit choice across the round-trip.
  static const String _kRoleKey = 'onboarding_is_service_provider';
  final GetStorage _roleBox = GetStorage();

  late bool _isServiceProvider = _roleBox.read(_kRoleKey) as bool? ?? false;
  bool get isServiceProvider => _isServiceProvider;

  void setServiceProvider(bool value) {
    _isServiceProvider = value;
    _roleBox.write(_kRoleKey, value);
    notifyListeners();
  }

  // Service Provider Fields
  String _institutionName = '';
  String get institutionName => _institutionName;

  int _maxAthletes = 10;
  int get maxAthletes => _maxAthletes;

  String _pricingModel = 'Per session';
  String get pricingModel => _pricingModel;

  int _duration = 30;
  int get duration => _duration;

  double _rate = 0.0;
  double get rate => _rate;

  // Individual Pricing Configuration
  bool _perSessionEnabled = true;
  bool get perSessionEnabled => _perSessionEnabled;
  int _perSessionDuration = 30;
  int get perSessionDuration => _perSessionDuration;
  double _perSessionRate = 0.0;
  double get perSessionRate => _perSessionRate;

  bool _perHourEnabled = false;
  bool get perHourEnabled => _perHourEnabled;
  int _perHourDuration = 60;
  int get perHourDuration => _perHourDuration;
  double _perHourRate = 0.0;
  double get perHourRate => _perHourRate;

  bool _perSeasonEnabled = false;
  bool get perSeasonEnabled => _perSeasonEnabled;
  int _perSeasonDuration = 3;
  int get perSeasonDuration => _perSeasonDuration;
  double _perSeasonRate = 0.0;
  double get perSeasonRate => _perSeasonRate;

  String? _logoPath;
  String? get logoPath => _logoPath;

  String? _coverPhotoPath;
  String? get coverPhotoPath => _coverPhotoPath;

  final List<String> _galleryPaths = [];
  List<String> get galleryPaths => _galleryPaths;

  String? _videoUrl;
  String? get videoUrl => _videoUrl;

  void setInstitutionName(String value) {
    _institutionName = value;
    notifyListeners();
  }

  void setMaxAthletes(int value) {
    _maxAthletes = value;
    notifyListeners();
  }

  void setPricingModel(String value) {
    _pricingModel = value;
    notifyListeners();
  }

  void setDuration(int value) {
    _duration = value;
    notifyListeners();
  }

  void setRate(double value) {
    _rate = value;
    notifyListeners();
  }

  void setPerSessionEnabled(bool val) {
    _perSessionEnabled = val;
    _updateFallbackPricing();
    notifyListeners();
  }
  void setPerSessionDuration(int val) {
    _perSessionDuration = val;
    _updateFallbackPricing();
    notifyListeners();
  }
  void setPerSessionRate(double val) {
    _perSessionRate = val;
    _updateFallbackPricing();
    notifyListeners();
  }

  void setPerHourEnabled(bool val) {
    _perHourEnabled = val;
    _updateFallbackPricing();
    notifyListeners();
  }
  void setPerHourDuration(int val) {
    _perHourDuration = val;
    _updateFallbackPricing();
    notifyListeners();
  }
  void setPerHourRate(double val) {
    _perHourRate = val;
    _updateFallbackPricing();
    notifyListeners();
  }

  void setPerSeasonEnabled(bool val) {
    _perSeasonEnabled = val;
    _updateFallbackPricing();
    notifyListeners();
  }
  void setPerSeasonDuration(int val) {
    _perSeasonDuration = val;
    _updateFallbackPricing();
    notifyListeners();
  }
  void setPerSeasonRate(double val) {
    _perSeasonRate = val;
    _updateFallbackPricing();
    notifyListeners();
  }

  void _updateFallbackPricing() {
    if (_perSessionEnabled) {
      _pricingModel = 'Per session';
      _duration = _perSessionDuration;
      _rate = _perSessionRate;
    } else if (_perHourEnabled) {
      _pricingModel = 'Per hour';
      _duration = _perHourDuration;
      _rate = _perHourRate;
    } else if (_perSeasonEnabled) {
      _pricingModel = 'Per season';
      _duration = _perSeasonDuration;
      _rate = _perSeasonRate;
    } else {
      _pricingModel = 'Per session';
      _duration = 30;
      _rate = 0.0;
    }
  }

  void setLogo(String path) {
    _logoPath = path;
    notifyListeners();
  }

  void setCoverPhoto(String path) {
    _coverPhotoPath = path;
    notifyListeners();
  }

  void addGalleryPhoto(String path) {
    if (_galleryPaths.length < 4) {
      _galleryPaths.add(path);
      notifyListeners();
    }
  }

  void removeGalleryPhoto(int index) {
    if (index >= 0 && index < _galleryPaths.length) {
      _galleryPaths.removeAt(index);
      notifyListeners();
    }
  }

  void setVideoUrl(String value) {
    _videoUrl = value;
    notifyListeners();
  }

  // Simplified Onboarding State additions
  String _location = 'Chicago, IL';
  String get location => _location;

  void setLocation(String value) {
    _location = value;
    notifyListeners();
  }

  bool _profileCompleted = false;
  bool get profileCompleted => _profileCompleted;

  void setProfileCompleted(bool value) {
    _profileCompleted = value;
    notifyListeners();
  }

  /// Persist the child. NOTHING is fabricated: DOB is required (validated by the
  /// UI before this runs), gender/medical/emergencyContact are written only when
  /// the parent actually entered them (null otherwise), and parental consent is
  /// recorded. The UI gates this call behind the un-prechecked consent box.
  Future<bool> submitAthleteProfile() async {
    if (_athleteDob == null || _fullName.trim().isEmpty) {
      // Defensive: the UI must collect a real name + DOB first.
      return false;
    }
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final athletes = await _repo.getAthletes();
      athletes.add({
        '_id': 'athlete_${DateTime.now().millisecondsSinceEpoch}',
        'fullName': _fullName.trim(),
        'dateOfBirth': _athleteDob, // real entered DOB — no default
        if (_athleteGender != null) 'gender': _athleteGender,
        'preferredSports': _selectedSports,
        if (_athleteMedicalConditions != null &&
            _athleteMedicalConditions!.trim().isNotEmpty)
          'medicalConditions': _athleteMedicalConditions!.trim(),
        if (_athleteEmergencyContact != null)
          'emergencyContact': _athleteEmergencyContact,
        // COPPA parental consent (UI gate guarantees this is true here).
        'parentConsent': true,
        'consentAt': DateTime.now().toUtc().toIso8601String(),
        'consentVersion': 'v1',
      });
      await _repo.saveAthletes(athletes);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  Future<bool> submitProviderProfile() async {
    _setLoading(true);
    _submitError = null;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final prof = await _repo.getProviderProfile();
      prof['businessName'] = _institutionName;
      prof['supportedSports'] = _selectedSports;
      prof['maxCapacity'] = _maxAthletes;
      // Persist the provider's chosen pricing (provider-set, per the domain rule).
      prof['pricing'] = {
        'perSession': {
          'enabled': _perSessionEnabled,
          'durationMinutes': _perSessionDuration,
          'rate': _perSessionRate,
        },
        'perHour': {
          'enabled': _perHourEnabled,
          'durationMinutes': _perHourDuration,
          'rate': _perHourRate,
        },
        'perSeason': {
          'enabled': _perSeasonEnabled,
          'durationMonths': _perSeasonDuration,
          'rate': _perSeasonRate,
        },
      };
      // Persist uploaded media so it isn't discarded.
      prof['media'] = {
        'logoPath': _logoPath,
        'coverPhotoPath': _coverPhotoPath,
        'galleryPaths': _galleryPaths,
        'videoUrl': _videoUrl,
      };
      // Completing onboarding LISTS the provider (server derives status =
      // 'approved' from this flag via the enforce_provider_trust trigger). We
      // never send `status` directly — a provider can't self-approve, and can
      // never self-grant the 'verified' trust badge (admin/service-role only).
      prof['onboardingCompleted'] = true;
      await _repo.saveProviderProfile(prof);
      // Role is set at signup via user_metadata (#18); no separate store needed.

      _setLoading(false);
      _submitError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _submitError = e.toString();
      notifyListeners();
      return false;
    }
  }
}
