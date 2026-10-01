import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';

class AlertsScreen extends StatelessWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  const AlertsScreen({super.key, required this.navigate, required this.city});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    decoration:
                        const BoxDecoration(gradient: AppColors.skyGradient),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => navigate(AppScreen.home),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0x33FFFFFF),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: const Color(0x4DFFFFFF)),
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Weather Alerts',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(city,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      const Text('NCR, Philippines',
                                          style: TextStyle(
                                              color: Color(0xB3FFFFFF),
                                              fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        // Primary alert
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: cardDecoration(
                            color: const Color(0xFFFFFDF0),
                            border: Border.all(
                                color: const Color(0xFFFCD34D), width: 2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(14)),
                                alignment: Alignment.center,
                                child: const Text('⚠️',
                                    style: TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Expanded(
                                          child: Text('Heavy Rain Warning',
                                              style: TextStyle(
                                                  color: AppColors.textDark,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppColors.amber,
                                              borderRadius:
                                                  BorderRadius.circular(99)),
                                          child: const Text('ACTIVE',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                        'Moderate to heavy rainfall is expected in your area.',
                                        style: TextStyle(
                                            color: AppColors.textBody,
                                            fontSize: 12,
                                            height: 1.5)),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Expected',
                                                  style: TextStyle(
                                                      color: AppColors.textGray,
                                                      fontSize: 10)),
                                              Text('3:00 PM – 7:00 PM',
                                                  style: TextStyle(
                                                      color: AppColors.textDark,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text('Severity',
                                                  style: TextStyle(
                                                      color: AppColors.textGray,
                                                      fontSize: 10)),
                                              Text('Moderate',
                                                  style: TextStyle(
                                                      color: AppColors.amber,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Other alerts
                        ...otherAlerts.map((a) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: cardDecoration(),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: Color(a.severityBg),
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    alignment: Alignment.center,
                                    child: WeatherIcon(
                                        condition: a.condition, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(a.title,
                                            style: const TextStyle(
                                                color: AppColors.textDark,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(a.desc,
                                            style: const TextStyle(
                                                color: AppColors.textGray,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Color(a.severityBg),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                          color: Color(a.severityColor)
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Text(a.severity,
                                        style: TextStyle(
                                            color: Color(a.severityColor),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        // AI safety reminder
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: cardDecoration(
                            color: const Color(0xFFF0F8FF),
                            border: Border.all(color: const Color(0xFFDBEEFF)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('✨', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 8),
                                  Text('AI Safety Reminder',
                                      style: TextStyle(
                                          color: AppColors.skyBlueTop,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                  '"Stay indoors during heavy rainfall and avoid flooded roads."',
                                  style: TextStyle(
                                      color: AppColors.textBody,
                                      fontSize: 13,
                                      height: 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomNav(active: AppScreen.alerts, onNavigate: navigate),
        ],
      ),
    );
  }
}
