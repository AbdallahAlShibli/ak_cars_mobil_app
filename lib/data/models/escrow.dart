import '../../core/i18n/strings.dart';

/// The escrow state machine — the product's core (spec §3).
///
/// A booking's position in the money-and-trust flow is **one enum value**,
/// never a set of independent booleans. That is the whole point: `isAccepted &&
/// isRefunded` is not a state anyone can reach here, and every screen that
/// renders progress, every notification, and every operator button derives
/// from the same value and the same [escrowTransitions] table.
///
/// In the pilot the money itself moves by hand — the founder holds the funds
/// and transfers them (spec §3, note 2). The app is the ledger of *state*, not
/// a payment processor; no automated gateway exists in phase 1 by design.
enum EscrowState {
  // ------------------------------------------------- quote phase (§6)
  // Reached only by a `BookingType.customQuote` booking. A catalogue booking
  // has a published price and starts below, at [createdPendingPayment].

  /// The customer described a part or repair; no price exists yet.
  requested,

  /// The workshop priced it — part and labour itemised separately.
  quoted,

  /// The customer accepted the quote. Transient: the system moves it straight
  /// on to [createdPendingPayment], because accepting a price *is* agreeing to
  /// pay it.
  quoteAccepted,

  // --------------------------------------------------- the shared path

  /// Booking created, the customer's payment has not been confirmed as held.
  createdPendingPayment,

  /// The amount is held in escrow. The workshop can now be asked to accept.
  fundsHeld,

  acceptedByWorkshop,
  inProgress,

  /// The workshop uploaded its completion proof.
  proofSubmitted,

  /// Waiting on the customer to approve or raise an issue.
  awaitingApproval,

  /// The customer approved (or the approval window lapsed) — released.
  releasedToWorkshop,

  /// The customer raised an issue; the founder resolves it by hand.
  disputed,

  /// Cancelled by the customer before the funds were held.
  cancelled,

  /// Returned to the customer — a rejected job, or a dispute resolved their
  /// way.
  refunded;

  /// Stable wire value.
  String get key => name;

  /// No transition leaves these.
  bool get isTerminal =>
      this == releasedToWorkshop ||
      this == cancelled ||
      this == refunded;

  /// The three states that exist only before a price does. Nothing is owed,
  /// nothing is scheduled, and nothing is held while a booking sits here.
  bool get isQuotePhase =>
      this == requested || this == quoted || this == quoteAccepted;

  /// Whether the customer's money is being held right now. Drives the escrow
  /// banner — a cancelled or refunded booking must stop claiming to hold
  /// anything, and neither must one that is still waiting for a price.
  bool get holdsFunds =>
      !isQuotePhase && this != createdPendingPayment && !isTerminal;
}

/// Who is allowed to fire a transition (spec §6).
enum EscrowActor {
  customer,
  workshop,

  /// The founder's operator panel. In the pilot this actor also stands in for
  /// the payment gateway: "funds held" and "dispute resolved" are things a
  /// human confirms after moving real money.
  founder,

  /// The app itself — the automatic proof hand-off and the 72-hour release.
  system;

  String get key => name;
}

/// The named events of the state machine. Buttons bind to these rather than to
/// a target state, so a screen can never invent a transition the table does
/// not allow.
enum EscrowEvent {
  /// Quote phase (spec §6). [submitQuote] carries a `Quote`; [acceptQuote]
  /// is what turns its total into the booking's amount.
  submitQuote,
  acceptQuote,
  declineQuote,

  /// System hand-off: an accepted price is an agreement to pay it, so the
  /// booking moves itself onto the shared path rather than waiting for the
  /// customer to press a second button meaning the same thing.
  proceedToPayment,

  /// System hand-off: a workshop that quoted a job has already agreed to do
  /// it, so it is not asked to accept it again once the funds land.
  autoAcceptQuotedJob,

  confirmFundsHeld,
  cancelBooking,
  acceptJob,
  rejectJob,
  startWork,
  submitProof,
  handOffForApproval,
  approve,
  raiseIssue,
  autoRelease,
  resolveInFavourOfWorkshop,
  resolveInFavourOfCustomer;

  String get key => name;
}

/// One row of the spec's transition table.
class EscrowTransition {
  const EscrowTransition({
    required this.from,
    required this.event,
    required this.actor,
    required this.to,
  });

  final EscrowState from;
  final EscrowEvent event;
  final EscrowActor actor;
  final EscrowState to;
}

/// The transition table, transcribed from spec §3 and the single authority on
/// what may happen next. Nothing else in the app hard-codes an ordering.
const List<EscrowTransition> escrowTransitions = [
  // ------------------------------------------- quote phase (customQuote)
  EscrowTransition(
    from: EscrowState.requested,
    event: EscrowEvent.submitQuote,
    actor: EscrowActor.workshop,
    to: EscrowState.quoted,
  ),
  EscrowTransition(
    from: EscrowState.quoted,
    event: EscrowEvent.acceptQuote,
    actor: EscrowActor.customer,
    to: EscrowState.quoteAccepted,
  ),
  EscrowTransition(
    from: EscrowState.quoted,
    event: EscrowEvent.declineQuote,
    actor: EscrowActor.customer,
    to: EscrowState.cancelled,
  ),
  EscrowTransition(
    from: EscrowState.quoteAccepted,
    event: EscrowEvent.proceedToPayment,
    actor: EscrowActor.system,
    to: EscrowState.createdPendingPayment,
  ),
  // A quoting workshop has already committed to the job; it joins the shared
  // path at "accepted" without being asked a second time.
  EscrowTransition(
    from: EscrowState.fundsHeld,
    event: EscrowEvent.autoAcceptQuotedJob,
    actor: EscrowActor.system,
    to: EscrowState.acceptedByWorkshop,
  ),

  // ----------------------------------------------------- the shared path
  EscrowTransition(
    from: EscrowState.createdPendingPayment,
    event: EscrowEvent.confirmFundsHeld,
    actor: EscrowActor.founder,
    to: EscrowState.fundsHeld,
  ),
  EscrowTransition(
    from: EscrowState.createdPendingPayment,
    event: EscrowEvent.cancelBooking,
    actor: EscrowActor.customer,
    to: EscrowState.cancelled,
  ),
  EscrowTransition(
    from: EscrowState.fundsHeld,
    event: EscrowEvent.acceptJob,
    actor: EscrowActor.workshop,
    to: EscrowState.acceptedByWorkshop,
  ),
  EscrowTransition(
    from: EscrowState.fundsHeld,
    event: EscrowEvent.rejectJob,
    actor: EscrowActor.workshop,
    to: EscrowState.refunded,
  ),
  EscrowTransition(
    from: EscrowState.acceptedByWorkshop,
    event: EscrowEvent.startWork,
    actor: EscrowActor.workshop,
    to: EscrowState.inProgress,
  ),
  EscrowTransition(
    from: EscrowState.inProgress,
    event: EscrowEvent.submitProof,
    actor: EscrowActor.workshop,
    to: EscrowState.proofSubmitted,
  ),
  EscrowTransition(
    from: EscrowState.proofSubmitted,
    event: EscrowEvent.handOffForApproval,
    actor: EscrowActor.system,
    to: EscrowState.awaitingApproval,
  ),
  EscrowTransition(
    from: EscrowState.awaitingApproval,
    event: EscrowEvent.approve,
    actor: EscrowActor.customer,
    to: EscrowState.releasedToWorkshop,
  ),
  EscrowTransition(
    from: EscrowState.awaitingApproval,
    event: EscrowEvent.raiseIssue,
    actor: EscrowActor.customer,
    to: EscrowState.disputed,
  ),
  EscrowTransition(
    from: EscrowState.awaitingApproval,
    event: EscrowEvent.autoRelease,
    actor: EscrowActor.system,
    to: EscrowState.releasedToWorkshop,
  ),
  EscrowTransition(
    from: EscrowState.disputed,
    event: EscrowEvent.resolveInFavourOfWorkshop,
    actor: EscrowActor.founder,
    to: EscrowState.releasedToWorkshop,
  ),
  EscrowTransition(
    from: EscrowState.disputed,
    event: EscrowEvent.resolveInFavourOfCustomer,
    actor: EscrowActor.founder,
    to: EscrowState.refunded,
  ),
];

extension EscrowStateX on EscrowState {
  /// Every transition legally available from this state.
  List<EscrowTransition> get transitions => [
        for (final t in escrowTransitions)
          if (t.from == this) t,
      ];

  /// The transitions [actor] may fire from here. This is what an operator
  /// panel renders as buttons — the workshop cannot be shown "resolve
  /// dispute" because the table does not give it one.
  List<EscrowTransition> transitionsFor(EscrowActor actor) => [
        for (final t in transitions)
          if (t.actor == actor) t,
      ];

  /// Where [event] leads from here, or null when it is not allowed. An
  /// illegal transition is a no-op, never a thrown error: a double-tap on
  /// "approve" must not crash the app.
  EscrowState? on(EscrowEvent event) {
    for (final t in transitions) {
      if (t.event == event) return t.to;
    }
    return null;
  }

  /// The happy-path successor, used by the staging lifecycle simulator and by
  /// the "skip ahead" demo control. Deliberately *not* the same thing as
  /// [transitions]: a dispute is a legal transition but never the default one.
  EscrowState? get happyPathNext => switch (this) {
        // The quote phase has no happy-path successor the app may take on its
        // own: [requested] needs a price only the workshop can name, and
        // [quoted] needs a decision only the customer can make. Inventing
        // either would be the demo build fabricating a workshop's numbers.
        EscrowState.requested || EscrowState.quoted => null,
        EscrowState.quoteAccepted => EscrowState.createdPendingPayment,
        EscrowState.createdPendingPayment => EscrowState.fundsHeld,
        EscrowState.fundsHeld => EscrowState.acceptedByWorkshop,
        EscrowState.acceptedByWorkshop => EscrowState.inProgress,
        EscrowState.inProgress => EscrowState.proofSubmitted,
        EscrowState.proofSubmitted => EscrowState.awaitingApproval,
        _ => null,
      };

  String label(S s) => switch (this) {
        EscrowState.requested =>
          s.t('بانتظار عرض السعر', 'Awaiting a quote'),
        EscrowState.quoted =>
          s.t('وصل عرض السعر — بانتظار قرارك', 'Quote received — your call'),
        EscrowState.quoteAccepted =>
          s.t('قبلت العرض', 'Quote accepted'),
        EscrowState.createdPendingPayment =>
          s.t('بانتظار تأكيد المبلغ', 'Awaiting payment confirmation'),
        EscrowState.fundsHeld =>
          s.t('المبلغ محجوز — بانتظار الورشة', 'Funds held — waiting for the workshop'),
        EscrowState.acceptedByWorkshop =>
          s.t('قبلته الورشة', 'Accepted by the workshop'),
        EscrowState.inProgress => s.t('العمل جارٍ', 'Work in progress'),
        EscrowState.proofSubmitted =>
          s.t('رُفع إثبات الإنجاز', 'Proof submitted'),
        EscrowState.awaitingApproval =>
          s.t('بانتظار موافقتك', 'Awaiting your approval'),
        EscrowState.releasedToWorkshop =>
          s.t('حُرِّر المبلغ للورشة', 'Released to the workshop'),
        EscrowState.disputed => s.t('قيد النزاع', 'Under dispute'),
        EscrowState.cancelled => s.t('ملغي', 'Cancelled'),
        EscrowState.refunded => s.t('مُعاد للعميل', 'Refunded'),
      };

  /// The five-step story the customer's tracking screen tells, collapsed from
  /// the ten machine states. The customer does not need to see the difference
  /// between "proof submitted" and "awaiting approval" — that hand-off is
  /// automatic and instant.
  int get customerStepIndex => switch (this) {
        // The quote phase shares the first row with "you sent the request",
        // which is exactly what it is: the booking exists and nothing is held.
        // What *distinguishes* the three states — no price / a price to
        // decide on / a price accepted — is the quote card the tracking screen
        // shows above the timeline, where the numbers actually are.
        EscrowState.requested ||
        EscrowState.quoted ||
        EscrowState.quoteAccepted ||
        EscrowState.createdPendingPayment =>
          0,
        EscrowState.fundsHeld => 1,
        EscrowState.acceptedByWorkshop => 2,
        EscrowState.inProgress => 3,
        EscrowState.proofSubmitted || EscrowState.awaitingApproval => 4,
        EscrowState.releasedToWorkshop ||
        EscrowState.disputed ||
        EscrowState.cancelled ||
        EscrowState.refunded =>
          5,
      };

  /// How far along that same six-step story this state *proves* a booking
  /// got, or null when it proves nothing.
  ///
  /// [customerStepIndex] answers "which row is the customer on"; this answers
  /// "which rows actually happened", and the two differ for the three off-path
  /// endings. A booking cancelled before payment sits on the last row, but it
  /// never reached "funds held" — so it contributes no progress and the rows
  /// it did reach are read from the booking's history instead
  /// (`ServiceRequest.reachedStepIndex`).
  int? get reachedStepIndex => switch (this) {
        EscrowState.requested ||
        EscrowState.quoted ||
        EscrowState.quoteAccepted ||
        EscrowState.createdPendingPayment =>
          0,
        EscrowState.fundsHeld => 1,
        EscrowState.acceptedByWorkshop => 2,
        EscrowState.inProgress => 3,
        EscrowState.proofSubmitted || EscrowState.awaitingApproval => 4,
        EscrowState.releasedToWorkshop => 5,
        EscrowState.disputed ||
        EscrowState.cancelled ||
        EscrowState.refunded =>
          null,
      };
}

extension EscrowEventX on EscrowEvent {
  /// Button copy. Written from the acting party's point of view — the
  /// workshop's "قبول الطلب" and the customer's "أوافق" are the same kind of
  /// object in the table but never appear on the same screen.
  L get label => switch (this) {
        EscrowEvent.submitQuote =>
          const L('تقديم عرض سعر', 'Submit a quote'),
        EscrowEvent.acceptQuote => const L('أقبل العرض', 'Accept quote'),
        EscrowEvent.declineQuote => const L('أرفض العرض', 'Decline quote'),
        EscrowEvent.proceedToPayment =>
          const L('المتابعة للدفع', 'Proceed to payment'),
        EscrowEvent.autoAcceptQuotedJob =>
          const L('قبول تلقائي (العرض يعني قبولاً)',
              'Auto-accepted (the quote was the acceptance)'),
        EscrowEvent.confirmFundsHeld =>
          const L('تأكيد استلام المبلغ', 'Confirm funds received'),
        EscrowEvent.cancelBooking => const L('إلغاء الحجز', 'Cancel booking'),
        EscrowEvent.acceptJob => const L('قبول الطلب', 'Accept job'),
        EscrowEvent.rejectJob => const L('رفض الطلب', 'Reject job'),
        EscrowEvent.startWork => const L('بدء العمل', 'Start work'),
        EscrowEvent.submitProof =>
          const L('رفع إثبات الإنجاز', 'Submit proof of work'),
        EscrowEvent.handOffForApproval =>
          const L('إحالة للموافقة', 'Hand off for approval'),
        EscrowEvent.approve =>
          const L('أوافق — حرِّر المبلغ', 'Approve — release payment'),
        EscrowEvent.raiseIssue => const L('لديّ ملاحظة', 'I have an issue'),
        EscrowEvent.autoRelease =>
          const L('تحرير تلقائي', 'Automatic release'),
        EscrowEvent.resolveInFavourOfWorkshop =>
          const L('حسم لصالح الورشة — تحرير', 'Resolve for workshop — release'),
        EscrowEvent.resolveInFavourOfCustomer =>
          const L('حسم لصالح العميل — إعادة', 'Resolve for customer — refund'),
      };

  /// Whether firing this event needs a confirmation step. Everything that
  /// ends the booking or moves real money does.
  bool get isDestructive =>
      this == EscrowEvent.declineQuote ||
      this == EscrowEvent.cancelBooking ||
      this == EscrowEvent.rejectJob ||
      this == EscrowEvent.raiseIssue ||
      this == EscrowEvent.resolveInFavourOfCustomer;
}

extension EscrowActorX on EscrowActor {
  L get label => switch (this) {
        EscrowActor.customer => const L('العميل', 'Customer'),
        EscrowActor.workshop => const L('الورشة', 'Workshop'),
        EscrowActor.founder => const L('المؤسس', 'Founder'),
        EscrowActor.system => const L('النظام', 'System'),
      };
}
