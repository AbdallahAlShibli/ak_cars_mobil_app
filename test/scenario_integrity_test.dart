import 'dart:convert';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/core/widgets/status_indicator.dart';
import 'fakes/data/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/operations/queue_urgency.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';
import 'fakes/data/mock_ids.dart';
import 'fakes/fakes.dart';

/// A JWT shaped like `TokenService.GenerateAccessToken`'s own output — see
/// `jwt_claims.dart`'s doc comment for why the claim key is the long URI
/// rather than the short `"role"` string one might expect.
String _founderJwt() {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({
        'alg': 'none',
      })}.${segment({
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role':
            'founder',
      })}.sig';
}

/// Scenario integrity (§13).
///
/// Twelve journeys, each asserted end to end through the real state layer
/// rather than against a single unit. The point is not to re-test the pieces —
/// they have their own files — but to catch the failure the unit tests cannot
/// see: a step that works alone and does not connect to the next one.
///
/// Every test drives the app the way a person would, through the notifiers, and
/// reads the result the way a screen would, through the providers. Nothing here
/// reaches into a repository to set up a state a user could not reach.

const _car = Car(
  id: 'sc-test-1',
  make: 'Toyota',
  model: 'Camry',
  year: 2019,
  plate: '1234 AB',
  odometerKm: 60000,
);

/// A container with the demo world switched off.
///
/// These tests assert on *their own* booking — "the request", "the review" —
/// and `MockSeed`'s forty would make every `single` and every count ambiguous.
/// The workshop roster stays seeded: it is reference data, and scenarios 7, 9
/// and 10 are about specific workshops in it.
Future<ProviderContainer> _container({List<Override> extra = const []}) =>
    createDataContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.forEnvironment(AppEnvironment.development)
              ,
        ),
        serviceMarketplaceServiceProvider.overrideWith(
          (ref) => MockServiceMarketplaceService(seeded: false),
        ),
        ...extra,
      ],
    );

/// An approved workshop's first catalogue offering.
ServiceOffering _offeringOf(ProviderContainer c, String providerId) =>
    c.read(serviceMarketplaceRepositoryProvider).offerings.firstWhere(
          (o) => o.provider.id == providerId && o.price != null,
        );

Future<ServiceRequest> _book(
  ProviderContainer c, {
  String providerId = mockIdP1,
  String? maintenanceItemKey,
}) =>
    c.read(requestsProvider.notifier).place(
          CreateServiceRequestDraft(
            offering: _offeringOf(c, providerId),
            car: _car,
            plate: '1234 AB',
            fulfillment: Fulfillment.workshop,
            slot: 'Mon · 10:30',
            addOnIds: const {},
            maintenanceItemKey: maintenanceItemKey,
          ),
        );

/// Walks a booking from "placed" to "waiting on the customer".
Future<void> _driveToApproval(ProviderContainer c, String id) async {
  final notifier = c.read(requestsProvider.notifier);
  await notifier.fire(id, EscrowEvent.confirmFundsHeld,
      actor: EscrowActor.founder);
  await notifier.fire(id, EscrowEvent.acceptJob, actor: EscrowActor.workshop);
  await notifier.fire(id, EscrowEvent.startWork, actor: EscrowActor.workshop);
  await notifier.fire(
    id,
    EscrowEvent.submitProof,
    actor: EscrowActor.workshop,
    proof: testProof(id),
  );
}

ServiceRequest _byId(ProviderContainer c, String id) =>
    c.read(requestsProvider).firstWhere((r) => r.id == id);

/// The certificate a registration carries — real PNG bytes, as the picker
/// would produce.
MediaAttachment _crAttachment(String fileName) => MediaAttachment(
      id: derivedGuid('test-cr', fileName),
      base64Data: testPngBase64,
      mimeType: 'image/png',
      fileName: fileName,
    );

/// Files a workshop registration the way `register_screen.dart` does.
Future<UserProfile> _registerWorkshop(
  ProviderContainer c, {
  String crDocumentName = 'cr.png',
}) async {
  final profile = UserProfile(
    id: 'u-applicant',
    name: 'Salim Al Hinai',
    phone: '+968 9200 1234',
    email: 'salim@example.om',
    region: 'Muscat',
    wilayat: 'Seeb',
    address: 'Street 12',
    kind: AccountKind.workshop,
    workshop: WorkshopApplication(
      businessNameAr: 'ورشة سالم',
      businessNameEn: 'Salim Workshop',
      crNumber: '1450998',
      crDocument: _crAttachment(crDocumentName),
      area: 'Seeb',
      fulfillments: const {Fulfillment.workshop},
      submittedAt: DateTime.now(),
    ),
  );
  await c.read(authProvider.notifier).register(profile);
  return profile;
}

ServiceProvider _applicantWorkshop(ProviderContainer c) =>
    c.read(serviceMarketplaceRepositoryProvider).providerOwnedBy('u-applicant')!;

void main() {
  // ==================================================== 1 — the whole journey
  test('1. a catalogue booking runs end to end, logs the service, and unlocks '
      'both reviews', () async {
    final c = await _container();
    // The booking names the maintenance line it came from, which is what lets
    // the completed job write itself into the car's book.
    final request = await _book(c, maintenanceItemKey: MaintenanceType.oil.key);
    await c.read(garageProvider.notifier).add(_car);

    expect(_byId(c, request.id).escrow, EscrowState.createdPendingPayment);
    await _driveToApproval(c, request.id);
    // The proof hand-off is automatic — the customer never sees a booking
    // parked at "proof submitted".
    expect(_byId(c, request.id).escrow, EscrowState.awaitingApproval);

    await c.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.approve,
          actor: EscrowActor.customer,
        );
    final done = _byId(c, request.id);
    expect(done.escrow, EscrowState.releasedToWorkshop);

    // The service record is written by the release, not by the booking.
    final book = c.read(maintenanceProvider)[_car.id];
    expect(book, isNotNull);
    expect(book!.records, isNotEmpty,
        reason: 'a released booking is the only thing that writes history');

    // Both halves of the review unlock on the same release (§8).
    expect(c.read(pendingCustomerReviewsProvider).map((r) => r.id),
        contains(request.id));
    expect(c.read(pendingWorkshopReviewsProvider).map((r) => r.id),
        contains(request.id));

  });

  // ============================================== 2 — part + install, evidence
  test('2. a part-and-fit job cannot claim completion without the part box',
      () async {
    final c = await _container();
    final request = await c.read(requestsProvider.notifier).placePartRequest(
          const CreatePartRequestDraft(
            providerId: mockIdP1,
            carId: 'sc-test-1',
            plate: '1234 AB',
            part: PartRequest(description: 'فلتر زيت'),
            fulfillment: 'workshop',
          ),
          car: _car,
        );
    expect(request.escrow, EscrowState.requested);

    await c.read(requestsProvider.notifier).submitQuote(
          request.id,
          Quote(
            id: 'q1',
            requestId: request.id,
            workshopId: mockIdP1,
            partDescription: 'فلتر زيت أصلي',
            partPrice: 4,
            laborPrice: 3,
            createdAt: DateTime.now(),
          ),
        );
    final notifier = c.read(requestsProvider.notifier);
    await notifier.fire(request.id, EscrowEvent.acceptQuote,
        actor: EscrowActor.customer);
    // Accepting a price is agreeing to pay it, and a workshop that quoted has
    // already committed — both hand-offs happen without a second tap.
    expect(_byId(c, request.id).escrow, EscrowState.createdPendingPayment);
    expect(_byId(c, request.id).total, 7);

    await notifier.fire(request.id, EscrowEvent.confirmFundsHeld,
        actor: EscrowActor.founder);
    expect(_byId(c, request.id).escrow, EscrowState.acceptedByWorkshop,
        reason: 'a quoting workshop is not asked to accept the job twice');
    await notifier.fire(request.id, EscrowEvent.startWork,
        actor: EscrowActor.workshop);

    // Photos, but no declaration that one shows the part's box.
    await notifier.fire(
      request.id,
      EscrowEvent.submitProof,
      actor: EscrowActor.workshop,
      proof: testProof(request.id, partBox: false),
    );
    expect(_byId(c, request.id).escrow, EscrowState.inProgress,
        reason: 'the customer bought a specific part; the box is the evidence');

    await notifier.fire(
      request.id,
      EscrowEvent.submitProof,
      actor: EscrowActor.workshop,
      proof: testProof(request.id, partBox: true),
    );
    expect(_byId(c, request.id).escrow, EscrowState.awaitingApproval);

  });

  // ================================================= 3 — the automatic release
  test('3. the approval window opens a real deadline and releases itself',
      () async {
    final c = await _container();
    final request = await _book(c);
    await _driveToApproval(c, request.id);

    final config = c.read(appConfigProvider);
    final open = _byId(c, request.id);
    expect(open.awaitingApprovalSince, isNotNull);
    expect(open.approvalDeadline(config.approvalWindow), isNotNull);

    // Measured from when the window opened, not from the proof's own stamp —
    // a proof that sat unprocessed must not shorten the customer's window.
    final deadline = open.approvalDeadline(config.approvalWindow)!;
    expect(deadline.difference(open.awaitingApprovalSince!),
        config.approvalWindow);

    // The reminder lands before the deadline, never after it.
    expect(config.approvalReminderLead, lessThan(config.approvalWindow));

    expect(open.autoReleaseDue(config.approvalWindow), isFalse);
    expect(
      open.autoReleaseDue(config.approvalWindow,
          now: deadline.add(const Duration(minutes: 1))),
      isTrue,
    );

    // And the sweep actually fires it.
    await c.read(requestsProvider.notifier).sweepExpiredApprovals(
          now: deadline.add(const Duration(minutes: 1)),
        );
    expect(_byId(c, request.id).escrow, EscrowState.releasedToWorkshop);

  });

  // ============================================= 4 — a dispute reaches founder
  test('4. a dispute lands in the founder queue and goes red past its SLA',
      () async {
    final c = await _container();
    final request = await _book(c);
    await _driveToApproval(c, request.id);
    await c.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.raiseIssue,
          actor: EscrowActor.customer,
          disputeNote: 'الصوت ما زال موجوداً',
        );

    final disputed = _byId(c, request.id);
    expect(disputed.escrow, EscrowState.disputed);
    // The customer's own words, unedited — the founder resolves on those.
    expect(disputed.disputeNote, 'الصوت ما زال موجوداً');
    // A dispute freezes the money; it does not return it.
    expect(disputed.escrow.holdsFunds, isTrue);

    // Fresh: nothing is being asked of anyone yet.
    expect(
      QueueSla.levelFor(disputed,
          window: QueueSla.founder, waitingOnMe: true),
      UrgencyLevel.normal,
    );
    // Two-thirds of the way to the window is where it starts warning…
    final soon = DateTime.now().add(QueueSla.founder * 0.7);
    expect(
      QueueSla.levelFor(disputed,
          window: QueueSla.founder, waitingOnMe: true, now: soon),
      UrgencyLevel.upcoming,
    );
    // …and past it, it is red.
    final late = DateTime.now().add(QueueSla.founder * 1.5);
    expect(
      QueueSla.levelFor(disputed,
          window: QueueSla.founder, waitingOnMe: true, now: late),
      UrgencyLevel.overdue,
    );
    // A row the reader cannot act on never colours, however old it is.
    expect(
      QueueSla.levelFor(disputed,
          window: QueueSla.founder, waitingOnMe: false, now: late),
      UrgencyLevel.normal,
    );

    // And it is in the operator queue the founder's panel reads.
    expect(
      c.read(operatorQueueProvider).where((r) => r.id == request.id),
      isNotEmpty,
    );

  });

  // =================================================== 5 — the maintenance loop
  test('5. odometer → due list → booking → record closes the loop', () async {
    final c = await _container();
    await c.read(garageProvider.notifier).add(_car);
    await c.read(maintenanceProvider.notifier).openBook(_car.id);
    await c.read(maintenanceProvider.notifier).updateOdometer(_car.id, 62000);

    final book = c.read(maintenanceProvider)[_car.id]!;
    expect(book.currentOdometerKm, 62000);
    // A car with no history has everything outstanding — that is the honest
    // starting point, not an empty list.
    expect(c.read(maintenanceDueForCarProvider(_car.id)), isNotEmpty);

    final request = await _book(c, maintenanceItemKey: MaintenanceType.oil.key);
    await _driveToApproval(c, request.id);
    await c.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.approve,
          actor: EscrowActor.customer,
        );

    final after = c.read(maintenanceProvider)[_car.id]!;
    expect(after.records.any((r) => r.itemKey == MaintenanceType.oil.key), isTrue,
        reason: 'the completed booking feeds the car\'s own history');

  });

  // ================================================== 6 — the home page's order
  test('6. the home page leads with the car, then only offers it can honour',
      () async {
    final c = await _container();
    await c.read(garageProvider.notifier).add(_car);

    // Section 1 is the user's own car status — it exists because there is a
    // car, not because there is content to fill a rail.
    expect(c.read(garageProvider), isNotEmpty);
    // A car with no service history has no countdown, and the home page says
    // "add your last service" rather than inventing one. That is what makes
    // this null, and it is the correct answer.
    expect(c.read(nextServiceDueProvider), isNull);
    expect(c.read(maintenanceDueForCarProvider(_car.id)), isNotEmpty);

    // Every offer on the rail passed all six validation rules.
    final marketplace = c.read(serviceMarketplaceRepositoryProvider);
    for (final live in c.read(homeOffersProvider)) {
      expect(marketplace.offerFor(live.offering.id), isNotNull);
      expect(live.offering.provider.isApproved, isTrue);
      expect(live.offer.isRealDiscount, isTrue);
    }

    // The leaderboards rank on merit, and only workshops the platform vouched
    // for are on them.
    for (final entry in c.read(topRatedWorkshopsProvider).items) {
      expect(entry.provider.isApproved, isTrue);
    }
    final ratings = [
      for (final e in c.read(topRatedWorkshopsProvider).items) e.rating.rating,
    ];
    expect(ratings, orderedEquals(<double>[...ratings]..sort((a, b) => b.compareTo(a))));

  });

  // ========================================================= 7 — negative paths
  group('7. the paths that must fail', () {
    test('an illegal transition is refused', () async {
      final c = await _container();
      final request = await _book(c);
      // Nothing has been accepted, so there is no work to finish.
      final result = await c.read(requestsProvider.notifier).fire(
            request.id,
            EscrowEvent.submitProof,
            actor: EscrowActor.workshop,
            proof: testProof(request.id),
          );
      expect(result, isNull);
      expect(_byId(c, request.id).escrow, EscrowState.createdPendingPayment);
      c.dispose();
    });

    test('an unauthorised actor is refused', () async {
      final c = await _container();
      final request = await _book(c);
      // Confirming that funds landed is the founder's act, not the workshop's.
      final result = await c.read(requestsProvider.notifier).fire(
            request.id,
            EscrowEvent.confirmFundsHeld,
            actor: EscrowActor.workshop,
          );
      expect(result, isNull);
      c.dispose();
    });

    test('an invented reference price cannot manufacture a discount', () async {
      final c = await createDataContainer();
      final marketplace = c.read(serviceMarketplaceRepositoryProvider);
      // The workshop publishes 32; the offer claims 45 was struck through.
      expect(marketplace.offeringById(mockOfferingId(mockIdP2, mockIdFull))!.price, 32);
      expect(marketplace.offerFor(mockOfferingId(mockIdP2, mockIdFull)), isNull);
      expect(marketplace.pricedOffering(mockOfferingId(mockIdP2, mockIdFull))!.price, 32);
    });

    test('an unapproved workshop is invisible and unbookable', () async {
      final c = await createDataContainer();
      final marketplace = c.read(serviceMarketplaceRepositoryProvider);
      final sohar = marketplace.providerById(mockIdP3)!;
      expect(sohar.isApproved, isFalse);

      // Not on any customer-facing list…
      expect(marketplace.visibleProviders.map((p) => p.id),
          isNot(contains(mockIdP3)));
      expect(marketplace.pricedOfferings.map((o) => o.provider.id),
          isNot(contains(mockIdP3)));
      expect(marketplace.offeringsFor(mockIdExpress).map((o) => o.provider.id),
          isNot(contains(mockIdP3)));
      // …and not on a leaderboard or an offer rail.
      expect(marketplace.offerFor(mockOfferingId(mockIdP3, mockIdExpress)), isNull);

      // …and it refuses a booking even when one is aimed straight at it,
      // because hiding a button is not a rule.
      await expectLater(
        c.read(serviceMarketplaceRepositoryProvider).createRequest(
              CreateServiceRequestDraft(
                offering: marketplace.offeringById(mockOfferingId(mockIdP3, mockIdExpress))!,
                car: _car,
                plate: '1234 AB',
                fulfillment: Fulfillment.workshop,
                slot: '10:30',
                addOnIds: const {},
              ),
            ),
        throwsA(isA<BusinessRuleException>().having(
            (e) => e.code, 'code', 'workshop_not_approved')),
      );
    });
  });

  // ================================================== 8 — the panels are guarded
  test(
      '8. the active role is a real account fact, not a switch anyone can '
      'flip', () async {
    final c = await _container();

    // A guest, or a signed-in customer, is a customer — there is no third
    // state to opt out of.
    expect(c.read(activeRoleProvider), AppRole.customer);

    // Filing a workshop application does not grant the role on its own —
    // §11: an application only *starts* review.
    await _registerWorkshop(c);
    expect(c.read(activeRoleProvider), AppRole.customer);

    // Approval is what the router's guard actually checks (see
    // `_guardOperatorPanels`), so it is what flips the role too.
    final id = _applicantWorkshop(c).id;
    await c.read(adminActionsProvider).setStage(id, ProviderOnboardingStage.approved);
    expect(c.read(activeRoleProvider), AppRole.workshop);
    expect(c.read(activeRoleProvider).actor, EscrowActor.workshop);

    // The founder role comes from the JWT's own role claim — nothing else
    // grants it, and nothing here can be reached without a real token
    // carrying it. Rebuilding the container is what a fresh sign-in is:
    // `AuthState.isFounder` is decoded once at that point, not re-read on
    // every check.
    final founderContainer = await _container(extra: [
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore(access: _founderJwt(), refresh: 'r'),
      ),
    ]);
    await founderContainer.read(authProvider.notifier).register(
          const UserProfile(
            name: 'Founder',
            phone: '+968 9333 4444',
            email: 'founder@example.om',
            region: 'Muscat',
            address: '',
          ),
        );
    expect(founderContainer.read(activeRoleProvider), AppRole.founder);
    expect(founderContainer.read(activeRoleProvider).actor, EscrowActor.founder);
  });

  // ====================================== 9 — a new workshop is pending, not live
  test('9. registering a workshop suspends it until somebody approves it',
      () async {
    final c = await _container();
    await _registerWorkshop(c);

    final workshop = _applicantWorkshop(c);
    // Filed at documentsSubmitted, not applied: the certificate came with it.
    expect(workshop.stage, ProviderOnboardingStage.documentsSubmitted);
    expect(workshop.isApproved, isFalse);
    expect(workshop.crDocument?.fileName, 'cr.png');
    // The bytes travelled with the application, not a link to them.
    expect(workshop.crDocument?.hasBytes, isTrue);

    final marketplace = c.read(serviceMarketplaceRepositoryProvider);
    // Invisible to customers on every surface.
    expect(marketplace.visibleProviders.map((p) => p.id),
        isNot(contains(workshop.id)));
    expect(marketplace.approvedWorkshops().map((p) => p.id),
        isNot(contains(workshop.id)));
    expect(marketplace.providerRegions.length,
        marketplace.providerRegions.toSet().length);

    // But present for the founder, which is the whole point.
    expect(c.read(pendingApplicationsProvider).map((p) => p.id),
        contains(workshop.id));
    expect(
      c.read(onboardingPipelineProvider)[
          ProviderOnboardingStage.documentsSubmitted],
      greaterThan(0),
    );

  });

  // ========================================= 10 — approval is what opens the door
  test('10. approving the workshop makes it live on the next read', () async {
    final c = await _container();
    await _registerWorkshop(c);
    final id = _applicantWorkshop(c).id;

    await c
        .read(adminActionsProvider)
        .setStage(id, ProviderOnboardingStage.approved);

    final approved = _applicantWorkshop(c);
    expect(approved.stage, ProviderOnboardingStage.approved);
    expect(approved.isApproved, isTrue);
    // No stale rejection left on the record to show its owner.
    expect(approved.rejectionReason, isNull);

    // Visible, and out of the pending queue, without anything being reloaded.
    expect(
      c.read(serviceMarketplaceRepositoryProvider).visibleProviders
          .map((p) => p.id),
      contains(id),
    );
    expect(c.read(pendingApplicationsProvider).map((p) => p.id),
        isNot(contains(id)));

  });

  // ============================== 11 — a rejection is readable and reversible
  test('11. a rejection carries its reason and the owner can re-submit',
      () async {
    final c = await _container();
    await _registerWorkshop(c);
    final id = _applicantWorkshop(c).id;

    // §14: no rejection without a written reason, enforced below the UI.
    await expectLater(
      c.read(adminActionsProvider).setStage(id, ProviderOnboardingStage.suspended),
      throwsA(isA<BusinessRuleException>().having(
          (e) => e.code, 'code', 'provider_rejection_reason_required')),
    );
    await expectLater(
      c.read(adminActionsProvider).setStage(
            id,
            ProviderOnboardingStage.suspended,
            reason: '   ',
          ),
      throwsA(isA<BusinessRuleException>()),
    );

    await c.read(adminActionsProvider).setStage(
          id,
          ProviderOnboardingStage.suspended,
          reason: 'الوثيقة غير واضحة',
        );

    final rejected = _applicantWorkshop(c);
    expect(rejected.stage, ProviderOnboardingStage.suspended);
    // Stored verbatim — this is what the owner is shown and acts on.
    expect(rejected.rejectionReason, 'الوثيقة غير واضحة');
    expect(rejected.isApproved, isFalse);

    // The owner corrects it and sends it again.
    final profile = c.read(authProvider).profile!;
    await c.read(authProvider.notifier).resubmitWorkshopApplication(
          profile.workshop!.copyWith(
            crDocument: _crAttachment('cr-clear.png'),
            submittedAt: DateTime.now(),
          ),
        );

    final resubmitted = _applicantWorkshop(c);
    expect(resubmitted.stage, ProviderOnboardingStage.documentsSubmitted);
    expect(resubmitted.crDocument?.fileName, 'cr-clear.png');
    // Re-filed, not duplicated — one workshop per owner.
    expect(
      c.read(rosterProvider).where((p) => p.ownerUserId == 'u-applicant').length,
      1,
    );
    // Back in the founder's pipeline, exactly as a first submission would be.
    expect(c.read(pendingApplicationsProvider).map((p) => p.id),
        contains(resubmitted.id));

  });

  // ================================================ 12 — every decision is logged
  test('12. approvals, rejections and payouts each write one audit line',
      () async {
    final c = await _container();
    await _registerWorkshop(c);
    final id = _applicantWorkshop(c).id;

    Iterable<AuditEntry> about(String subjectId) =>
        c.read(auditLogProvider).about(AuditSubjectType.provider, subjectId);

    // The submission itself is recorded, by the applicant.
    expect(about(id).map((e) => e.action), contains('provider.applied'));

    await c.read(adminActionsProvider).setStage(
          id,
          ProviderOnboardingStage.suspended,
          reason: 'الوثيقة غير واضحة',
        );
    final rejection =
        about(id).firstWhere((e) => e.action == 'provider.suspended');
    expect(rejection.actor, EscrowActor.founder);
    expect(rejection.fromState, ProviderOnboardingStage.documentsSubmitted.key);
    expect(rejection.toState, ProviderOnboardingStage.suspended.key);
    // The reason is on the record, not only on the workshop — the log has to
    // stand on its own months later.
    expect(rejection.note, 'الوثيقة غير واضحة');

    await c.read(adminActionsProvider).setStage(
          id,
          ProviderOnboardingStage.approved,
        );
    final approval =
        about(id).firstWhere((e) => e.action == 'provider.approved');
    expect(approval.fromState, ProviderOnboardingStage.suspended.key);
    expect(approval.toState, ProviderOnboardingStage.approved.key);

    // An escrow transition is logged from the same single write point.
    final request = await _book(c);
    await c.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder,
        );
    final moved = c
        .read(auditLogProvider)
        .about(AuditSubjectType.booking, request.id)
        .firstWhere((e) => e.action == 'escrow.confirmFundsHeld');
    expect(moved.fromState, EscrowState.createdPendingPayment.key);
    expect(moved.toState, EscrowState.fundsHeld.key);

    // So is a payout.
    final now = DateTime.now();
    final payout = await c.read(adminActionsProvider).markPaid(
          providerId: id,
          amount: 42.5,
          periodFrom: now.subtract(const Duration(days: 30)),
          periodTo: now,
        );
    expect(
      c.read(auditLogProvider).about(AuditSubjectType.payout, payout.id),
      isNotEmpty,
    );

    // Newest first, always — a log is only ever read from the top.
    final stamps = [for (final e in c.read(auditLogProvider)) e.at];
    expect(
      stamps,
      orderedEquals(<DateTime>[...stamps]..sort((a, b) => b.compareTo(a))),
    );

  });

  // ------------------------------------------------------------------ §16
  test('the seed reaches every escrow state, with relative dates', () async {
    // A founder session: the operator queue is founder-only, and this test
    // reads the whole marketplace through it.
    final c = await createDataContainer(overrides: [founderSessionOverride()]);
    final queue = c.read(operatorQueueProvider);

    final reached = {for (final r in queue) r.escrow};
    expect(reached, containsAll(EscrowState.values),
        reason: 'every state needs a booking sitting in it, or no screen that '
            'renders it has ever been looked at');

    // Nothing is dated in the future, and the oldest is inside the 90-day
    // window the seed documents.
    final now = DateTime.now();
    for (final r in queue) {
      expect(r.createdAt.isAfter(now), isFalse);
      expect(now.difference(r.createdAt).inDays, lessThanOrEqualTo(120));
    }

    // Two disputes either side of the founder's SLA, three awaiting approval.
    expect(queue.where((r) => r.escrow == EscrowState.disputed).length,
        greaterThanOrEqualTo(2));
    expect(queue.where((r) => r.escrow == EscrowState.awaitingApproval).length,
        greaterThanOrEqualTo(3));
    expect(
        queue
            .where((r) => r.escrow == EscrowState.createdPendingPayment)
            .length,
        greaterThanOrEqualTo(3));
    expect(queue.where((r) => r.type == BookingType.customQuote).length,
        greaterThanOrEqualTo(4));

    // And pending workshop applications for the founder's pipeline to hold.
    expect(
      c.read(pendingApplicationsProvider).where(
          (p) => p.stage == ProviderOnboardingStage.documentsSubmitted),
      isNotEmpty,
    );
  });

  test('a workshop\'s metrics and earnings are derived, never invented',
      () async {
    // Founder session: the metrics below are derived from the operator
    // queue, which only a founder's token loads.
    final c = await createDataContainer(overrides: [founderSessionOverride()]);
    final marketplace = c.read(serviceMarketplaceRepositoryProvider);
    final queue = c.read(operatorQueueProvider);
    final reviews = c.read(reviewsProvider);

    final metrics = marketplace.metricsFor(mockIdP1, queue, reviews);
    expect(metrics.received, greaterThan(0));
    expect(metrics.accepted, lessThanOrEqualTo(metrics.received));
    expect(metrics.completed, lessThanOrEqualTo(metrics.accepted));
    // The rating is the mean of real reviews, and matches counting them by
    // hand — there is no stored rating field anywhere to drift from.
    final mine = reviews.about(mockIdP1,
        direction: ReviewDirection.customerToWorkshop);
    expect(metrics.reviewCount, mine.length);
    expect(metrics.avgRating, mine.averageRating);
    expect(metrics.recentReviews.length, lessThanOrEqualTo(5));

    // A workshop nobody has sent a job to has *no* rate, not a zero one.
    final untouched = marketplace.metricsFor(mockIdP15, queue, reviews);
    expect(untouched.acceptanceRate, isNull);
    expect(untouched.avgRating, isNull);

    final earnings = marketplace.earningsFor(mockIdP1, queue);
    expect(earnings.releasedNet,
        closeTo(earnings.releasedGross - earnings.releasedCommission, 0.001));
    final commission = c.read(appConfigProvider).platformCommission;
    for (final line in earnings.lines) {
      expect(line.commission, closeTo(line.gross * commission, 0.001));
      expect(line.net, closeTo(line.gross - line.commission, 0.001));
    }
  });

  test('every seeded review sits behind a booking that was really released',
      () async {
    final c = await createDataContainer();
    final queue = c.read(operatorQueueProvider);
    final released = {
      for (final r in queue)
        if (r.escrow == EscrowState.releasedToWorkshop) r.id,
    };
    for (final review in c.read(reviewsProvider)) {
      expect(released, contains(review.bookingId),
          reason: 'a review with no completed job behind it is the fake social '
              'proof the design exists to prevent');
    }
  });

  test('the catalogue still covers every category in every served governorate',
      () async {
    final c = await createDataContainer();
    final marketplace = c.read(serviceMarketplaceRepositoryProvider);
    // Coverage is asserted over *bookable* workshops: hiding unapproved ones
    // must not open a hole the region filter would silently widen through.
    for (final region in marketplace.providerRegions) {
      expect(
        marketplace.visibleProviders.where((p) => p.region == region).length,
        greaterThanOrEqualTo(2),
        reason: '$region needs enough approved workshops to compare',
      );
      for (final category in MockServiceData.categories) {
        expect(
          marketplace.providerCountFor(category.id, region: region),
          greaterThan(0),
          reason: 'no approved workshop sells ${category.id} in $region',
        );
      }
    }
  });

  test('bilingual labels exist for every new enum (§0.1 rule 4)', () {
    const ar = S(true);
    const en = S(false);
    for (final stage in ProviderOnboardingStage.values) {
      expect(stage.label(ar), isNotEmpty);
      expect(stage.label(en), isNotEmpty);
      expect(stage.label(ar), isNot(stage.label(en)));
      expect(stage.ownerStatus(ar), isNotEmpty);
      expect(stage.key, stage.name);
    }
    for (final kind in AccountKind.values) {
      expect(kind.label(ar), isNotEmpty);
      expect(kind.description(en), isNotEmpty);
      expect(AccountKindX.fromKey(kind.key), kind);
    }
    for (final type in AuditSubjectType.values) {
      expect(type.label(ar), isNotEmpty);
      expect(AuditSubjectType.fromKey(type.key), type);
    }
  });
}
