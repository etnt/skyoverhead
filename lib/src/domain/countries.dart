/// A static ICAO location-prefix → country map used to derive a **Countries**
/// collection from airport ICAO codes, without any new network calls.
///
/// ICAO airport identifiers begin with a region/country prefix: most countries
/// use a two-letter prefix (e.g. `ED` Germany, `ES` Sweden, `EG` United
/// Kingdom), while a few large countries use a single letter (e.g. `K` United
/// States, `C` Canada, `Y` Australia). [countryForIcao] resolves a code by
/// trying the two-letter prefix first, then the single-letter fallback.
///
/// The map is intentionally partial — unknown prefixes simply resolve to
/// `null` and contribute nothing to the collection.
library;

/// Two-letter ICAO prefixes → country name.
const Map<String, String> kIcaoTwoLetterCountries = {
  // Europe (E…)
  'EB': 'Belgium',
  'ED': 'Germany',
  'EE': 'Estonia',
  'EF': 'Finland',
  'EG': 'United Kingdom',
  'EH': 'Netherlands',
  'EI': 'Ireland',
  'EK': 'Denmark',
  'EL': 'Luxembourg',
  'EN': 'Norway',
  'EP': 'Poland',
  'ES': 'Sweden',
  'ET': 'Germany',
  'EV': 'Latvia',
  'EY': 'Lithuania',
  // Europe / Mediterranean (L…)
  'LA': 'Albania',
  'LB': 'Bulgaria',
  'LC': 'Cyprus',
  'LD': 'Croatia',
  'LE': 'Spain',
  'LF': 'France',
  'LG': 'Greece',
  'LH': 'Hungary',
  'LI': 'Italy',
  'LJ': 'Slovenia',
  'LK': 'Czechia',
  'LM': 'Malta',
  'LN': 'Monaco',
  'LO': 'Austria',
  'LP': 'Portugal',
  'LR': 'Romania',
  'LS': 'Switzerland',
  'LT': 'Türkiye',
  'LU': 'Moldova',
  'LW': 'North Macedonia',
  'LX': 'Gibraltar',
  'LY': 'Serbia',
  'LZ': 'Slovakia',
  // Middle East / West Asia (O…)
  'OA': 'Afghanistan',
  'OB': 'Bahrain',
  'OE': 'Saudi Arabia',
  'OI': 'Iran',
  'OJ': 'Jordan',
  'OK': 'Kuwait',
  'OL': 'Lebanon',
  'OM': 'United Arab Emirates',
  'OO': 'Oman',
  'OP': 'Pakistan',
  'OR': 'Iraq',
  'OS': 'Syria',
  'OT': 'Qatar',
  // South & East Asia (V…, Z…, R…)
  'VA': 'India',
  'VE': 'India',
  'VI': 'India',
  'VO': 'India',
  'VC': 'Sri Lanka',
  'VD': 'Cambodia',
  'VG': 'Bangladesh',
  'VH': 'Hong Kong',
  'VL': 'Laos',
  'VM': 'Macau',
  'VN': 'Nepal',
  'VR': 'Maldives',
  'VT': 'Thailand',
  'VV': 'Vietnam',
  'VY': 'Myanmar',
  'RC': 'Taiwan',
  'RJ': 'Japan',
  'RK': 'South Korea',
  'RO': 'Japan',
  'RP': 'Philippines',
  'WA': 'Indonesia',
  'WI': 'Indonesia',
  'WM': 'Malaysia',
  'WS': 'Singapore',
  'WB': 'Brunei',
  // Africa (D…, F…, G…, H…)
  'DA': 'Algeria',
  'DN': 'Nigeria',
  'DT': 'Tunisia',
  'FA': 'South Africa',
  'FC': 'Republic of the Congo',
  'FL': 'Zambia',
  'FN': 'Angola',
  'FQ': 'Mozambique',
  'FV': 'Zimbabwe',
  'FW': 'Malawi',
  'FY': 'Namibia',
  'GC': 'Spain',
  'GM': 'Morocco',
  'GO': 'Senegal',
  'HA': 'Ethiopia',
  'HE': 'Egypt',
  'HK': 'Kenya',
  'HT': 'Tanzania',
  'HU': 'Uganda',
  // Central / South America (M…, S…, T…)
  'MB': 'Turks and Caicos',
  'MD': 'Dominican Republic',
  'MG': 'Guatemala',
  'MK': 'Jamaica',
  'MM': 'Mexico',
  'MP': 'Panama',
  'MR': 'Costa Rica',
  'MT': 'Haiti',
  'MU': 'Cuba',
  'MW': 'Cayman Islands',
  'MY': 'Bahamas',
  'MZ': 'Belize',
  'SA': 'Argentina',
  'SB': 'Brazil',
  'SC': 'Chile',
  'SE': 'Ecuador',
  'SG': 'Paraguay',
  'SK': 'Colombia',
  'SL': 'Bolivia',
  'SM': 'Suriname',
  'SP': 'Peru',
  'SU': 'Uruguay',
  'SV': 'Venezuela',
  'TA': 'Antigua and Barbuda',
  'TB': 'Barbados',
  'TJ': 'Puerto Rico',
  'TT': 'Trinidad and Tobago',
  // Oceania / Pacific (N…)
  'NF': 'Fiji',
  'NS': 'Samoa',
  'NV': 'Vanuatu',
  'NZ': 'New Zealand',
  // Former USSR / Central Asia (U…)
  'UA': 'Kazakhstan',
  'UB': 'Azerbaijan',
  'UD': 'Armenia',
  'UG': 'Georgia',
  'UK': 'Ukraine',
  'UM': 'Belarus',
  'UT': 'Uzbekistan',
};

/// Single-letter ICAO prefixes → country, used when no two-letter match exists.
const Map<String, String> kIcaoSingleLetterCountries = {
  'K': 'United States',
  'C': 'Canada',
  'Y': 'Australia',
  'Z': 'China',
  'U': 'Russia',
};

/// Resolve the country for an ICAO airport code, or `null` if unknown/blank.
String? countryForIcao(String? icao) {
  if (icao == null) return null;
  final code = icao.trim().toUpperCase();
  if (code.length < 2) return null;
  final two = kIcaoTwoLetterCountries[code.substring(0, 2)];
  if (two != null) return two;
  return kIcaoSingleLetterCountries[code.substring(0, 1)];
}
