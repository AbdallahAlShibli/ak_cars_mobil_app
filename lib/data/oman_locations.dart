/// Oman governorates and their wilayats (states).
/// Replace with `GET /api/locations` in Phase 2.
abstract final class OmanLocations {
  static const governorates = <String, List<String>>{
    'Muscat': [
      'Muscat', 'Muttrah', 'Bawshar', 'Seeb', 'Al Amerat', 'Qurayyat',
    ],
    'Dhofar': [
      'Salalah', 'Taqah', 'Mirbat', 'Thumrait', 'Sadah', 'Rakhyut',
    ],
    'Musandam': ['Khasab', 'Bukha', 'Daba', 'Madha'],
    'Al Buraimi': ['Al Buraimi', 'Mahdah', 'Al Sinainah'],
    'Ad Dakhiliyah': [
      'Nizwa', 'Bahla', 'Manah', 'Al Hamra', 'Adam', 'Izki', 'Samail',
      'Bidbid',
    ],
    'North Al Batinah': [
      'Sohar', 'Shinas', 'Liwa', 'Saham', 'Al Khaburah', 'As Suwayq',
    ],
    'South Al Batinah': [
      'Rustaq', 'Al Awabi', 'Nakhal', 'Wadi Al Maawil', 'Barka',
      'Al Musannah',
    ],
    'South Ash Sharqiyah': [
      'Sur', 'Al Kamil Wal Wafi', 'Jalan Bani Bu Hassan',
      'Jalan Bani Bu Ali', 'Masirah',
    ],
    'North Ash Sharqiyah': [
      'Ibra', 'Al Mudhaibi', 'Bidiyah', 'Al Qabil', 'Wadi Bani Khalid',
      'Dema Wa Thaieen',
    ],
    'Ad Dhahirah': ['Ibri', 'Yanqul', 'Dhank'],
    'Al Wusta': ['Haima', 'Duqm', 'Mahout', 'Al Jazer'],
  };

  static List<String> wilayatsOf(String governorate) =>
      governorates[governorate] ?? const [];
}
