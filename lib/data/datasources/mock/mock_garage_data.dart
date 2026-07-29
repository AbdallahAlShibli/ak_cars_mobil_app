import '../../../core/i18n/strings.dart';
import '../../models/challenge.dart';
import '../../models/maintenance.dart';

/// Demo seed for the weekly challenge. Read only by `MockChallengeService`.
///
/// There is deliberately no maintenance seed here any more. Maintenance is now
/// per car and every book starts empty: the demo log that used to live here was
/// global, so a user who had just registered their first car was shown an oil
/// change and a wheel alignment that car had never had, at a mileage that was
/// not theirs.
abstract final class MockGarageData {
  static const challengeBoard = ChallengeBoard(
    current: WeeklyChallenge(
      id: 'tyre-pressure',
      title: L('افحص ضغط الإطارات الأربعة', 'Check all four tyre pressures'),
      description: L(
        'حرارة الصيف ترفع الضغط — فحص أسبوعي يطيل عمر الإطار ويقلل الاستهلاك.',
        'Summer heat raises pressure — a weekly check extends tyre life and cuts fuel use.',
      ),
      steps: [
        ChallengeStep(
          id: 's1',
          title: L('حدّث ممشى السيارة', 'Update your odometer'),
          done: true,
        ),
        ChallengeStep(
          id: 's2',
          title: L('سجّل قراءة الضغط (صورة أو رقم)',
              'Log the pressure reading (photo or number)'),
        ),
        ChallengeStep(
          id: 's3',
          title: L('قارنها بالموصى به لسيارتك (33 PSI)',
              'Compare with your car\'s recommended (33 PSI)'),
        ),
      ],
      rewardPoints: 150,
      badgeName: L('عين على الإطارات', 'Tyre watcher'),
      endsInDays: 3,
      feedsMaintenance: MaintenanceType.tyres,
    ),
    next: LockedChallenge(
      title: L('نظّف فلتر المكيف بنفسك', 'Clean your AC filter yourself'),
      points: 100,
    ),
    history: [
      PastChallenge(
        title: L('افحص سائل التبريد', 'Check your coolant'),
        points: 150,
      ),
      PastChallenge(
        title: L('حدّث الممشى 4 أسابيع متتالية',
            'Update mileage 4 weeks in a row'),
        points: 200,
      ),
    ],
    streakWeeks: 3,
    completedCount: 12,
    points: 2450,
    badgeCount: 8,
  );

  /// The board an owner of a car that plugs in gets instead.
  ///
  /// Same shape, same rewards, same streak — only the tasks differ. An EV
  /// owner being handed "check your engine oil level" week after week is
  /// exactly the "EV support is an afterthought" feeling this exists to fix.
  ///
  /// The loyalty totals are shared with the combustion board on purpose: the
  /// user has one points balance, and it must not appear to change when they
  /// make an EV their default car.
  static const evChallengeBoard = ChallengeBoard(
    current: WeeklyChallenge(
      id: 'ev-trip-charge',
      title: L('خطّط الشحن قبل رحلتك القادمة',
          'Plan your charging before the next long drive'),
      description: L(
        'الطريق إلى صلالة أو الجبل الأخضر يحتاج توقفاً مخططاً — عشر دقائق '
            'اليوم توفّر عليك الانتظار على الطريق.',
        'A run to Salalah or Jebel Akhdar needs a planned stop — ten minutes '
            'now saves a wait on the road.',
      ),
      steps: [
        ChallengeStep(
          id: 'ev-s1',
          title: L('حدّد نقطة الشحن التي ستتوقف عندها',
              'Pick the charging stop you will use'),
        ),
        ChallengeStep(
          id: 'ev-s2',
          title: L('افحص كيبل الشحن: سخونة أو تشقق أو أطراف متآكلة',
              'Inspect your charging cable: heat marks, cracks, worn pins'),
        ),
        ChallengeStep(
          id: 'ev-s3',
          title: L('اضبط ضغط الإطارات — الضغط الناقص يقصّر المدى',
              'Set tyre pressures — low pressure costs you range'),
        ),
      ],
      rewardPoints: 150,
      badgeName: L('مستعد للطريق', 'Road ready'),
      endsInDays: 4,
      // Pressures set with a gauge is a tyre check, and it is logged as one.
      feedsMaintenance: MaintenanceType.tyres,
      recordTitle: L('ضبط ضغط الإطارات وفحص الكيبل (تحدي)',
          'Tyre pressures set & cable checked (challenge)'),
    ),
    next: LockedChallenge(
      title: L('سجّل فحص الشاحن المنزلي', 'Log your home charger inspection'),
      points: 120,
    ),
    history: [
      PastChallenge(
        title: L('نظّف منفذ الشحن وافحص القفل',
            'Clean the charge port and check its latch'),
        points: 100,
      ),
      PastChallenge(
        title: L('حدّث الممشى 4 أسابيع متتالية',
            'Update mileage 4 weeks in a row'),
        points: 200,
      ),
    ],
    streakWeeks: 3,
    completedCount: 12,
    points: 2450,
    badgeCount: 8,
  );
}
