import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../i18n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../data/models/escrow.dart';

/// The escrow story as a picture rather than as a sentence.
///
/// The tracking screen is where the product's one promise is either believed
/// or not — *your money is held until you say the work is done*. It was
/// telling that story in words: a status badge, a paragraph, a list of rows.
/// Words are the slowest way to answer "where is my money right now", and it
/// is the question the customer opens the app to ask.
///
/// Four stations, because four is what the customer's half of the machine
/// actually contains. The ten [EscrowState] values collapse onto them:
///
/// ```
/// ● held  →  ● in progress  →  ● proof  →  ● released
/// ```
///
/// A dispute is deliberately **not** a fifth station. It is not further along
/// than "proof submitted"; it is sideways from it, and drawing it in line
/// would say the booking progressed when it stalled. It renders as a branch
/// below the rail, in the danger color. Cancelled and refunded bookings never
/// entered the rail at all, so they get the same treatment.
enum EscrowStation { held, inProgress, proof, released }

/// Where [EscrowState] sits on the four-station rail.
extension EscrowStationX on EscrowState {
  /// How many stations this state *proves* were passed (0–4).
  int get stationsComplete => switch (this) {
        // Nothing is held yet — the rail has not started.
        EscrowState.requested ||
        EscrowState.quoted ||
        EscrowState.quoteAccepted ||
        EscrowState.createdPendingPayment =>
          0,
        EscrowState.fundsHeld ||
        EscrowState.acceptedByWorkshop ||
        EscrowState.inProgress =>
          1,
        EscrowState.proofSubmitted || EscrowState.awaitingApproval => 2,
        EscrowState.releasedToWorkshop => 4,
        // The money got as far as being held and then stopped moving forward.
        EscrowState.disputed => 2,
        // Nothing was ever held, so nothing on the rail happened.
        EscrowState.cancelled || EscrowState.refunded => 0,
      };

  /// The station currently being worked on, or null when the rail is finished
  /// or was left.
  EscrowStation? get activeStation => switch (this) {
        EscrowState.requested ||
        EscrowState.quoted ||
        EscrowState.quoteAccepted ||
        EscrowState.createdPendingPayment =>
          EscrowStation.held,
        EscrowState.fundsHeld ||
        EscrowState.acceptedByWorkshop ||
        EscrowState.inProgress =>
          EscrowStation.inProgress,
        EscrowState.proofSubmitted || EscrowState.awaitingApproval =>
          EscrowStation.released,
        EscrowState.releasedToWorkshop ||
        EscrowState.disputed ||
        EscrowState.cancelled ||
        EscrowState.refunded =>
          null,
      };

  /// True where the booking left the rail instead of finishing it. These get
  /// the branch note, not a station.
  bool get isOffRail =>
      this == EscrowState.disputed ||
      this == EscrowState.cancelled ||
      this == EscrowState.refunded;
}

/// How much room the timeline is being given.
enum EscrowTimelineSize {
  /// Rail and labels — the tracking screen.
  full,

  /// Rail only, half height, no labels — an operator queue card, where the
  /// job's identity is the content and its position is a glance.
  compact,
}

class EscrowTimeline extends StatelessWidget {
  const EscrowTimeline({
    super.key,
    required this.state,
    this.size = EscrowTimelineSize.full,
  });

  final EscrowState state;
  final EscrowTimelineSize size;

  bool get _compact => size == EscrowTimelineSize.compact;

  static (String, IconData) _label(S s, EscrowStation station) =>
      switch (station) {
        EscrowStation.held => (s.t('محجوز', 'Held'), LucideIcons.lock),
        EscrowStation.inProgress =>
          (s.t('قيد التنفيذ', 'In progress'), LucideIcons.wrench),
        EscrowStation.proof =>
          (s.t('إثبات مرفوع', 'Proof'), LucideIcons.camera),
        EscrowStation.released =>
          (s.t('محرَّر', 'Released'), LucideIcons.circleCheckBig),
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final complete = state.stationsComplete;
    final active = state.activeStation;
    final stations = EscrowStation.values;

    final rail = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, station) in stations.indexed) ...[
          if (i > 0)
            Expanded(
              // The connector into station `i` is filled exactly when station
              // `i` has been reached, so the line grows with the booking
              // instead of appearing whole the moment a step ticks over.
              child: _Connector(
                filled: complete >= i,
                partial: complete == i - 1 && active == station,
                compact: _compact,
              ),
            ),
          _Station(
            filled: complete > i,
            active: active == station && !state.isOffRail,
            label: _label(s, station).$1,
            icon: _label(s, station).$2,
            compact: _compact,
          ),
        ],
      ],
    );

    if (!state.isOffRail) return rail;

    // The branch. Drawn under the rail and hanging off the station the booking
    // actually reached, so the picture says "it got this far, then went here".
    final (branchLabel, branchColor) = switch (state) {
      EscrowState.disputed => (
          s.t('نزاع قيد المراجعة — المبلغ ما زال محجوزاً',
              'Under review — the funds stay held'),
          ak.danger
        ),
      EscrowState.refunded => (
          s.t('أُعيد المبلغ إليك', 'Refunded to you'),
          ak.danger
        ),
      _ => (s.t('أُلغي الحجز', 'Booking cancelled'), ak.inkSub),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rail,
        SizedBox(height: _compact ? AppSpacing.sm : AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: _compact ? 10 : 13,
              child: Icon(LucideIcons.cornerDownRight,
                  size: _compact ? 12 : 15, color: branchColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                branchLabel,
                style: TextStyle(
                  fontSize: _compact ? 11 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: branchColor,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One dot: filled (passed), ringed (here now), or hollow (still ahead).
class _Station extends StatefulWidget {
  const _Station({
    required this.filled,
    required this.active,
    required this.label,
    required this.icon,
    required this.compact,
  });

  final bool filled;
  final bool active;
  final String label;
  final IconData icon;
  final bool compact;

  @override
  State<_Station> createState() => _StationState();
}

class _StationState extends State<_Station>
    with SingleTickerProviderStateMixin {
  // Built eagerly rather than `late final`. Three of the four stations are
  // never active, so a lazy controller would go untouched for the widget's
  // whole life and then be *constructed* by `dispose()` reading it — which
  // calls `createTicker` on an element that is already deactivated, and
  // throws "looking up a deactivated widget's ancestor is unsafe".
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Station old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final dot = widget.compact ? 18.0 : 30.0;

    final (bg, fg, ring) = switch ((widget.filled, widget.active)) {
      (true, _) => (ak.primary, ak.onPrimary, null),
      (false, true) => (ak.amberBgSoft, ak.amberText, ak.amber),
      _ => (Colors.transparent, ak.inkFaint, null),
    };

    Widget circle = Container(
      width: dot,
      height: dot,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: ring ?? (widget.filled ? ak.primary : ak.border),
          width: widget.active ? 2 : 1.5,
        ),
      ),
      child: Icon(
        widget.filled ? LucideIcons.check : widget.icon,
        size: dot * 0.5,
        color: fg,
      ),
    );

    // A ring that breathes, not a dot that flashes: the current station has to
    // be findable without pulling the eye off the page every second.
    if (widget.active) {
      circle = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ak.amber.withValues(alpha: 0.30 * (1 - _pulse.value)),
                spreadRadius: 2 + 4 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: circle,
      );
    }

    if (widget.compact) return circle;

    return SizedBox(
      width: 68,
      child: Column(
        children: [
          circle,
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              fontWeight: widget.active || widget.filled
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: widget.active
                  ? ak.amberText
                  : widget.filled
                      ? ak.ink
                      : ak.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The line between two stations. Fills left-to-right (leading-to-trailing) as
/// the booking advances rather than switching on all at once.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.filled,
    required this.partial,
    required this.compact,
  });

  final bool filled;

  /// The booking is standing *at* the station this line leads into — the line
  /// is drawn half full so the rail reads as moving, not stopped.
  final bool partial;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final dot = compact ? 18.0 : 30.0;
    final factor = filled
        ? 1.0
        : partial
            ? 0.5
            : 0.0;

    return Padding(
      // Centred on the dots, and pulled to their edges so the rail is one
      // continuous line rather than four islands.
      padding: EdgeInsets.only(
        top: dot / 2 - 1.5,
        left: compact ? 2 : 3,
        right: compact ? 2 : 3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 3,
          child: Stack(
            children: [
              Container(color: ak.border),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: factor),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(color: ak.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
