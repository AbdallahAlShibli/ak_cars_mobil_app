import '../../data/models/escrow.dart';

/// Whether the customer may be handed the workshop's own phone / WhatsApp
/// number for a booking in [state].
///
/// Direct contact unlocks only once money is actually held in escrow. Before
/// that, anything agreed off-platform carries no guarantee, no proof of work
/// and no service record — so the number is not handed out, and the in-app
/// thread is the way to ask. `null` is "no booking exists yet" (a service
/// detail page, a workshop the customer is only looking at), which is the
/// earliest point of all.
///
/// This is the **single** authority on the question: no screen re-derives it
/// from its own set of states. Adding a state to [EscrowState] therefore forces
/// exactly one decision, here, rather than a scattered set of them.
bool canContactProviderDirectly(EscrowState? state) {
  if (state == null) return false;
  return switch (state) {
    // Money is held: the two parties are in a protected transaction, and
    // talking directly is now part of getting the car fixed.
    EscrowState.fundsHeld ||
    EscrowState.acceptedByWorkshop ||
    EscrowState.inProgress ||
    EscrowState.proofSubmitted ||
    EscrowState.awaitingApproval ||
    EscrowState.releasedToWorkshop =>
      true,
    // Deliberately unlocked. Withholding contact during a dispute looks
    // protective and is the opposite: the customer with a problem needs to
    // reach the workshop more than anyone, and cutting them off at that exact
    // moment is where trust breaks.
    EscrowState.disputed => true,
    // Before the funds land — including the whole quote phase — the in-app
    // thread is the channel.
    EscrowState.requested ||
    EscrowState.quoted ||
    EscrowState.quoteAccepted ||
    EscrowState.createdPendingPayment ||
    EscrowState.cancelled ||
    EscrowState.refunded =>
      false,
  };
}
