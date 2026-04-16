import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Météo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const WeatherHomePage(),
    );
  }
}

// ── Modèles de données ────────────────────────────────────────────────────────

class WeatherData {
  final double temperature;
  final double windSpeed;
  final String time;
  final List<HourlyWeather> hourly;

  WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.time,
    required this.hourly,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final hourlyTimes = List<String>.from(json['hourly']['time']);
    final hourlyTemps = List<double>.from(
      (json['hourly']['temperature_2m'] as List).map((e) => (e as num).toDouble()),
    );
    final hourlyHumidity = List<int>.from(
      (json['hourly']['relative_humidity_2m'] as List).map((e) => (e as num).toInt()),
    );
    final hourlyWind = List<double>.from(
      (json['hourly']['wind_speed_10m'] as List).map((e) => (e as num).toDouble()),
    );

    // Prendre les 24 prochaines heures
    final now = DateTime.now();
    final hourlyList = <HourlyWeather>[];
    for (int i = 0; i < hourlyTimes.length && hourlyList.length < 24; i++) {
      final t = DateTime.parse(hourlyTimes[i]);
      if (t.isAfter(now)) {
        hourlyList.add(HourlyWeather(
          time: t,
          temperature: hourlyTemps[i],
          humidity: hourlyHumidity[i],
          windSpeed: hourlyWind[i],
        ));
      }
    }

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      time: current['time'],
      hourly: hourlyList,
    );
  }
}

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int humidity;
  final double windSpeed;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
  });
}

// ── Service API ───────────────────────────────────────────────────────────────

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  static Future<WeatherData> fetchWeather({
    double latitude = 52.52,
    double longitude = 13.41,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,wind_speed_10m'
      '&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return WeatherData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erreur API: ${response.statusCode}');
    }
  }
}

// ── Page principale ───────────────────────────────────────────────────────────

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage>
    with TickerProviderStateMixin {
  WeatherData? _weatherData;
  bool _isLoading = true;
  String? _error;

  late AnimationController _bgController;
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );

    _loadWeather();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await WeatherService.fetchWeather();
      setState(() {
        _weatherData = data;
        _isLoading = false;
      });
      _cardController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getWeatherCondition(double temp) {
    if (temp < 5) return 'Très froid';
    if (temp < 10) return 'Froid';
    if (temp < 15) return 'Frais';
    if (temp < 20) return 'Doux';
    if (temp < 25) return 'Agréable';
    if (temp < 30) return 'Chaud';
    return 'Très chaud';
  }

  String _getWeatherIcon(double temp) {
    if (temp < 5) return '🌨️';
    if (temp < 10) return '🌥️';
    if (temp < 15) return '⛅';
    if (temp < 20) return '🌤️';
    if (temp < 25) return '☀️';
    return '🌞';
  }

  List<Color> _getGradientColors(double temp) {
    if (temp < 5) return [const Color(0xFF1A237E), const Color(0xFF283593)];
    if (temp < 15) return [const Color(0xFF1565C0), const Color(0xFF1976D2)];
    if (temp < 20) return [const Color(0xFF0277BD), const Color(0xFF0288D1)];
    if (temp < 25) return [const Color(0xFF00838F), const Color(0xFF006064)];
    return [const Color(0xFFE65100), const Color(0xFFBF360C)];
  }

  @override
  Widget build(BuildContext context) {
    final temp = _weatherData?.temperature ?? 20.0;
    final gradColors = _getGradientColors(temp);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradColors[0],
                  gradColors[1],
                  Color.lerp(gradColors[0], Colors.black, 0.3 + _bgController.value * 0.1)!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: _isLoading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Chargement de la météo...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger la météo',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWeather,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _weatherData!;

    return FadeTransition(
      opacity: _cardAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_cardAnimation),
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(data)),
              SliverToBoxAdapter(child: _buildStatsRow(data)),
              SliverToBoxAdapter(child: _buildHourlyForecast(data)),
              SliverToBoxAdapter(child: _buildDailyStats(data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(WeatherData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ville + date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Berlin, Allemagne',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadWeather,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Icône + température
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getWeatherIcon(data.temperature),
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.temperature.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w200,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    _getWeatherCondition(data.temperature),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatsRow(WeatherData data) {
    int currentHumidity = 50;
    if (data.hourly.isNotEmpty) {
      currentHumidity = data.hourly.first.humidity;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(Icons.air, '${data.windSpeed.toStringAsFixed(1)} km/h', 'Vent'),
            _buildDivider(),
            _buildStatItem(Icons.water_drop, '$currentHumidity%', 'Humidité'),
            _buildDivider(),
            _buildStatItem(
              Icons.thermostat,
              '${_getTodayMinMax(data)[0].toStringAsFixed(0)}° / ${_getTodayMinMax(data)[1].toStringAsFixed(0)}°',
              'Min / Max',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildHourlyForecast(WeatherData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prévisions horaires',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: min(12, data.hourly.length),
              itemBuilder: (context, index) {
                final h = data.hourly[index];
                final isNow = index == 0;

                return Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isNow
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isNow
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        isNow ? 'Maint.' : _formatHour(h.time),
                        style: TextStyle(
                          color: isNow ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        _getWeatherIcon(h.temperature),
                        style: const TextStyle(fontSize: 22),
                      ),
                      Text(
                        '${h.temperature.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStats(WeatherData data) {
  // Grouper par jour avec DateTime directement (PAS de String)
  final Map<DateTime, List<HourlyWeather>> byDay = {};

  for (final h in data.hourly) {
    final date = DateTime(h.time.year, h.time.month, h.time.day);

    byDay.putIfAbsent(date, () => []).add(h);
  }

  final days = byDay.entries.take(5).toList();

  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prévisions 5 jours',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: days.asMap().entries.map((entry) {
              final index = entry.key;
              final date = entry.value.key;
              final list = entry.value.value;

              final temps = list.map((h) => h.temperature).toList();
              final minT = temps.reduce(min);
              final maxT = temps.reduce(max);

              final avgHum = (list
                          .map((h) => h.humidity)
                          .reduce((a, b) => a + b) /
                      list.length)
                  .round();

              final avgTemp =
                  temps.reduce((a, b) => a + b) / temps.length;

              final isLast = index == days.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            _formatDayName(date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          _getWeatherIcon(avgTemp),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const Spacer(),
                        Text(
                          '$avgHum%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${minT.toStringAsFixed(0)}°',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        _buildTempBar(minT, maxT),
                        const SizedBox(width: 8),
                        Text(
                          '${maxT.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTempBar(double min, double max) {
    return Container(
      width: 60,
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade300,
            Colors.orange.shade300,
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<double> _getTodayMinMax(WeatherData data) {
    final now = DateTime.now();
    final todayHourly = data.hourly.where(
      (h) => h.time.day == now.day && h.time.month == now.month,
    ).toList();

    if (todayHourly.isEmpty) {
      return [data.temperature - 5, data.temperature + 5];
    }

    final temps = todayHourly.map((h) => h.temperature).toList();
    return [temps.reduce(min), temps.reduce(max)];
  }

  String _formatDate(DateTime dt) {
    const jours = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const mois = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${jours[dt.weekday % 7]} ${dt.day} ${mois[dt.month - 1]} ${dt.year}';
  }

  String _formatHour(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}h';
  }

  String _formatDayName(DateTime dt) {
    const jours = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final now = DateTime.now();
    if (dt.day == now.day) return "Aujourd'hui";
    if (dt.day == now.day + 1) return 'Demain';
    return jours[dt.weekday % 7];
  }
}
