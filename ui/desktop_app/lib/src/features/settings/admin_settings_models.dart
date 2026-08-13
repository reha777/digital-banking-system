class AdminSettings {
  const AdminSettings({
    required this.system,
    required this.preferences,
    required this.profile,
  });
  final SystemSettings system;
  final AdminPreferences preferences;
  final AdminProfile profile;
  factory AdminSettings.fromJson(Map<String, dynamic> json) => AdminSettings(
    system: SystemSettings.fromJson(json['system'] as Map<String, dynamic>),
    preferences: AdminPreferences.fromJson(
      json['preferences'] as Map<String, dynamic>,
    ),
    profile: AdminProfile.fromJson(json['profile'] as Map<String, dynamic>),
  );
}

class SystemSettings {
  const SystemSettings({
    required this.systemName,
    required this.systemShortName,
    required this.companyName,
    required this.companyEmail,
    required this.companyPhone,
    required this.timezone,
    required this.sessionTimeoutMinutes,
    required this.autoLogoutWarningMinutes,
    required this.enableDataCaching,
    required this.updatedAtUtc,
  });
  final String systemName,
      systemShortName,
      companyName,
      companyEmail,
      companyPhone,
      timezone;
  final int sessionTimeoutMinutes, autoLogoutWarningMinutes;
  final bool enableDataCaching;
  final DateTime? updatedAtUtc;
  factory SystemSettings.fromJson(Map<String, dynamic> j) => SystemSettings(
    systemName: j['systemName'].toString(),
    systemShortName: j['systemShortName'].toString(),
    companyName: j['companyName'].toString(),
    companyEmail: j['companyEmail'].toString(),
    companyPhone: j['companyPhone'].toString(),
    timezone: j['timezone'].toString(),
    sessionTimeoutMinutes: j['sessionTimeoutMinutes'] as int,
    autoLogoutWarningMinutes: j['autoLogoutWarningMinutes'] as int,
    enableDataCaching: j['enableDataCaching'] as bool,
    updatedAtUtc: DateTime.tryParse(j['updatedAtUtc']?.toString() ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'systemName': systemName,
    'systemShortName': systemShortName,
    'companyName': companyName,
    'companyEmail': companyEmail,
    'companyPhone': companyPhone,
    'timezone': timezone,
    'sessionTimeoutMinutes': sessionTimeoutMinutes,
    'autoLogoutWarningMinutes': autoLogoutWarningMinutes,
    'enableDataCaching': enableDataCaching,
  };
}

class AdminPreferences {
  const AdminPreferences({
    required this.themeMode,
    required this.sidebarStyle,
    required this.dateFormat,
    required this.timeFormat,
    required this.firstDayOfWeek,
    required this.numberFormat,
    required this.defaultItemsPerPage,
    required this.timezone,
  });
  final String themeMode,
      sidebarStyle,
      dateFormat,
      timeFormat,
      firstDayOfWeek,
      numberFormat;
  final int defaultItemsPerPage;
  final String timezone;
  factory AdminPreferences.fromJson(Map<String, dynamic> j) => AdminPreferences(
    themeMode: j['themeMode'].toString(),
    sidebarStyle: j['sidebarStyle'].toString(),
    dateFormat: j['dateFormat'].toString(),
    timeFormat: j['timeFormat'].toString(),
    firstDayOfWeek: j['firstDayOfWeek'].toString(),
    numberFormat: j['numberFormat'].toString(),
    defaultItemsPerPage: j['defaultItemsPerPage'] as int,
    timezone: j['timezone']?.toString() ?? 'Europe/Sarajevo',
  );
  Map<String, dynamic> toJson() => {
    'themeMode': themeMode,
    'sidebarStyle': sidebarStyle,
    'dateFormat': dateFormat,
    'timeFormat': timeFormat,
    'firstDayOfWeek': firstDayOfWeek,
    'numberFormat': numberFormat,
    'defaultItemsPerPage': defaultItemsPerPage,
    'timezone': timezone,
  };
}

class AdminProfile {
  const AdminProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
  });
  final String firstName, lastName, email, phoneNumber;
  factory AdminProfile.fromJson(Map<String, dynamic> j) => AdminProfile(
    firstName: j['firstName'].toString(),
    lastName: j['lastName'].toString(),
    email: j['email'].toString(),
    phoneNumber: j['phoneNumber'].toString(),
  );
  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'phoneNumber': phoneNumber,
  };
}
