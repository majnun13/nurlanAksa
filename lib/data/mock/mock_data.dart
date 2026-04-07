// ─────────────────────────────────────────────────────
//  Mock Data – tüm UI bağlantıları buradan beslenir.
//  API entegrasyonu yapılınca bu dosya repository katmanı
//  ile değiştirilecek.
// ─────────────────────────────────────────────────────

class MockAksaData {
  MockAksaData._();

  // ── User
  static const String userName = 'Yavuz';
  static const int userAge = 27;
  static const double userWeight = 78.0;
  static const double userHeight = 178.0;
  static const String healthGoal = 'Kilo Koru';

  // ── Risk Score
  static const double riskScore = 0.58;   // 0.0 – 1.0 arası
  static const String riskLabel = 'Orta Risk';
  static const int riskPoints = 58;
  static const int riskTrend = 7; // + ise artış

  // ── Anomaly
  static const bool hasAnomaly = true;
  static const String anomalyLevel = 'ORTA';
  static const String anomalyMessage =
      'Kalp atış hızınız bugün normalden yüksek seyrediyor. '
      'Devam ederse bir sağlık uzmanına danışmanızı öneririz.';

  // ── Risk factors
  static const List<Map<String, dynamic>> topFactors = [
    {'name': 'Uyku kalitesi', 'impact': 0.22, 'icon': '💤'},
    {'name': 'Fiziksel aktivite', 'impact': 0.18, 'icon': '🏃'},
    {'name': 'Protein alımı', 'impact': 0.12, 'icon': '🍗'},
    {'name': 'Kalp atış hızı', 'impact': 0.06, 'icon': '❤️'},
  ];

  // ── Recommendations
  static const String nutritionTip =
      'Bir sonraki öğününüzde protein kaynağı (yumurta, tavuk) eklemeyi deneyin.';
  static const String exerciseTip =
      'Hafif yürüyüş (25 dk) enerji seviyenizi ve kan akışınızı artıracaktır.';
  static const String sleepTip =
      '7-8 saatlik düzenli uyku hedefleyin. Yatma saatinizi sabit tutun.';

  // ── Activity / Steps
  static const int stepsToday = 4200;
  static const int stepsGoal = 10000;
  static const int activeMinutes = 22;
  static const int activeMinutesGoal = 60;
  static const int caloriesBurned = 1420;
  static const int caloriesGoal = 2000;
  static const double distanceKm = 3.2;
  static const int restingHR = 72;

  // ── Sleep
  static const double sleepHours = 6.2;
  static const double sleepQuality = 0.52; // 0-1
  static const String sleepStage = 'REM';

  // ── Nutrition daily
  static const double caloriesToday = 1450;
  static const double caloriesTarget = 1800;
  static const double proteinToday = 42;
  static const double proteinTarget = 90;
  static const double carbsToday = 210;
  static const double carbsTarget = 180;
  static const double fatToday = 55;
  static const double fatTarget = 60;

  // ── Meals list
  static const List<Map<String, dynamic>> meals = [
    {
      'name': 'Yulaf ezmesi + muz',
      'type': 'Kahvaltı',
      'time': '08:30',
      'kcal': 380,
      'protein': 11,
      'carbs': 62,
      'fat': 8,
      'emoji': '🥣',
    },
    {
      'name': 'Tavuklu salata',
      'type': 'Öğle',
      'time': '13:00',
      'kcal': 460,
      'protein': 38,
      'carbs': 25,
      'fat': 18,
      'emoji': '🥗',
    },
    {
      'name': 'Protein bar',
      'type': 'Ara öğün',
      'time': '16:00',
      'kcal': 210,
      'protein': 20,
      'carbs': 18,
      'fat': 6,
      'emoji': '🍫',
    },
  ];

  // ── Weekly step data (chart)
  static const List<int> weeklySteps = [6200, 4100, 8900, 5500, 3800, 4200, 0];
  static const List<String> weekDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  // ── Anomaly events
  static const List<Map<String, dynamic>> anomalyEvents = [
    {
      'metric': 'Kalp Atış Hızı',
      'value': '112 bpm',
      'baseline': '72 bpm',
      'severity': 'ORTA',
      'time': 'Bugün, 14:32',
      'message':
          'Kalp atış hızınız bugün öğleden sonra normalden yüksek seyretti.',
    },
    {
      'metric': 'Aktivite',
      'value': '3 gündür düşük',
      'baseline': '6,500+ adım',
      'severity': 'DÜŞÜK',
      'time': '3 gün önce',
      'message': 'Son 3 günde adım sayınız ortalamanın belirgin altında.',
    },
  ];

  // ── Exercise recommendations
  static const List<Map<String, dynamic>> exerciseRecs = [
    {
      'type': 'Yürüyüş',
      'duration': '25 dk',
      'intensity': 'Düşük',
      'desc': 'Temiz havada hafif yürüyüş enerji seviyenizi artıracak.',
      'icon': '🚶',
      'color': 0xFF10B981,
    },
    {
      'type': 'Esneme',
      'duration': '10 dk',
      'intensity': 'Çok Düşük',
      'desc': 'Sabah esneme hareketleri kas esnekliğini ve kan dolaşımını iyileştirir.',
      'icon': '🧘',
      'color': 0xFF06B6D4,
    },
    {
      'type': 'Hafif Bisiklet',
      'duration': '20 dk',
      'intensity': 'Orta',
      'desc': 'Düşük yoğunluklu kardiyo kondisyon için idealdir.',
      'icon': '🚴',
      'color': 0xFF4F46E5,
    },
  ];

  // ── Weekly plan
  static const List<Map<String, dynamic>> weeklyPlan = [
    {'day': 'Pzt', 'activity': 'Yürüyüş 30dk', 'done': true},
    {'day': 'Sal', 'activity': 'Dinlenme', 'done': true},
    {'day': 'Çar', 'activity': 'Bisiklet 20dk', 'done': false},
    {'day': 'Per', 'activity': 'Yürüyüş 25dk', 'done': false},
    {'day': 'Cum', 'activity': 'Yoga 20dk', 'done': false},
    {'day': 'Cmt', 'activity': 'Koşu 15dk', 'done': false},
    {'day': 'Paz', 'activity': 'Dinlenme', 'done': false},
  ];

  // ── Risk score history
  static const List<Map<String, dynamic>> riskHistory = [
    {'date': '3 Mar', 'score': 51},
    {'date': '4 Mar', 'score': 54},
    {'date': '5 Mar', 'score': 52},
    {'date': '6 Mar', 'score': 56},
    {'date': '7 Mar', 'score': 55},
    {'date': '8 Mar', 'score': 57},
    {'date': '9 Mar', 'score': 58},
  ];

  // ── Heart rate (24h – chart)
  static const List<double> heartRateHourly = [
    65, 63, 62, 61, 60, 62, 67, 75, 82, 88, 86, 84,
    79, 83, 112, 95, 87, 80, 76, 74, 72, 70, 68, 65,
  ];

  // ── Profile
  static const List<String> medicalConditions = [];
  static const String lifestyleLevel = 'Orta';
  static const List<String> dietaryRestrictions = ['Laktoz intoleransı'];
}