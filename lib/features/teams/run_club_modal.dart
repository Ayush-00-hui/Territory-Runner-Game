import 'package:flutter/material.dart';
import '../../main.dart';

class RunClubModal extends StatefulWidget {
  const RunClubModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const RunClubModal(),
    );
  }

  @override
  State<RunClubModal> createState() => _RunClubModalState();
}

class _RunClubModalState extends State<RunClubModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _joinedClubs = {'Cyber Dawn Saturday 10K'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.accent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'RUN CLUB & SQUADS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [
                Tab(text: '⚡ Nearby Runners'),
                Tab(text: '🏃 Weekend Clubs'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Nearby Players
                _buildNearbyRunnersTab(),

                // Tab 2: Weekend Running Clubs
                _buildWeekendClubsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyRunnersTab() {
    final nearbyRunners = [
      {
        'name': 'Nova_Strider',
        'dist': '320m away',
        'pace': '5\'12"/km',
        'level': 4,
        'status': 'Currently running in Sector 8a10',
        'avatar': 'N',
        'color': const Color(0xFF00F0FF),
      },
      {
        'name': 'HexVeloCity',
        'dist': '680m away',
        'pace': '5\'45"/km',
        'level': 6,
        'status': 'Conquered 3 hexes today',
        'avatar': 'H',
        'color': const Color(0xFF8A2BE2),
      },
      {
        'name': 'AeroKnight',
        'dist': '1.2 km away',
        'pace': '6\'10"/km',
        'level': 2,
        'status': 'Active warm-up',
        'avatar': 'A',
        'color': const Color(0xFFFF0055),
      },
      {
        'name': 'CyberPhantom',
        'dist': '1.8 km away',
        'pace': '4\'55"/km',
        'level': 9,
        'status': 'On a 7-day streak',
        'avatar': 'C',
        'color': const Color(0xFF00FF88),
      },
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.radar, color: AppColors.accent, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '4 Active runners conquering territory within 2.0 km of your coordinates',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...nearbyRunners.map((runner) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: (runner['color'] as Color).withValues(alpha: 0.2),
                  child: Text(
                    runner['avatar'] as String,
                    style: TextStyle(
                      color: runner['color'] as Color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            runner['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Lvl ${runner['level']}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${runner['dist']} • Pace: ${runner['pace']}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        runner['status'] as String,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    foregroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚡ High-five sent to ${runner['name']}!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Wave 👋', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekendClubsTab() {
    final clubs = [
      {
        'title': 'Cyber Dawn Saturday 10K',
        'schedule': 'Every Saturday • 6:30 AM',
        'location': 'Central Park Metro Gate 4',
        'members': 38,
        'pace': 'Moderate (5:30 - 6:30 min/km)',
        'tag': 'WEEKEND 10K',
        'color': const Color(0xFF00F0FF),
      },
      {
        'title': 'Midnight Neon 5K Jog',
        'schedule': 'Every Friday Night • 8:00 PM',
        'location': 'Cyber City Skyline Loop',
        'members': 62,
        'pace': 'Social / Casual (6:30 - 7:30 min/km)',
        'tag': 'NIGHT RUN',
        'color': const Color(0xFF8A2BE2),
      },
      {
        'title': 'Sunday Long Run & Recovery',
        'schedule': 'Every Sunday • 7:00 AM',
        'location': 'Lakeview Botanical Trail',
        'members': 24,
        'pace': 'Endurance (5:45 - 6:45 min/km)',
        'tag': 'HALF MARATHON',
        'color': const Color(0xFFFF9900),
      },
      {
        'title': 'Sector Domination Turf War',
        'schedule': 'Saturday • 5:00 PM',
        'location': 'Downtown Commercial Hub',
        'members': 45,
        'pace': 'Competitive Conquest',
        'tag': 'HEX BATTLE',
        'color': const Color(0xFFFF0055),
      },
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        ...clubs.map((club) {
          final String title = club['title'] as String;
          final bool isJoined = _joinedClubs.contains(title);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isJoined ? (club['color'] as Color) : AppColors.border,
                width: isJoined ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (club['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        club['tag'] as String,
                        style: TextStyle(
                          color: club['color'] as Color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.people_alt, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${club['members']} runners',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      club['schedule'] as String,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        club['location'] as String,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pace: ${club['pace']}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isJoined ? Colors.white12 : (club['color'] as Color),
                        foregroundColor: isJoined ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isJoined) {
                            _joinedClubs.remove(title);
                          } else {
                            _joinedClubs.add(title);
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isJoined ? 'Left $title' : '🎉 You joined $title! Added to weekend calendar.',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        isJoined ? 'Joined ✓' : 'Join Squad',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
