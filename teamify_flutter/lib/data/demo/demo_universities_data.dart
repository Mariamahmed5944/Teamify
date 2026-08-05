import 'package:flutter/foundation.dart';
import '../models/university_option_model.dart';

/// Centralized expanded catalog of Egyptian higher-education institutions.
final List<UniversityOption> staticEgyptianUniversities = [
  // ── Public Universities ───────────────────────────────────────────────────
  UniversityOption.create(
    id: 'uni_al_azhar',
    name: 'Al-Azhar University',
    city: 'Cairo',
    type: 'Public',
    aliases: ['Azhar', 'Al Azhar'],
  ),
  UniversityOption.create(
    id: 'uni_alex',
    name: 'Alexandria University',
    city: 'Alexandria',
    type: 'Public',
    aliases: ['AlexU', 'Alexandria'],
  ),
  UniversityOption.create(
    id: 'uni_ain_shams',
    name: 'Ain Shams University',
    city: 'Cairo',
    type: 'Public',
    aliases: ['ASU', 'Ain Shams'],
  ),
  UniversityOption.create(
    id: 'uni_arish',
    name: 'Arish University',
    city: 'Arish',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_assiut',
    name: 'Assiut University',
    city: 'Assiut',
    type: 'Public',
    aliases: ['Assiut'],
  ),
  UniversityOption.create(
    id: 'uni_aswan',
    name: 'Aswan University',
    city: 'Aswan',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_benha',
    name: 'Benha University',
    city: 'Benha',
    type: 'Public',
    aliases: ['BU', 'Benha'],
  ),
  UniversityOption.create(
    id: 'uni_beni_suef',
    name: 'Beni-Suef University',
    city: 'Beni-Suef',
    type: 'Public',
    aliases: ['BSU'],
  ),
  UniversityOption.create(
    id: 'uni_cairo',
    name: 'Cairo University',
    city: 'Giza',
    type: 'Public',
    aliases: ['CU', 'Cairo'],
  ),
  UniversityOption.create(
    id: 'uni_damanhour',
    name: 'Damanhour University',
    city: 'Damanhour',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_damietta',
    name: 'Damietta University',
    city: 'Damietta',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_fayoum',
    name: 'Fayoum University',
    city: 'Fayoum',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_helwan',
    name: 'Helwan University',
    city: 'Cairo',
    type: 'Public',
    aliases: ['HU', 'Helwan'],
  ),
  UniversityOption.create(
    id: 'uni_kafrelsheikh',
    name: 'Kafrelsheikh University',
    city: 'Kafr El Sheikh',
    type: 'Public',
    aliases: ['KFS'],
  ),
  UniversityOption.create(
    id: 'uni_luxor',
    name: 'Luxor University',
    city: 'Luxor',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_mansoura',
    name: 'Mansoura University',
    city: 'Mansoura',
    type: 'Public',
    aliases: ['MU', 'Mansoura'],
  ),
  UniversityOption.create(
    id: 'uni_matrouh',
    name: 'Matrouh University',
    city: 'Matrouh',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_menofia',
    name: 'Menoufia University',
    city: 'Shibin El Kom',
    type: 'Public',
    aliases: ['Menoufia'],
  ),
  UniversityOption.create(
    id: 'uni_minia',
    name: 'Minia University',
    city: 'Minia',
    type: 'Public',
    aliases: ['Minia'],
  ),
  UniversityOption.create(
    id: 'uni_new_valley',
    name: 'New Valley University',
    city: 'Kharga',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_port_said',
    name: 'Port Said University',
    city: 'Port Said',
    type: 'Public',
    aliases: ['PSU'],
  ),
  UniversityOption.create(
    id: 'uni_sadat_city',
    name: 'Sadat City University',
    city: 'Sadat City',
    type: 'Public',
    aliases: ['USC'],
  ),
  UniversityOption.create(
    id: 'uni_sohag',
    name: 'Sohag University',
    city: 'Sohag',
    type: 'Public',
    aliases: ['Sohag'],
  ),
  UniversityOption.create(
    id: 'uni_south_valley',
    name: 'South Valley University',
    city: 'Qena',
    type: 'Public',
    aliases: ['SVU'],
  ),
  UniversityOption.create(
    id: 'uni_suez',
    name: 'Suez University',
    city: 'Suez',
    type: 'Public',
  ),
  UniversityOption.create(
    id: 'uni_suez_canal',
    name: 'Suez Canal University',
    city: 'Ismailia',
    type: 'Public',
    aliases: ['SCU'],
  ),
  UniversityOption.create(
    id: 'uni_tanta',
    name: 'Tanta University',
    city: 'Tanta',
    type: 'Public',
    aliases: ['Tanta'],
  ),
  UniversityOption.create(
    id: 'uni_zagazig',
    name: 'Zagazig University',
    city: 'Zagazig',
    type: 'Public',
    aliases: ['ZU', 'Zagazig'],
  ),

  // ── Private Universities ──────────────────────────────────────────────────
  UniversityOption.create(
    id: 'uni_acu',
    name: 'Ahram Canadian University',
    city: '6th of October',
    type: 'Private',
    aliases: ['ACU'],
  ),
  UniversityOption.create(
    id: 'uni_badr',
    name: 'Badr University in Cairo',
    city: 'Badr City',
    type: 'Private',
    aliases: ['BUC'],
  ),
  UniversityOption.create(
    id: 'uni_delta_private',
    name: 'Delta University for Science and Technology',
    city: 'Gamasa',
    type: 'Private',
    aliases: ['DUST'],
  ),
  UniversityOption.create(
    id: 'uni_deraya',
    name: 'Deraya University',
    city: 'Minia',
    type: 'Private',
  ),
  UniversityOption.create(
    id: 'uni_ecu',
    name: 'Egyptian Chinese University',
    city: 'Cairo',
    type: 'Private',
    aliases: ['ECU'],
  ),
  UniversityOption.create(
    id: 'uni_eru',
    name: 'Egyptian Russian University',
    city: 'Badr City',
    type: 'Private',
    aliases: ['ERU'],
  ),
  UniversityOption.create(
    id: 'uni_fue',
    name: 'Future University in Egypt',
    city: 'New Cairo',
    type: 'Private',
    aliases: ['FUE', 'Future University'],
  ),
  UniversityOption.create(
    id: 'uni_guc',
    name: 'German University in Cairo',
    city: 'New Cairo',
    type: 'Private',
    aliases: ['GUC', 'German University'],
  ),
  UniversityOption.create(
    id: 'uni_heliopolis',
    name: 'Heliopolis University',
    city: 'Cairo',
    type: 'Private',
    aliases: ['HU'],
  ),
  UniversityOption.create(
    id: 'uni_horus',
    name: 'Horus University',
    city: 'New Damietta',
    type: 'Private',
    aliases: ['HUE'],
  ),
  UniversityOption.create(
    id: 'uni_may',
    name: 'May University in Cairo',
    city: '15th of May City',
    type: 'Private',
  ),
  UniversityOption.create(
    id: 'uni_merit',
    name: 'Merit University',
    city: 'Sohag',
    type: 'Private',
  ),
  UniversityOption.create(
    id: 'uni_miu',
    name: 'Misr International University',
    city: 'Obour City',
    type: 'Private',
    aliases: ['MIU'],
  ),
  UniversityOption.create(
    id: 'uni_must',
    name: 'Misr University for Science and Technology',
    city: '6th of October',
    type: 'Private',
    aliases: ['MUST'],
  ),
  UniversityOption.create(
    id: 'uni_msa',
    name: 'Modern Sciences and Arts University',
    city: '6th of October',
    type: 'Private',
    aliases: ['MSA', 'October University for Sciences and Arts'],
  ),
  UniversityOption.create(
    id: 'uni_nahda',
    name: 'Nahda University',
    city: 'Beni Suef',
    type: 'Private',
    aliases: ['NUB'],
  ),
  UniversityOption.create(
    id: 'uni_new_giza',
    name: 'New Giza University',
    city: 'Giza',
    type: 'Private',
    aliases: ['NGU', 'Newgiza University'],
  ),
  UniversityOption.create(
    id: 'uni_new_salhia',
    name: 'New Salhia University',
    city: 'Salhia',
    type: 'Private',
  ),
  UniversityOption.create(
    id: 'uni_nile',
    name: 'Nile University',
    city: 'Sheikh Zayed',
    type: 'Private',
    aliases: ['NU', 'Nile'],
  ),
  UniversityOption.create(
    id: 'uni_o6u',
    name: 'October 6 University',
    city: '6th of October',
    type: 'Private',
    aliases: ['O6U', '6th of October University'],
  ),
  UniversityOption.create(
    id: 'uni_pharos',
    name: 'Pharos University in Alexandria',
    city: 'Alexandria',
    type: 'Private',
    aliases: ['PUA'],
  ),
  UniversityOption.create(
    id: 'uni_sinai',
    name: 'Sinai University',
    city: 'Arish & Qantara',
    type: 'Private',
    aliases: ['SU'],
  ),
  UniversityOption.create(
    id: 'uni_sphinx',
    name: 'Sphinx University',
    city: 'Assiut',
    type: 'Private',
  ),
  UniversityOption.create(
    id: 'uni_auc',
    name: 'The American University in Cairo',
    city: 'New Cairo',
    type: 'Private',
    aliases: ['AUC', 'American University in Cairo'],
  ),
  UniversityOption.create(
    id: 'uni_bue',
    name: 'The British University in Egypt',
    city: 'El Sherouk',
    type: 'Private',
    aliases: ['BUE', 'British University in Egypt'],
  ),

  // ── National & Non-Profit Universities ───────────────────────────────────
  UniversityOption.create(
    id: 'uni_ain_shams_national',
    name: 'Ain Shams National University',
    city: 'Obour City',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_alamein',
    name: 'Alamein International University',
    city: 'New Alamein',
    type: 'National',
    aliases: ['AIU'],
  ),
  UniversityOption.create(
    id: 'uni_alex_national',
    name: 'Alexandria National University',
    city: 'Alexandria',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_assiut_national',
    name: 'Assiut National University',
    city: 'Assiut',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_benha_national',
    name: 'Benha National University',
    city: 'Obour City',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_beni_suef_national',
    name: 'Beni-Suef National University',
    city: 'Beni Suef',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_cairo_national',
    name: 'Cairo National University',
    city: '6th of October',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_east_port_said_national',
    name: 'East Port Said National University',
    city: 'Port Said',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_eui',
    name: 'Egypt University of Informatics',
    city: 'New Capital',
    type: 'National',
    aliases: ['EUI'],
  ),
  UniversityOption.create(
    id: 'uni_galala',
    name: 'Galala University',
    city: 'Galala',
    type: 'National',
    aliases: ['GU'],
  ),
  UniversityOption.create(
    id: 'uni_helwan_national',
    name: 'Helwan National University',
    city: 'Helwan',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_ismailia_national',
    name: 'Ismailia National University',
    city: 'Ismailia',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_king_salman',
    name: 'King Salman International University',
    city: 'South Sinai',
    type: 'National',
    aliases: ['KSIU'],
  ),
  UniversityOption.create(
    id: 'uni_mansoura_national',
    name: 'Mansoura National University',
    city: 'Mansoura',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_menofia_national',
    name: 'Menoufia National University',
    city: 'Shibin El Kom',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_minya_national',
    name: 'Minya National University',
    city: 'Minia',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_new_mansoura',
    name: 'New Mansoura University',
    city: 'New Mansoura',
    type: 'National',
    aliases: ['NMU'],
  ),
  UniversityOption.create(
    id: 'uni_south_valley_national',
    name: 'South Valley National University',
    city: 'Qena',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_suez_canal_national',
    name: 'Suez Canal National University',
    city: 'Ismailia',
    type: 'National',
  ),
  UniversityOption.create(
    id: 'uni_zagazig_national',
    name: 'Zagazig National University',
    city: 'Zagazig',
    type: 'National',
  ),

  // ── Technological Universities ────────────────────────────────────────────
  UniversityOption.create(
    id: 'uni_october_tech',
    name: '6th of October Technological University',
    city: '6th of October',
    type: 'Technological',
  ),
  UniversityOption.create(
    id: 'uni_assiut_new_tech',
    name: 'Assiut New Technological University',
    city: 'New Assiut',
    type: 'Technological',
  ),
  UniversityOption.create(
    id: 'uni_beni_suef_tech',
    name: 'Beni-Suef Technological University',
    city: 'Beni Suef',
    type: 'Technological',
    aliases: ['BSTU'],
  ),
  UniversityOption.create(
    id: 'uni_borg_el_arab_tech',
    name: 'Borg El Arab Technological University',
    city: 'Borg El Arab',
    type: 'Technological',
  ),
  UniversityOption.create(
    id: 'uni_delta_tech',
    name: 'Delta Technological University',
    city: 'Qwesna',
    type: 'Technological',
    aliases: ['DTU'],
  ),
  UniversityOption.create(
    id: 'uni_east_port_said_tech',
    name: 'East Port Said Technological University',
    city: 'Port Said',
    type: 'Technological',
  ),
  UniversityOption.create(
    id: 'uni_cairo_tech',
    name: 'New Cairo Technological University',
    city: 'New Cairo',
    type: 'Technological',
    aliases: ['NCTU'],
  ),
  UniversityOption.create(
    id: 'uni_new_valley_tech',
    name: 'New Valley Technological University',
    city: 'New Valley',
    type: 'Technological',
  ),
  UniversityOption.create(
    id: 'uni_samannoud_tech',
    name: 'Samannoud Technological University',
    city: 'Gharbia',
    type: 'Technological',
  ),
  UniversityOption.create(
    id: 'uni_thebes_tech',
    name: 'Thebes Technological University',
    city: 'Luxor',
    type: 'Technological',
  ),

  // ── International Branch Campuses & Hosted ────────────────────────────────
  UniversityOption.create(
    id: 'uni_coventry_tkh',
    name: 'Coventry University hosted by The Knowledge Hub',
    city: 'New Capital',
    type: 'International',
    aliases: ['Coventry', 'TKH'],
  ),
  UniversityOption.create(
    id: 'uni_giu',
    name: 'German International University',
    city: 'New Capital',
    type: 'International',
    aliases: ['GIU'],
  ),
  UniversityOption.create(
    id: 'uni_nova_tkh',
    name: 'Nova University Lisbon hosted by The Knowledge Hub',
    city: 'New Capital',
    type: 'International',
    aliases: ['Nova Lisbon', 'TKH'],
  ),
  UniversityOption.create(
    id: 'uni_tmu_uofc',
    name: 'Toronto Metropolitan University hosted by Universities of Canada',
    city: 'New Capital',
    type: 'International',
    aliases: ['TMU', 'UofCanada'],
  ),
  UniversityOption.create(
    id: 'uni_ucl_tkh',
    name: 'University of Central Lancashire hosted by The Knowledge Hub',
    city: 'New Capital',
    type: 'International',
    aliases: ['UCLan', 'TKH'],
  ),
  UniversityOption.create(
    id: 'uni_hertfordshire_gaf',
    name: 'University of Hertfordshire hosted by GAF',
    city: 'New Capital',
    type: 'International',
    aliases: ['Hertfordshire', 'GAF'],
  ),
  UniversityOption.create(
    id: 'uni_uol_eue',
    name: 'University of London hosted by European Universities in Egypt',
    city: 'New Capital',
    type: 'International',
    aliases: ['UoL', 'EUE'],
  ),
  UniversityOption.create(
    id: 'uni_upei_uofc',
    name: 'University of Prince Edward Island hosted by Universities of Canada',
    city: 'New Capital',
    type: 'International',
    aliases: ['UPEI', 'UofCanada'],
  ),

  // Special "Other" option (always last)
  UniversityOption.create(id: 'uni_other', name: 'Other', isCustom: true),
];

/// Helper to sort and deduplicate built-in universities while ensuring "Other" remains last.
List<UniversityOption> getSortedDeduplicatedUniversities() {
  final Map<String, UniversityOption> uniqueMap = {};
  for (final uni in staticEgyptianUniversities) {
    if (uni.id == 'uni_other') continue;
    uniqueMap.putIfAbsent(uni.normalizedName, () => uni);
  }

  final sortedList = uniqueMap.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final other = staticEgyptianUniversities.firstWhere(
    (u) => u.id == 'uni_other',
    orElse: () => UniversityOption.create(id: 'uni_other', name: 'Other', isCustom: true),
  );

  sortedList.add(other);
  return sortedList;
}

/// In-memory session store for custom universities registered during runtime.
class DemoUniversityStore extends ChangeNotifier {
  static final DemoUniversityStore instance = DemoUniversityStore._();
  DemoUniversityStore._();

  final List<UniversityOption> _customUniversities = [];

  List<UniversityOption> get allUniversities {
    final sortedBuiltIns = getSortedDeduplicatedUniversities();
    final baseWithoutOther = sortedBuiltIns
        .where((u) => u.id != 'uni_other')
        .toList();
    final otherOption = sortedBuiltIns
        .firstWhere((u) => u.id == 'uni_other');

    return [
      ...baseWithoutOther,
      ..._customUniversities,
      otherOption,
    ];
  }

  /// Register or retrieve a custom university by display name.
  UniversityOption getOrCreateCustomUniversity(String customName) {
    final cleanedName = customName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final norm = UniversityOption.normalizeUniversityName(cleanedName);

    // Check if matching custom university already exists in session
    final existingCustom = _customUniversities.firstWhere(
      (u) => u.normalizedName == norm,
      orElse: () => const UniversityOption(id: '', name: '', normalizedName: ''),
    );

    if (existingCustom.id.isNotEmpty) {
      return existingCustom;
    }

    // Check if matching static university exists
    final existingStatic = staticEgyptianUniversities.firstWhere(
      (u) => u.normalizedName == norm,
      orElse: () => const UniversityOption(id: '', name: '', normalizedName: ''),
    );

    if (existingStatic.id.isNotEmpty) {
      return existingStatic;
    }

    // Create new custom university for session
    final newCustom = UniversityOption.create(
      id: 'custom_uni_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanedName,
      isCustom: true,
    );

    _customUniversities.add(newCustom);
    notifyListeners();
    return newCustom;
  }
}
