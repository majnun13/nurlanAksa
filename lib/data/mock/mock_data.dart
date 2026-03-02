class MockAksaData {
  static double riskScore = 0.62; // 0-1
  static String riskLabel = "Orta";

  static bool hasAnomaly = true;
  static String anomalyLevel = "Önemli"; // Hafif / Önemli / Acil
  static String anomalyMessage = "Nabız ve uyku düzeninde alışılmadık sapma tespit edildi.";

  static List<Map<String, dynamic>> topFactors = [
    {"name": "Uyku süresi düşüşü", "impact": 0.18},
    {"name": "Dinlenik nabız artışı", "impact": 0.14},
    {"name": "Aktivite azalması", "impact": 0.11},
  ];

  static Map<String, List<double>> series = {
    "Adım": [4200, 6100, 5200, 8300, 7600, 9100, 6800],
    "Nabız": [72, 74, 78, 76, 81, 79, 77],
    "Uyku": [7.1, 6.4, 6.8, 5.9, 6.2, 7.0, 6.6],
  };

  static String nutritionTip = "Bugün protein hedefini yakalamak için 1 porsiyon yoğurt ekleyebilirsin.";
  static String exerciseTip = "Uygunsa 20 dk tempolu yürüyüş önerilir (orta yoğunluk).";
}