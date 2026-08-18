import 'dart:math';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/audit_entry.dart';
import 'package:ak_cars_mobil_app/data/models/car.dart';
import 'package:ak_cars_mobil_app/data/models/escrow.dart';
import 'package:ak_cars_mobil_app/data/models/payout_record.dart';
import 'package:ak_cars_mobil_app/data/models/powertrain.dart';
import 'package:ak_cars_mobil_app/data/models/proof_of_work.dart';
import 'package:ak_cars_mobil_app/data/models/quote.dart';
import 'package:ak_cars_mobil_app/data/models/review.dart';
import 'package:ak_cars_mobil_app/data/models/service_provider.dart';
import 'package:ak_cars_mobil_app/data/models/service_request.dart';
import 'mock_service_data.dart';
import 'mock_ids.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'mock_media.dart';

/// The demo world, in one place (spec §2).
///
/// Before this file existed the mock data was a catalogue and nothing else:
/// eleven workshops that were all either approved or not, and **zero** seeded
/// bookings. Every operator screen therefore opened empty, which meant none of
/// them could be looked at — an SLA colour that only appears after you place a
/// booking by hand is an SLA colour nobody has ever seen.
///
/// What this seeds, and why each part is here:
///
/// * **Workshops across every [ProviderOnboardingStage]** — so the founder's
///   pipeline (§5, tab 2) and the registration flow (§11) have something real
///   to render, including applications waiting on a human.
/// * **Bookings covering every [EscrowState]** — the previous data reached
///   exactly one of the thirteen. Several are positioned deliberately either
///   side of a [QueueSla] window so the amber and red states are visible on a
///   cold start rather than only after waiting a day.
/// * **Reviews in both directions**, including one written after a resolved
///   dispute, because §8 says those are labelled rather than hidden and that
///   rule needs a case to be visible on.
/// * **Payouts and audit lines**, so the Money and Audit tabs are not empty
///   shells.
///
/// **Determinism.** Every timestamp is relative to [now] and every random
/// choice comes from [_rng], seeded at 42. Two runs of the test suite see the
/// same world, and that world is never stale — a fixture with absolute 2024
/// dates in it reads as a bug the moment it is a year old.
///
/// **Single source of truth.** `MockServiceData` reads its provider list from
/// here rather than declaring its own; this file reads the catalogue back for
/// the offerings its bookings point at. The two imports look circular and are
/// not: Dart initialises `static final` lazily, and neither list is needed
/// while the other is being built.
///
/// **What is deliberately *not* seeded:** the user's garage and their
/// maintenance books. Both are the signed-in person's own records, and the
/// project already removed a global maintenance seed once, for the reason
/// recorded in `mock_garage_data.dart` — a user who has just registered their
/// first car must not be shown services that car never had. The cars below
/// belong to the seeded *bookings*, not to anybody's garage.
abstract final class MockSeed {
  /// Seeded so the world is identical on every run. Used for the small
  /// variations — which car is on which booking, which review scores what —
  /// that make the demo data look lived-in rather than tabulated.
  static final _rng = Random(42);

  /// One `now` for the whole seed. Read once so a build that takes a second
  /// cannot produce two bookings whose relative ages disagree by a tick.
  static final now = DateTime.now();

  static DateTime daysAgo(num days) =>
      now.subtract(Duration(minutes: (days * 24 * 60).round()));

  static DateTime hoursAgo(num hours) =>
      now.subtract(Duration(minutes: (hours * 60).round()));

  // ============================================================ workshops

  /// The workshop roster — every stage of the onboarding path represented.
  ///
  /// **Fifteen, not the spec's twelve**, and the extra three are not padding.
  /// The region coverage rule (`services_region_test`) requires that every
  /// governorate's *approved* workshops between them sell every category, and
  /// that takes eleven approved workshops on its own. §11 then needs
  /// applications actually sitting in the founder's queue. Twelve cannot be
  /// both, so the roster is eleven approved plus four applications in flight.
  ///
  /// The four applicants (`p12`–`p15`, and `p3`) carry **no catalogue
  /// entries**, which is not an oversight: a workshop that has not been
  /// approved has never listed a service, so it contributes nothing to the
  /// coverage matrix and cannot be booked even if a stale link reached it.
  static final providers = <ServiceProvider>[
    // ------------------------------------------------------------ Muscat
    ServiceProvider(
      id: mockIdP1,
      name: const L('ورشة النور', 'Al Noor Workshop'),
      area: 'Al Khuwair',
      region: 'Muscat',
      distanceKm: 2.4,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(420),
      fulfillments: const {Fulfillment.workshop, Fulfillment.pickup},
      capabilities: const {ProviderCapability.evService},
      phone: '+96824478120',
      whatsapp: '96892140088',
      vatNumber: 'OM1100047382',
      crNumber: '1198432',
      hours: const L('السبت–الخميس ٨:٠٠–٢٠:٠٠ · الجمعة مغلق',
          'Sat–Thu 8:00–20:00 · Fri closed'),
    ),
    ServiceProvider(
      id: mockIdP2,
      name: const L('الخليج للعناية بالسيارات', 'Gulf Auto Care'),
      area: 'Seeb',
      region: 'Muscat',
      distanceKm: 6.1,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(510),
      fulfillments: const {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      capabilities: const {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      phone: '+96824551907',
      whatsapp: '96895330214',
      vatNumber: 'OM1100062915',
      crNumber: '1243907',
      hours: const L('السبت–الخميس ٧:٣٠–٢١:٠٠ · الجمعة ١٦:٠٠–٢١:٠٠',
          'Sat–Thu 7:30–21:00 · Fri 16:00–21:00'),
    ),
    ServiceProvider(
      id: mockIdP4,
      name: const L('خبراء القرم للسيارات', 'Qurum Auto Experts'),
      area: 'Qurum',
      region: 'Muscat',
      distanceKm: 4.2,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(300),
      fulfillments: const {Fulfillment.workshop, Fulfillment.pickup},
      pickupFee: 2,
      phone: '+96824663415',
      whatsapp: '96899210546',
      vatNumber: 'OM1100051764',
      crNumber: '1215880',
      hours: const L('السبت–الخميس ٨:٠٠–١٩:٠٠ · الجمعة مغلق',
          'Sat–Thu 8:00–19:00 · Fri closed'),
    ),
    // -------------------------------------------------- North Al Batinah
    /// Listed a catalogue during a pilot, then had to re-submit its CR when
    /// the platform tightened verification. Unapproved, so its services are
    /// hidden and its offer (`of-p3-express-unapproved`) is rejected — which
    /// is exactly the case `home_offers_test` pins.
    ServiceProvider(
      id: mockIdP3,
      name: const L('كراج صحار سبيد', 'Sohar Speed Garage'),
      area: 'Sohar',
      region: 'North Al Batinah',
      distanceKm: 18.0,
      verified: false,
      stage: ProviderOnboardingStage.documentsSubmitted,
      stageSince: hoursAgo(31),
      crDocument: mockCrDocument(
        id: derivedGuid('cr-document', '1307654'),
        crNumber: '1307654',
      ),
      fulfillments: const {Fulfillment.workshop},
      phone: '+96826841203',
      whatsapp: '96897440319',
      crNumber: '1307654',
      hours: const L('السبت–الخميس ٨:٠٠–١٨:٠٠', 'Sat–Thu 8:00–18:00'),
    ),
    ServiceProvider(
      id: mockIdP8,
      name: const L('مركز صحم للسيارات', 'Saham Auto Centre'),
      area: 'Saham',
      region: 'North Al Batinah',
      distanceKm: 26.0,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(260),
      fulfillments: const {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      capabilities: const {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      phone: '+96826855740',
      whatsapp: '96893120877',
      vatNumber: 'OM1100073508',
      crNumber: '1288201',
      hours: const L('السبت–الخميس ٧:٠٠–٢٠:٠٠ · الجمعة ١٦:٠٠–٢٠:٠٠',
          'Sat–Thu 7:00–20:00 · Fri 16:00–20:00'),
    ),
    /// Added so North Al Batinah still covers every category once `p3` is
    /// correctly hidden from customers.
    ServiceProvider(
      id: mockIdP12,
      name: const L('لوى للميكانيكا الشاملة', 'Liwa Complete Motors'),
      area: 'Liwa',
      region: 'North Al Batinah',
      distanceKm: 34.0,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(88),
      fulfillments: const {Fulfillment.workshop, Fulfillment.pickup},
      pickupFee: 4,
      phone: '+96826751840',
      whatsapp: '96891880463',
      vatNumber: 'OM1100090417',
      crNumber: '1394507',
      hours: const L('السبت–الخميس ٨:٠٠–١٩:٠٠', 'Sat–Thu 8:00–19:00'),
    ),
    // -------------------------------------------------- South Al Batinah
    ServiceProvider(
      id: mockIdP7,
      name: const L('بركاء كويك فكس', 'Barka Quick Fix'),
      area: 'Barka',
      region: 'South Al Batinah',
      distanceKm: 22.0,
      verified: false,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(150),
      fulfillments: const {Fulfillment.workshop, Fulfillment.roadside},
      capabilities: const {ProviderCapability.evService},
      phone: '+96826882456',
      whatsapp: '96896015523',
      crNumber: '1341120',
      hours: const L('السبت–الخميس ٨:٠٠–٢٢:٠٠', 'Sat–Thu 8:00–22:00'),
    ),
    ServiceProvider(
      id: mockIdP9,
      name: const L('الرستاق لميكانيكا السيارات', 'Rustaq Motor Works'),
      area: 'Rustaq',
      region: 'South Al Batinah',
      distanceKm: 38.0,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(340),
      fulfillments: const {Fulfillment.workshop, Fulfillment.pickup},
      capabilities: const {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      pickupFee: 4,
      phone: '+96826875031',
      whatsapp: '96894870162',
      vatNumber: 'OM1100068247',
      crNumber: '1276418',
      hours: const L('السبت–الخميس ٨:٠٠–١٩:٣٠ · الجمعة مغلق',
          'Sat–Thu 8:00–19:30 · Fri closed'),
    ),
    /// Documents read and accepted, not yet switched on — the stage that
    /// exists to prove approval is a *decision*, not a consequence of the
    /// paperwork being in order.
    ServiceProvider(
      id: mockIdP13,
      name: const L('ورشة المصنعة الحديثة', 'Musannah Modern Workshop'),
      area: 'Al Musannah',
      region: 'South Al Batinah',
      distanceKm: 41.0,
      verified: true,
      stage: ProviderOnboardingStage.verified,
      stageSince: hoursAgo(9),
      crDocument: mockCrDocument(
        id: derivedGuid('cr-document', '1402886'),
        crNumber: '1402886',
      ),
      ownerUserId: 'u-seed-musannah',
      fulfillments: const {Fulfillment.workshop, Fulfillment.pickup},
      phone: '+96826862190',
      crNumber: '1402886',
    ),
    // ----------------------------------------------------- Ad Dakhiliyah
    ServiceProvider(
      id: mockIdP5,
      name: const L('نزوى للعناية بالسيارات', 'Nizwa Car Care'),
      area: 'Nizwa',
      region: 'Ad Dakhiliyah',
      distanceKm: 32.0,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(390),
      fulfillments: const {Fulfillment.workshop, Fulfillment.roadside},
      capabilities: const {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      phone: '+96825412876',
      whatsapp: '96891650430',
      vatNumber: 'OM1100059183',
      crNumber: '1260973',
      hours: const L('السبت–الخميس ٧:٣٠–١٩:٠٠ · الجمعة مغلق',
          'Sat–Thu 7:30–19:00 · Fri closed'),
    ),
    ServiceProvider(
      id: mockIdP10,
      name: const L('نقطة خدمة سمائل', 'Samail Service Point'),
      area: 'Samail',
      region: 'Ad Dakhiliyah',
      distanceKm: 24.0,
      verified: false,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(64),
      fulfillments: const {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      phone: '+96825350962',
      whatsapp: '96892770118',
      crNumber: '1352209',
      hours: const L('يومياً ٦:٠٠–٢٣:٠٠', 'Daily 6:00–23:00'),
    ),
    /// Rejected, with the reason the owner is shown (§11 step 5) and can act
    /// on. Re-submitting puts it back to [ProviderOnboardingStage
    /// .documentsSubmitted] and back into the founder's pipeline.
    ServiceProvider(
      id: mockIdP14,
      name: const L('ورشة بهلاء للسيارات', 'Bahla Auto Workshop'),
      area: 'Bahla',
      region: 'Ad Dakhiliyah',
      distanceKm: 47.0,
      verified: false,
      stage: ProviderOnboardingStage.suspended,
      stageSince: hoursAgo(52),
      rejectionReason:
          'صورة السجل التجاري غير واضحة — الرقم غير مقروء. أعد رفعها بجودة أعلى.',
      crDocument: mockCrDocument(
        id: derivedGuid('cr-document', '1411203'),
        crNumber: '1411203',
      ),
      ownerUserId: 'u-seed-bahla',
      fulfillments: const {Fulfillment.workshop},
      phone: '+96825420117',
      crNumber: '1411203',
    ),
    // ------------------------------------------------------------ Dhofar
    ServiceProvider(
      id: mockIdP6,
      name: const L('مركز صلالة للمحركات', 'Salalah Motors Hub'),
      area: 'Salalah',
      region: 'Dhofar',
      distanceKm: 45.0,
      verified: true,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(280),
      fulfillments: const {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      capabilities: const {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      pickupFee: 4,
      phone: '+96823298450',
      whatsapp: '96899640277',
      vatNumber: 'OM1100081642',
      crNumber: '1229561',
      hours: const L('السبت–الخميس ٨:٠٠–٢٠:٣٠ · الجمعة ١٦:٠٠–٢٠:٣٠',
          'Sat–Thu 8:00–20:30 · Fri 16:00–20:30'),
    ),
    ServiceProvider(
      id: mockIdP11,
      name: const L('كراج طاقة للسيارات', 'Taqah Auto Garage'),
      area: 'Taqah',
      region: 'Dhofar',
      distanceKm: 52.0,
      verified: false,
      stage: ProviderOnboardingStage.approved,
      stageSince: daysAgo(41),
      fulfillments: const {Fulfillment.workshop, Fulfillment.roadside},
      phone: '+96823271908',
      whatsapp: '96897330654',
      crNumber: '1366742',
      hours: const L('السبت–الخميس ٨:٠٠–١٨:٣٠', 'Sat–Thu 8:00–18:30'),
    ),
    /// The freshest application — submitted hours ago, still inside the SLA
    /// the founder panel measures against.
    ServiceProvider(
      id: mockIdP15,
      name: const L('ورشة مرباط البحرية', 'Mirbat Marine & Auto'),
      area: 'Mirbat',
      region: 'Dhofar',
      distanceKm: 71.0,
      verified: false,
      stage: ProviderOnboardingStage.documentsSubmitted,
      stageSince: hoursAgo(5),
      crDocument: mockCrDocument(
        id: derivedGuid('cr-document', '1423970'),
        crNumber: '1423970',
      ),
      ownerUserId: 'u-seed-mirbat',
      fulfillments: const {Fulfillment.workshop, Fulfillment.roadside},
      phone: '+96823268804',
      crNumber: '1423970',
    ),
  ];

  static ServiceProvider providerById(String id) =>
      providers.firstWhere((p) => p.id == id);

  // ================================================================= cars

  /// The cars the seeded bookings are *for*.
  ///
  /// Not a garage: nothing here is offered to the signed-in user, and nothing
  /// writes a maintenance book. They exist so an operator card has a real make,
  /// model and plate to show instead of a placeholder.
  static const cars = <Car>[
    Car(
      id: mockIdSc1,
      make: 'Toyota',
      model: 'Land Cruiser',
      year: 2021,
      plate: '4821 AB',
      odometerKm: 78400,
      governorate: 'Muscat',
      powertrain: Powertrain.petrol,
    ),
    Car(
      id: mockIdSc2,
      make: 'Nissan',
      model: 'Patrol',
      year: 2019,
      plate: '1176 CD',
      odometerKm: 132500,
      governorate: 'Muscat',
      powertrain: Powertrain.petrol,
    ),
    Car(
      id: mockIdSc3,
      make: 'Hyundai',
      model: 'Elantra',
      year: 2022,
      plate: '9034 EF',
      odometerKm: 41200,
      governorate: 'North Al Batinah',
      powertrain: Powertrain.petrol,
    ),
    Car(
      id: mockIdSc4,
      make: 'Tesla',
      model: 'Model 3',
      year: 2023,
      plate: '5507 GH',
      odometerKm: 28900,
      governorate: 'Muscat',
      powertrain: Powertrain.electric,
    ),
    Car(
      id: mockIdSc5,
      make: 'Mitsubishi',
      model: 'Pajero',
      year: 2018,
      plate: '2298 JK',
      odometerKm: 164000,
      governorate: 'Dhofar',
      powertrain: Powertrain.diesel,
    ),
    Car(
      id: mockIdSc6,
      make: 'Kia',
      model: 'Sportage',
      year: 2020,
      plate: '7713 LM',
      odometerKm: 96700,
      governorate: 'Ad Dakhiliyah',
      powertrain: Powertrain.petrol,
    ),
  ];

  // ============================================================= bookings

  /// A booking sitting in [target], with a history that actually reaches it.
  ///
  /// The history is *walked*, not fabricated: every entry comes from
  /// [ServiceRequest.apply] firing a real event from the real transition table,
  /// so a seeded booking cannot be in a state the machine could not have
  /// produced. That matters more than it sounds — the operator panels derive
  /// "how long has this been stuck" from the history, and a hand-written
  /// history would let a fixture claim an age the state machine disagrees with.
  ///
  /// [ageHours] is how long ago the booking *entered its current state*, which
  /// is the number every [QueueSla] colour is computed from. The steps before
  /// it are spread backwards from there.
  static ServiceRequest _booking({
    required String id,
    required String offeringId,
    required EscrowState target,
    required double ageHours,
    Car? car,
    String slot = '10:30',
    Fulfillment fulfillment = Fulfillment.workshop,
    String disputeNote = '',
    bool withProof = false,
  }) {
    final offering = MockServiceData.offerings.firstWhere(
      (o) => o.id == offeringId,
      orElse: () => MockServiceData.offerings.first,
    );
    final vehicle = car ?? cars[_rng.nextInt(cars.length)];

    // Steps are one "working gap" apart, ending [ageHours] ago. Six hours is
    // long enough that no two entries share a timestamp and short enough that
    // a booking's whole life fits inside a plausible few days.
    final path = _pathTo(target);
    const gap = 6.0;
    final startedAt = hoursAgo(ageHours + gap * path.length);

    var request = ServiceRequest(
      id: id,
      offering: offering,
      car: vehicle,
      plate: vehicle.plate ?? '',
      fulfillment: fulfillment,
      slot: slot,
      addOns: const [],
      total: offering.price ?? 0,
      escrow: EscrowState.createdPendingPayment,
      createdAt: startedAt,
      history: [
        EscrowEntry(
          state: EscrowState.createdPendingPayment,
          actor: EscrowActor.customer,
          at: startedAt,
        ),
      ],
    );

    for (final (i, step) in path.indexed) {
      request = request.apply(
        step.event,
        actor: step.actor,
        at: hoursAgo(ageHours + gap * (path.length - 1 - i)),
        disputeNote: step.event == EscrowEvent.raiseIssue ? disputeNote : null,
        proof: step.event == EscrowEvent.submitProof
            ? _proof(id, partBox: false)
            : null,
      );
    }

    // A proof on a booking that has already moved past `proofSubmitted` — the
    // customer's approval screen still shows the evidence they approved on.
    if (withProof && request.proof == null) {
      request = request.copyWith(proof: _proof(id, partBox: false));
    }
    return request;
  }

  static ProofOfWork _proof(String requestId, {required bool partBox}) =>
      ProofOfWork(
        id: derivedGuid('proof', requestId),
        requestId: requestId,
        notes: 'تم تنفيذ العمل وفحص السيارة قبل التسليم.',
        submittedAt: hoursAgo(6),
        media: [
          mockProofPhoto(
            id: mockProofMediaId(requestId, 1),
            fileName: 'proof-$requestId-1.jpg',
            caption: 'بعد الإنجاز',
          ),
          if (partBox)
            mockProofPhoto(
              id: mockProofMediaId(requestId, 2),
              fileName: 'proof-$requestId-box.jpg',
              caption: 'علبة القطعة',
            ),
        ],
        includesPartBoxPhoto: partBox,
      );

  /// The shortest legal event sequence from `createdPendingPayment` to
  /// [target], as (event, actor) pairs. Read off the transition table's own
  /// shape rather than duplicating it — an event that stops being legal makes
  /// the seed fail loudly instead of producing an impossible booking.
  static List<({EscrowEvent event, EscrowActor actor})> _pathTo(
      EscrowState target) {
    const held = (event: EscrowEvent.confirmFundsHeld, actor: EscrowActor.founder);
    const accepted = (event: EscrowEvent.acceptJob, actor: EscrowActor.workshop);
    const started = (event: EscrowEvent.startWork, actor: EscrowActor.workshop);
    const proofed = (event: EscrowEvent.submitProof, actor: EscrowActor.workshop);
    const handed =
        (event: EscrowEvent.handOffForApproval, actor: EscrowActor.system);

    return switch (target) {
      EscrowState.createdPendingPayment => const [],
      EscrowState.cancelled => const [
          (event: EscrowEvent.cancelBooking, actor: EscrowActor.customer),
        ],
      EscrowState.fundsHeld => const [held],
      EscrowState.refunded => const [
          held,
          (event: EscrowEvent.rejectJob, actor: EscrowActor.workshop),
        ],
      EscrowState.acceptedByWorkshop => const [held, accepted],
      EscrowState.inProgress => const [held, accepted, started],
      EscrowState.proofSubmitted => const [held, accepted, started, proofed],
      EscrowState.awaitingApproval =>
        const [held, accepted, started, proofed, handed],
      EscrowState.releasedToWorkshop => const [
          held,
          accepted,
          started,
          proofed,
          handed,
          (event: EscrowEvent.approve, actor: EscrowActor.customer),
        ],
      EscrowState.disputed => const [
          held,
          accepted,
          started,
          proofed,
          handed,
          (event: EscrowEvent.raiseIssue, actor: EscrowActor.customer),
        ],
      // The quote phase is not reachable from `createdPendingPayment` — a
      // custom-quote booking starts before it. Those are built by
      // [_partBooking] instead.
      EscrowState.requested ||
      EscrowState.quoted ||
      EscrowState.quoteAccepted =>
        throw StateError(
          'A quote-phase booking starts at `requested`; use _partBooking',
        ),
    };
  }

  /// A "part + installation" booking (spec §6), which enters the machine three
  /// states earlier than a catalogue one.
  static ServiceRequest _partBooking({
    required String id,
    required String providerId,
    required EscrowState target,
    required double ageHours,
    required PartRequest part,
    Car? car,
    Quote? quote,
  }) {
    final vehicle = car ?? cars[_rng.nextInt(cars.length)];
    const gap = 8.0;
    final steps = switch (target) {
      EscrowState.requested => 0,
      EscrowState.quoted => 1,
      EscrowState.quoteAccepted => 2,
      _ => 4,
    };

    var request = ServiceRequest.partInstall(
      id: id,
      provider: providerById(providerId),
      car: vehicle,
      plate: vehicle.plate ?? '',
      part: part,
      fulfillment: Fulfillment.workshop,
      createdAt: hoursAgo(ageHours + gap * steps),
    );
    if (target == EscrowState.requested) return request;

    request = request.apply(
      EscrowEvent.submitQuote,
      actor: EscrowActor.workshop,
      at: hoursAgo(ageHours + gap * (steps - 1)),
      quote: quote,
    );
    if (target == EscrowState.quoted) return request;

    request = request.apply(
      EscrowEvent.acceptQuote,
      actor: EscrowActor.customer,
      at: hoursAgo(ageHours + gap * (steps - 2)),
    );
    if (target == EscrowState.quoteAccepted) return request;

    // Past the quote phase it rejoins the shared path — and skips "accept",
    // because a workshop that quoted a job has already agreed to do it.
    request = request
        .apply(EscrowEvent.proceedToPayment,
            actor: EscrowActor.system, at: hoursAgo(ageHours + gap * 2))
        .apply(EscrowEvent.confirmFundsHeld,
            actor: EscrowActor.founder, at: hoursAgo(ageHours + gap))
        .apply(EscrowEvent.autoAcceptQuotedJob,
            actor: EscrowActor.system, at: hoursAgo(ageHours + gap * 0.5));
    if (target == EscrowState.acceptedByWorkshop) return request;

    return request.apply(EscrowEvent.startWork,
        actor: EscrowActor.workshop, at: hoursAgo(ageHours));
  }

  /// Every seeded booking, newest first.
  ///
  /// Reaches **all thirteen** [EscrowState] values. Several ages are chosen
  /// against a specific [QueueSla] threshold and are commented where they are;
  /// changing one of those numbers changes what an operator screen looks like
  /// on a cold start, so they are not arbitrary.
  static final requests = <ServiceRequest>[
    // ---------------------------------------- awaiting the founder's money
    // `QueueSla.founder` is 4h: below 2/3 of it is calm, past it is red.
    _booking(
      id: mockId2101,
      offeringId: mockOfferingId(mockIdP1, mockIdMajor),
      target: EscrowState.createdPendingPayment,
      ageHours: 0.7,
      car: cars[0],
    ),
    _booking(
      id: mockId2102,
      offeringId: mockOfferingId(mockIdP2, mockIdFull),
      target: EscrowState.createdPendingPayment,
      ageHours: 3.1, // past 2/3 × 4h — amber
      car: cars[1],
    ),
    _booking(
      id: mockId2103,
      offeringId: mockOfferingId(mockIdP6, mockIdAc),
      target: EscrowState.createdPendingPayment,
      ageHours: 6.5, // past 4h — red
      car: cars[4],
    ),

    // ----------------------------------------------- waiting on a workshop
    // `QueueSla.workshop` is 24h.
    _booking(
      id: mockId2104,
      offeringId: mockOfferingId(mockIdP4, mockIdExpress),
      target: EscrowState.fundsHeld,
      ageHours: 2,
      car: cars[1],
    ),
    _booking(
      id: mockId2105,
      offeringId: mockOfferingId(mockIdP8, mockIdExpress),
      target: EscrowState.fundsHeld,
      ageHours: 17.5, // past 2/3 × 24h — amber
      car: cars[2],
    ),
    _booking(
      id: mockId2106,
      offeringId: mockOfferingId(mockIdP5, mockIdMajor),
      target: EscrowState.fundsHeld,
      ageHours: 30, // past 24h — red
      car: cars[5],
    ),
    _booking(
      id: mockId2107,
      offeringId: mockOfferingId(mockIdP9, mockIdFull),
      target: EscrowState.acceptedByWorkshop,
      ageHours: 5,
    ),
    _booking(
      id: mockId2108,
      offeringId: mockOfferingId(mockIdP12, mockIdMajor),
      target: EscrowState.acceptedByWorkshop,
      ageHours: 26,
      car: cars[2],
    ),
    _booking(
      id: mockId2109,
      offeringId: mockOfferingId(mockIdP1, mockIdFull),
      target: EscrowState.inProgress,
      ageHours: 3,
      car: cars[0],
    ),
    _booking(
      id: mockId2110,
      offeringId: mockOfferingId(mockIdP2, mockIdDetailing),
      target: EscrowState.inProgress,
      ageHours: 14,
      fulfillment: Fulfillment.pickup,
    ),
    _booking(
      id: mockId2111,
      offeringId: mockOfferingId(mockIdP10, mockIdBattery),
      target: EscrowState.inProgress,
      ageHours: 39,
      car: cars[5],
    ),
    _booking(
      id: mockId2112,
      offeringId: mockOfferingId(mockIdP11, mockIdTyres),
      target: EscrowState.proofSubmitted,
      ageHours: 1.5,
      car: cars[4],
    ),
    _booking(
      id: mockId2113,
      offeringId: mockOfferingId(mockIdP6, mockIdExpress),
      target: EscrowState.proofSubmitted,
      ageHours: 20,
    ),

    // -------------------------------------------- waiting on the customer
    // The approval window is 72h; the reminder lead is 24h before that.
    _booking(
      id: mockId2114,
      offeringId: mockOfferingId(mockIdP1, mockIdExpress),
      target: EscrowState.awaitingApproval,
      ageHours: 2,
      car: cars[0],
    ),
    _booking(
      id: mockId2115,
      offeringId: mockOfferingId(mockIdP4, mockIdTyres),
      target: EscrowState.awaitingApproval,
      ageHours: 51, // inside the 24h reminder lead — the nudge is showing
      car: cars[1],
    ),
    _booking(
      id: mockId2116,
      offeringId: mockOfferingId(mockIdP8, mockIdEvCheck),
      target: EscrowState.awaitingApproval,
      ageHours: 80, // past 72h — the automatic release is due
      car: cars[3],
    ),

    // ------------------------------------------------------------ disputes
    _booking(
      id: mockId2117,
      offeringId: mockOfferingId(mockIdP9, mockIdDetailing),
      target: EscrowState.disputed,
      ageHours: 1.2, // inside `QueueSla.founder`
      disputeNote:
          'التلميع ترك خطوطاً واضحة على غطاء المحرك، وما كانت موجودة قبل.',
    ),
    _booking(
      id: mockId2118,
      offeringId: mockOfferingId(mockIdP5, mockIdAc),
      target: EscrowState.disputed,
      ageHours: 9, // well past 4h — red in the founder's queue
      car: cars[5],
      disputeNote:
          'المكيف رجع يضعف بعد يومين من التعبئة. أظن فيه تسريب ما انفحص.',
    ),

    // --------------------------------------------------- settled, and how
    _booking(
      id: mockId2119,
      offeringId: mockOfferingId(mockIdP1, mockIdMajor),
      target: EscrowState.releasedToWorkshop,
      ageHours: 30,
      car: cars[0],
      withProof: true,
    ),
    _booking(
      id: mockId2120,
      offeringId: mockOfferingId(mockIdP2, mockIdExpress),
      target: EscrowState.releasedToWorkshop,
      ageHours: 96,
      withProof: true,
    ),
    _booking(
      id: mockId2121,
      offeringId: mockOfferingId(mockIdP4, mockIdDetailing),
      target: EscrowState.releasedToWorkshop,
      ageHours: 240,
      car: cars[1],
      withProof: true,
    ),
    _booking(
      id: mockId2122,
      offeringId: mockOfferingId(mockIdP6, mockIdMajor),
      target: EscrowState.releasedToWorkshop,
      ageHours: 460,
      car: cars[4],
      withProof: true,
    ),
    _booking(
      id: mockId2123,
      offeringId: mockOfferingId(mockIdP8, mockIdBattery),
      target: EscrowState.releasedToWorkshop,
      ageHours: 700,
      car: cars[2],
      withProof: true,
    ),
    _booking(
      id: mockId2124,
      offeringId: mockOfferingId(mockIdP5, mockIdFull),
      target: EscrowState.releasedToWorkshop,
      ageHours: 980,
      car: cars[5],
      withProof: true,
    ),
    _booking(
      id: mockId2125,
      offeringId: mockOfferingId(mockIdP9, mockIdMajor),
      target: EscrowState.releasedToWorkshop,
      ageHours: 1340,
      withProof: true,
    ),
    _booking(
      id: mockId2126,
      offeringId: mockOfferingId(mockIdP2, mockIdAc),
      target: EscrowState.releasedToWorkshop,
      ageHours: 1720,
      car: cars[3],
      withProof: true,
    ),
    // Roughly ninety days back — the far edge of the Money tab's history.
    _booking(
      id: mockId2127,
      offeringId: mockOfferingId(mockIdP1, mockIdDiag),
      target: EscrowState.releasedToWorkshop,
      ageHours: 2090,
      car: cars[0],
      withProof: true,
    ),
    _booking(
      id: mockId2128,
      offeringId: mockOfferingId(mockIdP12, mockIdContracts),
      target: EscrowState.releasedToWorkshop,
      ageHours: 2140,
      car: cars[2],
      withProof: true,
    ),

    // --------------------------------------------------- the two endings
    _booking(
      id: mockId2129,
      offeringId: mockOfferingId(mockIdP7, mockIdExpress),
      target: EscrowState.cancelled,
      ageHours: 62,
    ),
    _booking(
      id: mockId2130,
      offeringId: mockOfferingId(mockIdP10, mockIdDetailing),
      target: EscrowState.cancelled,
      ageHours: 310,
      car: cars[5],
    ),
    _booking(
      id: mockId2131,
      offeringId: mockOfferingId(mockIdP11, mockIdSos),
      target: EscrowState.refunded,
      ageHours: 130,
      car: cars[4],
    ),
    _booking(
      id: mockId2132,
      offeringId: mockOfferingId(mockIdP7, mockIdBattery),
      target: EscrowState.refunded,
      ageHours: 520,
    ),

    // ------------------------------------------- part + installation (§6)
    _partBooking(
      id: mockId2133,
      providerId: mockIdP1,
      target: EscrowState.requested,
      ageHours: 4,
      car: cars[0],
      part: const PartRequest(
        description: 'مساعدين أمامي يمين ويسار',
        symptom: 'صوت طقطقة عند المطبات وميلان في المنعطفات',
      ),
    ),
    _partBooking(
      id: mockId2134,
      providerId: mockIdP2,
      target: EscrowState.quoted,
      ageHours: 11,
      car: cars[1],
      part: const PartRequest(
        description: 'دينمو (ألترنيتر) بديل',
        preferredBrand: 'أصلي أو Denso',
        symptom: 'لمبة البطارية تضيء أثناء القيادة',
      ),
      quote: Quote(
        id: mockIdQ2134,
        requestId: mockId2134,
        workshopId: mockIdP2,
        partDescription: 'دينمو Denso أصلي',
        partPrice: 64,
        laborPrice: 18,
        partBrand: 'Denso',
        warrantyDays: 180,
        note: 'القطعة متوفرة خلال يومين.',
        createdAt: hoursAgo(11),
      ),
    ),
    _partBooking(
      id: mockId2135,
      providerId: mockIdP4,
      target: EscrowState.quoteAccepted,
      ageHours: 2,
      car: cars[1],
      part: const PartRequest(description: 'طقم فحمات فرامل أمامية'),
      quote: Quote(
        id: mockIdQ2135,
        requestId: mockId2135,
        workshopId: mockIdP4,
        partDescription: 'فحمات أمامية سيراميك',
        partPrice: 22,
        laborPrice: 9,
        warrantyDays: 90,
        createdAt: hoursAgo(18),
      ),
    ),
    _partBooking(
      id: mockId2136,
      providerId: mockIdP9,
      target: EscrowState.inProgress,
      ageHours: 7,
      car: cars[2],
      part: const PartRequest(
        description: 'ردياتير بديل',
        symptom: 'حرارة ترتفع في الزحمة',
      ),
      quote: Quote(
        id: mockIdQ2136,
        requestId: mockId2136,
        workshopId: mockIdP9,
        partDescription: 'ردياتير بديل مع خرطوم علوي',
        partPrice: 78,
        laborPrice: 25,
        warrantyDays: 365,
        createdAt: hoursAgo(40),
      ),
    ),

    // A few more completed jobs so the workshop panel's Performance tab has a
    // population worth computing an acceptance rate over.
    _booking(
      id: mockId2137,
      offeringId: mockOfferingId(mockIdP1, mockIdAc),
      target: EscrowState.releasedToWorkshop,
      ageHours: 380,
      car: cars[0],
      withProof: true,
    ),
    _booking(
      id: mockId2138,
      offeringId: mockOfferingId(mockIdP1, mockIdExpress),
      target: EscrowState.releasedToWorkshop,
      ageHours: 620,
      car: cars[1],
      withProof: true,
    ),
    _booking(
      id: mockId2139,
      offeringId: mockOfferingId(mockIdP1, mockIdContracts),
      target: EscrowState.refunded,
      ageHours: 840,
      car: cars[0],
    ),
    _booking(
      id: mockId2140,
      offeringId: mockOfferingId(mockIdP2, mockIdTyres),
      target: EscrowState.releasedToWorkshop,
      ageHours: 1100,
      car: cars[3],
      withProof: true,
    ),
  ];

  // ============================================================== reviews

  /// Reviews in both directions, written only against bookings that actually
  /// reached `releasedToWorkshop` — which is the entire verification mechanism
  /// (`review.dart`), so a seed that broke it would be seeding fake social
  /// proof.
  ///
  /// Deliberately uneven: `p1` has several, `p12` has exactly one, and the
  /// workshops nobody has used have none at all. Every screen that prints a
  /// rating has to render "no rating" as a different thing from a low one, and
  /// it can only be checked against data that contains the case.
  static final reviews = <Review>[
    Review(
      id: mockIdRevS1,
      bookingId: mockId2119,
      authorId: 'u-seed-1',
      subjectId: mockIdP1,
      direction: ReviewDirection.customerToWorkshop,
      rating: 5,
      comment: 'شرحوا لي كل شي قبل ما يبدون، والسيارة رجعت نظيفة.',
      serviceType: const L('صيانة شاملة', 'Major service'),
      createdAt: hoursAgo(26),
    ),
    Review(
      id: mockIdRevS2,
      bookingId: mockId2119,
      authorId: mockIdP1,
      subjectId: 'u-seed-1',
      direction: ReviewDirection.workshopToCustomer,
      rating: 5,
      comment: 'وصل في وقته وكان واضح في وصف المشكلة.',
      serviceType: const L('صيانة شاملة', 'Major service'),
      createdAt: hoursAgo(25),
    ),
    Review(
      id: mockIdRevS3,
      bookingId: mockId2120,
      authorId: 'u-seed-2',
      subjectId: mockIdP2,
      direction: ReviewDirection.customerToWorkshop,
      rating: 4,
      comment: 'خدمة سريعة، بس الانتظار كان أطول من المتوقع.',
      serviceType: const L('صيانة سريعة', 'Express service'),
      createdAt: hoursAgo(90),
    ),
    Review(
      id: mockIdRevS4,
      bookingId: mockId2121,
      authorId: 'u-seed-1',
      subjectId: mockIdP4,
      direction: ReviewDirection.customerToWorkshop,
      rating: 5,
      serviceType: const L('تلميع السيارة', 'Car detailing'),
      createdAt: hoursAgo(232),
    ),
    Review(
      id: mockIdRevS5,
      bookingId: mockId2122,
      authorId: 'u-seed-3',
      subjectId: mockIdP6,
      direction: ReviewDirection.customerToWorkshop,
      rating: 4,
      comment: 'سعر واضح من البداية وما زاد شي.',
      serviceType: const L('صيانة شاملة', 'Major service'),
      createdAt: hoursAgo(450),
    ),
    /// Written after a dispute that settled. §8 labels these rather than
    /// hiding them, and that rule needs at least one case to be visible on.
    Review(
      id: mockIdRevS6,
      bookingId: mockId2123,
      authorId: 'u-seed-2',
      subjectId: mockIdP8,
      direction: ReviewDirection.customerToWorkshop,
      rating: 3,
      comment: 'صار سوء فهم على السعر، بس حلّوه معي بشكل عادل في النهاية.',
      serviceType: const L('تغيير البطارية', 'Battery replacement'),
      createdAt: hoursAgo(690),
      afterDispute: true,
    ),
    Review(
      id: mockIdRevS7,
      bookingId: mockId2124,
      authorId: 'u-seed-3',
      subjectId: mockIdP5,
      direction: ReviewDirection.customerToWorkshop,
      rating: 5,
      serviceType: const L('صيانة كاملة', 'Full service'),
      createdAt: hoursAgo(970),
    ),
    /// `p12` has exactly one review — the threshold case the ratings board
    /// must refuse to rank on.
    Review(
      id: mockIdRevS8,
      bookingId: mockId2128,
      authorId: 'u-seed-4',
      subjectId: mockIdP12,
      direction: ReviewDirection.customerToWorkshop,
      rating: 5,
      comment: 'أفضل ورشة جربتها في الباطنة.',
      serviceType: const L('عقد صيانة سنوي', 'Annual service contract'),
      createdAt: hoursAgo(2130),
    ),
    Review(
      id: mockIdRevS9,
      bookingId: mockId2137,
      authorId: 'u-seed-1',
      subjectId: mockIdP1,
      direction: ReviewDirection.customerToWorkshop,
      rating: 4,
      serviceType: const L('عناية بالمكيف', 'AC care'),
      createdAt: hoursAgo(370),
    ),
    Review(
      id: mockIdRevS10,
      bookingId: mockId2138,
      authorId: 'u-seed-2',
      subjectId: mockIdP1,
      direction: ReviewDirection.customerToWorkshop,
      rating: 5,
      comment: 'ما حاولوا يبيعون لي أشياء ما احتاجها. هذا اللي رجّعني.',
      serviceType: const L('صيانة سريعة', 'Express service'),
      createdAt: hoursAgo(610),
    ),
    Review(
      id: mockIdRevS11,
      bookingId: mockId2140,
      authorId: 'u-seed-4',
      subjectId: mockIdP2,
      direction: ReviewDirection.customerToWorkshop,
      rating: 4,
      serviceType: const L('تغيير وترصيص الإطارات', 'Tyre change & balancing'),
      createdAt: hoursAgo(1080),
    ),
  ];

  // ============================================================== payouts

  /// Transfers the founder has already made by hand (§5, tab 3).
  ///
  /// They stop short of the newest releases on purpose: the Money tab's whole
  /// job is showing what is *still owed*, and a ledger where everything is
  /// settled cannot demonstrate that.
  static final payouts = <PayoutRecord>[
    PayoutRecord(
      id: mockIdPo1,
      providerId: mockIdP1,
      amount: 118.60,
      periodFrom: daysAgo(90),
      periodTo: daysAgo(60),
      markedAt: daysAgo(58),
      note: 'تحويل بنكي — دفعة الشهر',
    ),
    PayoutRecord(
      id: mockIdPo2,
      providerId: mockIdP2,
      amount: 74.25,
      periodFrom: daysAgo(90),
      periodTo: daysAgo(60),
      markedAt: daysAgo(58),
    ),
    PayoutRecord(
      id: mockIdPo3,
      providerId: mockIdP1,
      amount: 62.40,
      periodFrom: daysAgo(60),
      periodTo: daysAgo(30),
      markedAt: daysAgo(28),
    ),
    PayoutRecord(
      id: mockIdPo4,
      providerId: mockIdP6,
      amount: 48.00,
      periodFrom: daysAgo(60),
      periodTo: daysAgo(30),
      markedAt: daysAgo(27),
      note: 'خصم عمولة الشهر محسوب',
    ),
    PayoutRecord(
      id: mockIdPo5,
      providerId: mockIdP5,
      amount: 26.60,
      periodFrom: daysAgo(60),
      periodTo: daysAgo(30),
      markedAt: daysAgo(27),
    ),
  ];

  // ================================================================ audit

  /// The audit lines that pre-date this session.
  ///
  /// Only the decisions a human made: the escrow transitions on the seeded
  /// bookings are already recorded on those bookings' own histories, and
  /// duplicating all forty of them here would make the founder's log unreadable
  /// on its first open. Everything written *during* a session is appended by
  /// the repository, from its single write point.
  static final audit = <AuditEntry>[
    AuditEntry(
      id: mockIdAu1,
      at: daysAgo(88),
      actor: EscrowActor.founder,
      actorId: 'founder',
      action: 'provider.approved',
      subjectType: AuditSubjectType.provider,
      subjectId: mockIdP12,
      fromState: ProviderOnboardingStage.verified.key,
      toState: ProviderOnboardingStage.approved.key,
      note: 'سجل تجاري ساري ومطابق للاسم.',
    ),
    AuditEntry(
      id: mockIdAu2,
      at: daysAgo(64),
      actor: EscrowActor.founder,
      actorId: 'founder',
      action: 'provider.approved',
      subjectType: AuditSubjectType.provider,
      subjectId: mockIdP10,
      fromState: ProviderOnboardingStage.verified.key,
      toState: ProviderOnboardingStage.approved.key,
    ),
    AuditEntry(
      id: mockIdAu3,
      at: hoursAgo(52),
      actor: EscrowActor.founder,
      actorId: 'founder',
      action: 'provider.rejected',
      subjectType: AuditSubjectType.provider,
      subjectId: mockIdP14,
      fromState: ProviderOnboardingStage.documentsSubmitted.key,
      toState: ProviderOnboardingStage.suspended.key,
      note: 'صورة السجل التجاري غير واضحة — الرقم غير مقروء.',
    ),
    AuditEntry(
      id: mockIdAu4,
      at: hoursAgo(9),
      actor: EscrowActor.founder,
      actorId: 'founder',
      action: 'provider.verified',
      subjectType: AuditSubjectType.provider,
      subjectId: mockIdP13,
      fromState: ProviderOnboardingStage.documentsSubmitted.key,
      toState: ProviderOnboardingStage.verified.key,
      note: 'الوثائق مقروءة ومطابقة — بانتظار قرار التفعيل.',
    ),
    AuditEntry(
      id: mockIdAu5,
      at: daysAgo(58),
      actor: EscrowActor.founder,
      actorId: 'founder',
      action: 'payout.marked',
      subjectType: AuditSubjectType.payout,
      subjectId: mockIdPo1,
      note: 'تحويل بنكي — دفعة الشهر',
    ),
    AuditEntry(
      id: mockIdAu6,
      at: daysAgo(12),
      actor: EscrowActor.founder,
      actorId: 'founder',
      action: 'offer.enabled',
      subjectType: AuditSubjectType.offer,
      subjectId: mockIdOfP1Major,
      toState: 'active',
    ),
  ];
}
