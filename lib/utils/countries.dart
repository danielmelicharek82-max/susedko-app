library countries;

/// Predvolený buyer country code
const String defaultBuyerCountryCode = 'SK';

/// 🌍 Mapa názvov krajín na ISO kódy
const Map<String, String> countryMap = {
  'Afghanistan': 'AF',
  'Albania': 'AL',
  'Algeria': 'DZ',
  'Andorra': 'AD',
  'Angola': 'AO',
  'Argentina': 'AR',
  'Armenia': 'AM',
  'Australia': 'AU',
  'Austria': 'AT',
  'Azerbaijan': 'AZ',
  'Bahamas': 'BS',
  'Bahrain': 'BH',
  'Bangladesh': 'BD',
  'Barbados': 'BB',
  'Belarus': 'BY',
  'Belgium': 'BE',
  'Belize': 'BZ',
  'Benin': 'BJ',
  'Bhutan': 'BT',
  'Bolivia': 'BO',
  'Bosnia and Herzegovina': 'BA',
  'Botswana': 'BW',
  'Brazil': 'BR',
  'Brunei': 'BN',
  'Bulgaria': 'BG',
  'Burkina Faso': 'BF',
  'Burundi': 'BI',
  'Cabo Verde': 'CV',
  'Cambodia': 'KH',
  'Cameroon': 'CM',
  'Canada': 'CA',
  'Central African Republic': 'CF',
  'Chad': 'TD',
  'Chile': 'CL',
  'China': 'CN',
  'Colombia': 'CO',
  'Comoros': 'KM',
  'Congo (Congo-Brazzaville)': 'CG',
  'Costa Rica': 'CR',
  'Croatia': 'HR',
  'Cuba': 'CU',
  'Cyprus': 'CY',
  'Czech Republic': 'CZ',
  'Denmark': 'DK',
  'Djibouti': 'DJ',
  'Dominica': 'DM',
  'Dominican Republic': 'DO',
  'Ecuador': 'EC',
  'Egypt': 'EG',
  'El Salvador': 'SV',
  'Equatorial Guinea': 'GQ',
  'Eritrea': 'ER',
  'Estonia': 'EE',
  'Eswatini': 'SZ',
  'Ethiopia': 'ET',
  'Fiji': 'FJ',
  'Finland': 'FI',
  'France': 'FR',
  'Gabon': 'GA',
  'Gambia': 'GM',
  'Georgia': 'GE',
  'Germany': 'DE',
  'Ghana': 'GH',
  'Greece': 'GR',
  'Grenada': 'GD',
  'Guatemala': 'GT',
  'Guinea': 'GN',
  'Guinea-Bissau': 'GW',
  'Guyana': 'GY',
  'Haiti': 'HT',
  'Honduras': 'HN',
  'Hungary': 'HU',
  'Iceland': 'IS',
  'India': 'IN',
  'Indonesia': 'ID',
  'Iran': 'IR',
  'Iraq': 'IQ',
  'Ireland': 'IE',
  'Israel': 'IL',
  'Italy': 'IT',
  'Jamaica': 'JM',
  'Japan': 'JP',
  'Jordan': 'JO',
  'Kazakhstan': 'KZ',
  'Kenya': 'KE',
  'Kiribati': 'KI',
  'Kuwait': 'KW',
  'Kyrgyzstan': 'KG',
  'Laos': 'LA',
  'Latvia': 'LV',
  'Lebanon': 'LB',
  'Lesotho': 'LS',
  'Liberia': 'LR',
  'Libya': 'LY',
  'Liechtenstein': 'LI',
  'Lithuania': 'LT',
  'Luxembourg': 'LU',
  'Madagascar': 'MG',
  'Malawi': 'MW',
  'Malaysia': 'MY',
  'Maldives': 'MV',
  'Mali': 'ML',
  'Malta': 'MT',
  'Marshall Islands': 'MH',
  'Mauritania': 'MR',
  'Mauritius': 'MU',
  'Mexico': 'MX',
  'Micronesia': 'FM',
  'Moldova': 'MD',
  'Monaco': 'MC',
  'Mongolia': 'MN',
  'Montenegro': 'ME',
  'Morocco': 'MA',
  'Mozambique': 'MZ',
  'Myanmar': 'MM',
  'Namibia': 'NA',
  'Nauru': 'NR',
  'Nepal': 'NP',
  'Netherlands': 'NL',
  'New Zealand': 'NZ',
  'Nicaragua': 'NI',
  'Niger': 'NE',
  'Nigeria': 'NG',
  'North Korea': 'KP',
  'North Macedonia': 'MK',
  'Norway': 'NO',
  'Oman': 'OM',
  'Pakistan': 'PK',
  'Palau': 'PW',
  'Palestine': 'PS',
  'Panama': 'PA',
  'Papua New Guinea': 'PG',
  'Paraguay': 'PY',
  'Peru': 'PE',
  'Philippines': 'PH',
  'Poland': 'PL',
  'Portugal': 'PT',
  'Qatar': 'QA',
  'Romania': 'RO',
  'Russia': 'RU',
  'Rwanda': 'RW',
  'Saint Kitts and Nevis': 'KN',
  'Saint Lucia': 'LC',
  'Saint Vincent and the Grenadines': 'VC',
  'Samoa': 'WS',
  'San Marino': 'SM',
  'Sao Tome and Principe': 'ST',
  'Saudi Arabia': 'SA',
  'Senegal': 'SN',
  'Serbia': 'RS',
  'Seychelles': 'SC',
  'Sierra Leone': 'SL',
  'Singapore': 'SG',
  'Slovakia': 'SK',
  'Slovenia': 'SI',
  'Solomon Islands': 'SB',
  'Somalia': 'SO',
  'South Africa': 'ZA',
  'South Korea': 'KR',
  'South Sudan': 'SS',
  'Spain': 'ES',
  'Sri Lanka': 'LK',
  'Sudan': 'SD',
  'Suriname': 'SR',
  'Sweden': 'SE',
  'Switzerland': 'CH',
  'Syria': 'SY',
  'Taiwan': 'TW',
  'Tajikistan': 'TJ',
  'Tanzania': 'TZ',
  'Thailand': 'TH',
  'Timor-Leste': 'TL',
  'Togo': 'TG',
  'Tonga': 'TO',
  'Trinidad and Tobago': 'TT',
  'Tunisia': 'TN',
  'Turkey': 'TR',
  'Turkmenistan': 'TM',
  'Tuvalu': 'TV',
  'Uganda': 'UG',
  'Ukraine': 'UA',
  'United Arab Emirates': 'AE',
  'United Kingdom': 'GB',
  'United States': 'US',
  'Uruguay': 'UY',
  'Uzbekistan': 'UZ',
  'Vanuatu': 'VU',
  'Vatican City': 'VA',
  'Venezuela': 'VE',
  'Vietnam': 'VN',
  'Yemen': 'YE',
  'Zambia': 'ZM',
  'Zimbabwe': 'ZW',
};

/// 🌍 Európske krajiny (ISO kódy)
const Set<String> europeanCountries = {
  "AL","AD","AT","BY","BE","BA","BG","HR","CY","CZ","DK","EE",
  "FI","FR","DE","GR","HU","IS","IE","IT","XK","LV","LI","LT",
  "LU","MT","MD","MC","ME","NL","MK","NO","PL","PT","RO","RU",
  "SM","RS","SK","SI","ES","SE","CH","TR","UA","GB","VA",
};

/// 🇺🇸 Severna Amerika (ISO kódy)
const Set<String> northAmericanCountries = {
  "US","CA","MX","GT","BZ","CU","JM","TT","BS","BB"
};

/// 🇸🇪 Južna Amerika (ISO kódy)
const Set<String> southAmericanCountries = {
  "BR","AR","CL","CO","PE","VE","UY","PY","BO","GY","SR","EC","PA","DO"
};

/// 🇨🇳 Ázijské krajiny (ISO kódy)
const Set<String> asianCountries = {
  "AF","AM","AZ","BH","BD","BT","BN","KH","CN","CY","GE","IN","ID","IR","IQ","IL","JP","JO","KZ","KW","KG","LA","LB","MY","MV","MN","MM","NP","KP","OM","PK","PH","QA","SA","SG","KR","LK","SY","TW","TJ","TH","TL","TM","AE","UZ","VN","YE"
};

/// 🐨 Oceánia (ISO kódy)
const Set<String> oceaniaCountries = {
  "AU","NZ","FJ","PG","SB","VU","WS","TO","NR","PW","FM","MH","TV","KI"
};

/// 🌍 Africké krajiny (ISO kódy)
const Set<String> africanCountries = {
  "DZ","AO","BJ","BW","BF","BI","CV","CM","CF","TD","KM","CG","CD","DJ","EG","GQ","ER","ET","GA","GM","GH","GN","GW","KE","LS","LR","LY","MG","MW","ML","MR","MU","MA","MZ","NA","NE","NG","RW","ST","SN","SC","SL","SO","ZA","SS","SD","TZ","TG","TN","UG","ZM","ZW"
};

/// 🗺️ Susedné krajiny (ISO kódy)
const Map<String, List<String>> neighbourMap = {
  // Europa
  "AT": ["DE", "CZ", "SK", "HU", "LI", "CH"],
  "BE": ["FR", "DE", "NL", "LU"],
  "BG": ["RO", "GR", "MK", "TR", "RS"],
  "HR": ["SI", "HU", "BA", "RS", "ME"],
  "CY": [],
  "CZ": ["DE", "PL", "SK", "AT"],
  "DK": ["DE"],
  "EE": ["LV", "RU"],
  "FI": ["SE", "NO", "RU"],
  "FR": ["BE", "DE", "LU", "ES", "IT", "CH"],
  "DE": ["DK", "PL", "CZ", "NL", "BE", "LU", "CH", "AT"],
  "GR": ["BG", "MK", "AL", "TR"],
  "HU": ["SK", "AT", "RO", "RS", "HR", "SI"],
  "IE": ["GB"],
  "IT": ["FR", "CH", "AT", "SI", "SM", "VA"],
  "LV": ["EE", "LT", "RU", "BY"],
  "LT": ["LV", "PL", "BY", "RU"],
  "LU": ["BE", "FR", "DE"],
  "MT": [],
  "NL": ["BE", "DE"],
  "PL": ["DE", "CZ", "SK", "LT", "BY"],
  "PT": ["ES"],
  "RO": ["BG", "HU", "RS", "MD", "UA"],
  "SK": ["CZ", "PL", "HU", "AT"],
  "SI": ["IT", "AT", "HU", "HR"],
  "ES": ["PT", "FR", "AD"],
  "SE": ["NO", "FI"],
  "GB": ["IE"],
  "UA": ["PL", "SK", "HU", "RO", "BY", "MD", "RU"],
  "CH": ["DE", "FR", "IT", "AT", "LI"],
  "TR": ["BG", "GR", "GE", "AM", "IR", "IQ", "SY", "CY", "RO", "MK"],
  "LI": ["CH", "AT"],

// Severná Amerika / Stredná Amerika / Karibik
  "US": ["CA", "MX"],
  "CA": ["US"],
  "MX": ["US", "GT", "BZ"],
  "GT": ["MX", "BZ", "HN", "SV"],
  "BZ": ["MX", "GT"],
  "HN": ["GT", "SV"],
  "SV": ["GT", "HN"],
  "NI": ["CR"],
  "CR": ["NI", "PA"],
  "PA": ["CR"],
  "CU": [],
  "JM": [],
  "TT": [],
  "BS": [],
  "BB": [],
  "DO": ["HT"],
  "HT": ["DO"],
  "PR": ["DO"],

// Južná Amerika
  "BR": ["AR", "PE", "CO", "VE", "UY", "PY", "BO", "GY", "SR", "GF"],
  "AR": ["CL", "BO", "PY", "UY", "BR"],
  "CL": ["AR", "PE", "BO"],
  "CO": ["BR", "VE", "PE", "EC"],
  "PE": ["EC", "CO", "CL", "BO", "BR"],
  "VE": ["BR", "CO", "GY"],
  "UY": ["AR", "BR", "PY"],
  "PY": ["AR", "BR", "BO", "UY"],
  "BO": ["AR", "BR", "CL"],
  "GY": ["BR", "VE", "SR"],
  "SR": ["BR", "GY", "GF"],
  "EC": ["PE", "CO"],
  "GF": ["BR", "SR"],
// Asia
  "AF": ["TM", "UZ", "TJ", "PK", "IR", "CN"],            // Afganistan
  "AM": ["GE", "AZ", "TR", "IR"],                        // Arménsko
  "AZ": ["AM", "GE", "IR", "RU"],                        // Azerbajdžan
  "BH": [],                                              // Bahrajn (ostrov)
  "BD": ["IN", "MM"],                                    // Bangladéš
  "BT": ["CN", "IN"],                                    // Bhután
  "BN": ["MY"],                                          // Brunej
  "KH": ["TH", "LA", "VN"],                              // Kambodža
  "CN": ["MN", "RU", "KP", "VN", "LA", "BT", "IN", "PK", "MM"], // Čína

  "GE": ["RU", "AM", "AZ", "TR"],                        // Gruzínsko
  "IN": ["PK", "CN", "NP", "BT", "MM", "LK"],           // India
  "ID": ["MY", "TL", "PG"],                              // Indonézia
  "IR": ["IQ", "TR", "AM", "AZ", "PK", "AF"],            // Irán
  "IQ": ["SY", "TR", "IR", "JO", "KW", "SA"],           // Irak
  "IL": ["EG", "JO", "SY"],                              // Izrael
  "JP": [],                                              // Japonsko (ostrov)
  "JO": ["SY", "IQ", "SA", "IL"],                        // Jordánsko
  "KZ": ["RU", "CN", "KG", "UZ", "TM"],                  // Kazachstan
  "KW": ["IQ", "SA"],                                    // Kuvajt
  "KG": ["KZ", "UZ", "TJ", "CN"],                        // Kirgizsko
  "LA": ["CN", "VN", "KH", "TH"],                        // Laos
  "LB": ["SY", "IL"],                                    // Libanon
  "MY": ["SG", "TH", "BN"],                              // Malajzia
  "MV": [],                                              // Maledivy (ostrov)
  "MN": ["RU", "CN"],                                    // Mongolsko
  "MM": ["CN", "IN", "BD", "LA", "TH"],                 // Mjanmarsko
  "NP": ["CN", "IN"],                                    // Nepál
  "KP": ["CN", "KR", "RU"],                              // Severná Kórea
  "OM": ["SA", "YE", "AE"],                               // Omán
  "PK": ["AF", "IN", "IR", "CN"],                        // Pakistan
  "PH": [],                                              // Filipíny (ostrov)
  "QA": ["SA"],                                          // Katar
  "SA": ["YE", "OM", "AE", "IQ", "KW"],                  // Saudská Arábia
  "SG": ["MY"],                                          // Singapur
  "KR": ["KP"],                                          // Južná Kórea
  "LK": ["IN"],                                          // Srí Lanka
  "SY": ["TR", "IQ", "JO", "IL", "LB"],                 // Sýria
  "TW": [],                                              // Taiwan (ostrov)
  "TJ": ["AF", "UZ", "KG", "CN"],                        // Tadžikistan
  "TH": ["MM", "LA", "KH", "MY"],                        // Thajsko
  "TL": ["ID"],                                          // Východný Timor
  "TM": ["AF", "UZ", "KZ", "IR"],                        // Turkménsko
  "AE": ["SA", "OM"],                                    // Spojené arabské emiráty
  "UZ": ["KZ", "KG", "TJ", "AF", "TM"],                 // Uzbekistan
  "VN": ["CN", "LA", "KH"],                              // Vietnam
  "YE": ["SA", "OM"],                                    // Jemen
// Oceania (ISO kódy)
"AU": ["NZ", "FJ", "PG"],       // Austrália susedí s Nový Zéland, Fidži, Papua Nová Guinea
"NZ": ["AU", "FJ", "WS"],       // Nový Zéland susedí s Austrália, Fidži, Samoa
"FJ": ["AU", "NZ", "PG"],       // Fidži susedí s Austrália, Nový Zéland, Papua Nová Guinea
"PG": ["AU", "FJ", "SB"],       // Papua Nová Guinea susedí s Austrália, Fidži, Šalamúnove ostrovy
"SB": ["PG", "VU", "FJ"],       // Šalamúnove ostrovy susedí s Papua Nová Guinea, Vanuatu, Fidži
"VU": ["SB", "FJ", "WS"],       // Vanuatu susedí s Šalamúnove ostrovy, Fidži, Samoa
"WS": ["VU", "NZ"],              // Samoa susedí s Vanuatu, Nový Zéland
"TO": ["FJ", "WS"],              // Tonga susedí s Fidži, Samoa
"NR": ["AU", "FJ"],              // Nauru susedí s Austrália, Fidži
"PW": ["AU", "FJ"],              // Palau susedí s Austrália, Fidži
"FM": ["AU", "FJ"],              // Mikronézia susedí s Austrália, Fidži
"MH": ["FM", "PW"],              // Marshallove ostrovy susedí s Mikronézia, Palau
"TV": ["FJ", "VU"],              // Tuvalu susedí s Fidži, Vanuatu
"KI": ["FJ", "TV"],              // Kiribati susedí s Fidži, Tuvalu
  // Africa
  "DZ": ["TN","LY","NE","MR","EH","MA","TD","LY"],           // Alžírsko
  "AO": ["CD","CG","NA","ZM"],                               // Angola
  "BJ": ["NG","BF","NE","TG"],                               // Benin
  "BW": ["ZA","NA","ZW"],                                    // Botswana
  "BF": ["BJ","NE","ML","CI","GH","TG"],                     // Burkina Faso
  "BI": ["RW","TZ","CD"],                                    // Burundi
  "CV": [],                                                   // Cabo Verde (ostrov)
  "CM": ["NG","TD","CF","CG","GQ"],                          // Kamerun
  "CF": ["CM","TD","SD","SS","CD"],                          // Stredoafrická republika
  "TD": ["LY","NE","CM","CF","SD"],                          // Čad
  "KM": [],                                                   // Comory (ostrov)
  "CG": ["GA","CM","CD"],                                     // Kongo (Brazzaville)
  "CD": ["CG","CF","SS","UG","RW","TZ","BI","AO"],           // Kongo (Kinshasa)
  "DJ": ["ER","ET","SO"],                                     // Džibutsko
  "EG": ["LY","SD","IL"],                                     // Egypt
  "GQ": ["CM","GA"],                                         // Rovníková Guinea
  "ER": ["DJ","ET","SD"],                                     // Eritrea
  "SZ": ["ZA","MZ","LS"],                                     // Eswatini
  "ET": ["ER","DJ","SD","SS","KE","SO"],                      // Etiópia
  "GA": ["CG","GQ"],                                         // Gabon
  "GM": ["SN"],                                               // Gambia
  "GH": ["CI","BF","TG"],                                     // Ghana
  "GN": ["SN","CI","LR","SL"],                                // Guinea
  "GW": ["SN","GN"],                                         // Guinea-Bissau
  "CI": ["LR","GN","BF","GH","ML"],                           // Pobrežie Slonoviny
  "KE": ["UG","TZ","ET","SO","SS"],                           // Keňa
  "LS": ["ZA","SZ"],                                         // Lesotho
  "LR": ["SL","GN","CI"],                                     // Libéria
  "LY": ["TN","DZ","NE","SD","EG"],                           // Lýbia
  "MG": [],                                                   // Madagaskar (ostrov)
  "MW": ["TZ","ZM","MZ"],                                     // Malawi
  "ML": ["SN","MR","DZ","NE","BF","CI"],                      // Mali
  "MR": ["EH","DZ","ML","SN"],                                // Mauritánia
  "MU": [],                                                   // Maurícius (ostrov)
  "MA": ["DZ","EH","ES"],                                     // Maroko
  "MZ": ["TZ","ZM","ZW","ZA","MW"],                           // Mozambik
  "NA": ["ZA","BW","AO"],                                     // Namíbia
  "NE": ["DZ","LY","TD","BJ","BF","NG"],                      // Niger
  "NG": ["BJ","NE","CM"],                                     // Nigéria
  "RW": ["UG","TZ","BI","CD"],                                 // Rwanda
  "ST": [],                                                   // Sao Tome a Principe (ostrov)
  "SN": ["MR","ML","GN","GW","GM"],                           // Senegal
  "SC": [],                                                   // Seychely (ostrov)
  "SL": ["GN","LR"],                                         // Sierra Leone
  "SO": ["DJ","ET","KE","SS"],                                 // Somálsko
  "ZA": ["NA","ZW","BW","SZ","LS","MO"],                      // Južná Afrika
  "SS": ["SS","SD","ET","KE","UG","CD"],                       // Južný Sudán
  "SD": ["EG","LY","TD","CF","SS","ER","ET"],                 // Sudán
  "TZ": ["KE","UG","RW","BI","ZM","MW","CD"],                 // Tanzánia
  "TG": ["BJ","BF","GH"],                                     // Togo
  "TN": ["DZ","LY"],                                         // Tunisko
  "UG": ["KE","TZ","RW","SS","CD"],                            // Uganda
  "ZM": ["TZ","MW","MZ","ZW","AO"],                             // Zambia
  "ZW": ["ZA","BW","MZ"],                                     // Zimbabwe
};
