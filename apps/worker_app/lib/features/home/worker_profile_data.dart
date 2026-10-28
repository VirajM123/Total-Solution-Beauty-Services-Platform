import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_operations_api.dart';

const workerServiceOptions = <String, List<String>>{
  'Hair': [
    'Haircut',
    'Hair Styling',
    'Hair Spa',
    'Hair Colouring',
    'Bridal Hairstyle',
  ],
  'Makeup': [
    'Party Makeup',
    'Bridal Makeup',
    'Engagement Makeup',
    'Natural Makeup',
  ],
  'Skin & Facial': ['Classic Facial', 'Clean-up', 'Detan', 'Skin Care'],
  'Waxing & Grooming': [
    'Full Arms Waxing',
    'Full Legs Waxing',
    'Threading',
    'Eyebrow Shaping',
  ],
  'Nails': ['Manicure', 'Pedicure', 'Nail Art', 'Nail Extensions'],
  'Mehendi': ['Bridal Mehendi', 'Arabic Mehendi', 'Festival Mehendi'],
};

@immutable
class WorkerProfile {
  const WorkerProfile({
    required this.mobile,
    required this.fullName,
    required this.email,
    required this.dateOfBirth,
    required this.cityOrArea,
    required this.primaryCategory,
    required this.services,
    required this.yearsOfExperience,
    required this.workMode,
    required this.travelRadiusKm,
    required this.languages,
    required this.about,
    required this.certificateDetails,
    this.profilePhotoPath,
    this.notificationsEnabled = true,
  });

  final String mobile;
  final String fullName;
  final String email;
  final DateTime dateOfBirth;
  final String cityOrArea;
  final String primaryCategory;
  final List<String> services;
  final int yearsOfExperience;
  final String workMode;
  final int travelRadiusKm;
  final List<String> languages;
  final String about;
  final String certificateDetails;
  final String? profilePhotoPath;
  final bool notificationsEnabled;

  WorkerProfile copyWith({
    String? fullName,
    String? email,
    DateTime? dateOfBirth,
    String? cityOrArea,
    String? primaryCategory,
    List<String>? services,
    int? yearsOfExperience,
    String? workMode,
    int? travelRadiusKm,
    List<String>? languages,
    String? about,
    String? certificateDetails,
    String? profilePhotoPath,
    bool? notificationsEnabled,
  }) => WorkerProfile(
    mobile: mobile,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    cityOrArea: cityOrArea ?? this.cityOrArea,
    primaryCategory: primaryCategory ?? this.primaryCategory,
    services: List.unmodifiable(services ?? this.services),
    yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
    workMode: workMode ?? this.workMode,
    travelRadiusKm: travelRadiusKm ?? this.travelRadiusKm,
    languages: List.unmodifiable(languages ?? this.languages),
    about: about ?? this.about,
    certificateDetails: certificateDetails ?? this.certificateDetails,
    profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'mobile': mobile,
    'fullName': fullName,
    'email': email,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    'cityOrArea': cityOrArea,
    'primaryCategory': primaryCategory,
    'services': services,
    'yearsOfExperience': yearsOfExperience,
    'workMode': workMode,
    'travelRadiusKm': travelRadiusKm,
    'languages': languages,
    'about': about,
    'certificateDetails': certificateDetails,
    'profilePhotoPath': profilePhotoPath,
    'notificationsEnabled': notificationsEnabled,
  };

  factory WorkerProfile.fromJson(Map<String, Object?> json) {
    List<String> readStrings(String key) {
      final value = json[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid worker profile field: $key');
      }
      return List.unmodifiable(value.cast<String>());
    }

    String readString(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException('Invalid worker profile field: $key');
      }
      return value;
    }

    final date = DateTime.tryParse(readString('dateOfBirth'));
    final years = json['yearsOfExperience'];
    final radius = json['travelRadiusKm'];
    final notifications = json['notificationsEnabled'];
    if (date == null ||
        years is! int ||
        radius is! int ||
        notifications is! bool ||
        json['version'] != 1) {
      throw const FormatException('Saved worker profile is invalid');
    }
    return WorkerProfile(
      mobile: readString('mobile'),
      fullName: readString('fullName'),
      email: readString('email'),
      dateOfBirth: date,
      cityOrArea: readString('cityOrArea'),
      primaryCategory: readString('primaryCategory'),
      services: readStrings('services'),
      yearsOfExperience: years,
      workMode: readString('workMode'),
      travelRadiusKm: radius,
      languages: readStrings('languages'),
      about: readString('about'),
      certificateDetails: readString('certificateDetails'),
      profilePhotoPath: json['profilePhotoPath'] is String
          ? json['profilePhotoPath'] as String
          : null,
      notificationsEnabled: notifications,
    );
  }
}

abstract interface class WorkerProfileStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureWorkerProfileStorage implements WorkerProfileStorage {
  SecureWorkerProfileStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class WorkerProfileRepository extends ChangeNotifier {
  WorkerProfileRepository(
    this._storage, {
    WorkerOperationsApi? operationsApi,
  }) : _operationsApi = operationsApi;

  final WorkerProfileStorage _storage;
  final Map<String, WorkerProfile?> _cache = {};
  WorkerOperationsApi? _operationsApi;

  void setOperationsApi(WorkerOperationsApi? api) {
    _operationsApi = api;
  }

  static String _digits(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    return digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
  }

  static String _storageKey(String mobile) =>
      'pinkora.worker.profile.v1.${_digits(mobile)}';

  WorkerProfile? profileFor(String mobile) => _cache[_digits(mobile)];

  Future<WorkerProfile?> load(String mobile) async {
    final normalized = _digits(mobile);
    if (normalized.isEmpty) return null;

    final raw = await _storage.read(_storageKey(normalized));
    WorkerProfile? local;
    if (raw != null) {
      try {
        local = WorkerProfile.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
        _cache[normalized] = local;
        notifyListeners();
      } catch (_) {}
    }

    if (local != null) {
      if (_operationsApi is WorkerMobileOperationsApi) {
        unawaited(_revalidateWithServer(normalized, mobile, local));
      }
      return local;
    }

    if (_operationsApi is WorkerMobileOperationsApi) {
      final fromServer = await _revalidateWithServer(normalized, mobile, null);
      if (fromServer != null) return fromServer;
    }

    return _cache[normalized];
  }

  Future<WorkerProfile?> _revalidateWithServer(
    String normalized,
    String mobile,
    WorkerProfile? local,
  ) async {
    if (_operationsApi is! WorkerMobileOperationsApi) return null;
    try {
      final data = await (_operationsApi as WorkerMobileOperationsApi)
          .fetchWorkerProfile();
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final profile = data['profile'] as Map<String, dynamic>? ?? {};

      final rawServices = profile['services'];
      final List<String> servicesList;
      if (rawServices is List && rawServices.isNotEmpty) {
        servicesList = rawServices.cast<String>();
      } else if (local != null && local.services.isNotEmpty) {
        servicesList = local.services;
      } else {
        servicesList = const ['Hair Styling'];
      }

      final rawLangs = profile['languages'];
      final List<String> languagesList;
      if (rawLangs is List && rawLangs.isNotEmpty) {
        languagesList = rawLangs.cast<String>();
      } else if (local != null && local.languages.isNotEmpty) {
        languagesList = local.languages;
      } else {
        languagesList = const ['English', 'Hindi'];
      }

      final dobStr = profile['dateOfBirth'] as String?;
      final parsedDob = dobStr != null ? DateTime.tryParse(dobStr) : null;
      final dob = parsedDob ?? local?.dateOfBirth ?? DateTime(1995, 1, 1);

      final serverProfile = WorkerProfile(
        mobile: (user['mobileNumber'] as String?) ??
            (profile['mobileNumber'] as String?) ??
            mobile,
        fullName: (user['fullName'] as String?) ??
            (profile['fullName'] as String?) ??
            local?.fullName ??
            'Worker',
        email: (user['email'] as String?) ??
            (profile['email'] as String?) ??
            local?.email ??
            '',
        dateOfBirth: dob,
        cityOrArea: (profile['cityOrArea'] as String?) ??
            local?.cityOrArea ??
            'Latur Central',
        primaryCategory: (profile['primaryCategory'] as String?) ??
            local?.primaryCategory ??
            'Hair',
        services: servicesList,
        yearsOfExperience: (profile['experienceYears'] as num?)?.toInt() ??
            local?.yearsOfExperience ??
            2,
        workMode: (profile['workMode'] as String?) ??
            local?.workMode ??
            'Salon-based',
        travelRadiusKm: (profile['travelRadiusKm'] as num?)?.toInt() ??
            local?.travelRadiusKm ??
            10,
        languages: languagesList,
        about: (profile['about'] as String?) ??
            local?.about ??
            'Professional salon artist with Hii Beauty',
        certificateDetails: (profile['certificateDetails'] as String?) ??
            local?.certificateDetails ??
            'Verified Specialist',
        profilePhotoPath: local?.profilePhotoPath ??
            (profile['profilePhotoPath'] as String?),
        notificationsEnabled: (profile['notificationsEnabled'] as bool?) ??
            local?.notificationsEnabled ??
            true,
      );

      await _storage.write(
        _storageKey(normalized),
        jsonEncode(serverProfile.toJson()),
      );
      _cache[normalized] = serverProfile;
      notifyListeners();
      return serverProfile;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(WorkerProfile profile) async {
    final normalized = _digits(profile.mobile);
    if (normalized.isEmpty) {
      throw ArgumentError.value(profile.mobile, 'mobile', 'Mobile is required');
    }
    final saved = profile.copyWith();
    await _storage.write(_storageKey(normalized), jsonEncode(saved.toJson()));
    _cache[normalized] = saved;
    notifyListeners();

    if (_operationsApi is WorkerMobileOperationsApi) {
      await _syncToServer(saved);
    }
  }

  Future<void> _syncToServer(WorkerProfile saved) async {
    try {
      final body = <String, dynamic>{
        'fullName': saved.fullName,
        if (saved.email.trim().isNotEmpty) 'email': saved.email.trim(),
        'cityOrArea': saved.cityOrArea,
        'about': saved.about,
        'experienceYears': saved.yearsOfExperience,
        'primaryCategory': saved.primaryCategory,
        'services': saved.services,
        'notificationsEnabled': saved.notificationsEnabled,
        'languages': saved.languages,
        'workMode': saved.workMode,
        'travelRadiusKm': saved.travelRadiusKm,
        'dateOfBirth': saved.dateOfBirth.toIso8601String(),
        'certificateDetails': saved.certificateDetails,
        if (saved.profilePhotoPath != null)
          'profilePhotoPath': saved.profilePhotoPath,
      };
      await (_operationsApi as WorkerMobileOperationsApi)
          .updateWorkerProfile(body);
    } catch (_) {}
  }

  Future<String> savePhoto(String mobile, Uint8List bytes) async {
    final normalized = _digits(mobile);
    if (normalized.isEmpty) {
      throw ArgumentError.value(mobile, 'mobile', 'Mobile is required');
    }
    if (bytes.isEmpty || bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes',
        'Photo must be under 5 MB',
      );
    }
    final directory = await getApplicationSupportDirectory();
    final photoDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}worker_profiles',
    );
    await photoDirectory.create(recursive: true);
    final destination = File(
      '${photoDirectory.path}${Platform.pathSeparator}worker_$normalized.img',
    );
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await destination.exists()) await destination.delete();
    final saved = await temporary.rename(destination.path);
    return saved.path;
  }

  Future<WorkerProfile> saveRegistration(
    WorkerProfile profile, {
    Uint8List? profilePhotoBytes,
  }) async {
    final normalized = _digits(profile.mobile);
    final existing = await load(profile.mobile);
    final saved = existing == null
        ? profile
        : profile.copyWith(
            fullName: profile.fullName.trim().isEmpty
                ? existing.fullName
                : profile.fullName,
            email: profile.email.trim().isEmpty
                ? existing.email
                : profile.email,
            cityOrArea: profile.cityOrArea.trim().isEmpty
                ? existing.cityOrArea
                : profile.cityOrArea,
            primaryCategory: profile.primaryCategory.trim().isEmpty
                ? existing.primaryCategory
                : profile.primaryCategory,
            services: profile.services.isEmpty
                ? existing.services
                : profile.services,
            languages: profile.languages.isEmpty
                ? existing.languages
                : profile.languages,
            about: profile.about.trim().isEmpty
                ? existing.about
                : profile.about,
            certificateDetails: profile.certificateDetails.trim().isEmpty
                ? existing.certificateDetails
                : profile.certificateDetails,
            profilePhotoPath:
                profile.profilePhotoPath ?? existing.profilePhotoPath,
            notificationsEnabled: existing.notificationsEnabled,
          );
    if (normalized.isEmpty) {
      throw ArgumentError.value(profile.mobile, 'mobile', 'Mobile is required');
    }
    final withPhoto = profilePhotoBytes == null
        ? saved
        : saved.copyWith(
            profilePhotoPath: await savePhoto(
              profile.mobile,
              profilePhotoBytes,
            ),
          );
    await save(withPhoto);
    return withPhoto;
  }
}

class WorkerProfileStore {
  WorkerProfileStore._();

  static final WorkerProfileRepository repository = WorkerProfileRepository(
    SecureWorkerProfileStorage(),
  );
}
