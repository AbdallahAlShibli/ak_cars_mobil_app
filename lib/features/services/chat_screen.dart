import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Per-request chat with the provider (simulated replies until the
/// real-time backend lands in Phase 2).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _replyTimer;
  bool _typing = false;

  static const _replies = [
    'Hello! Your car is with us — work is going well.',
    'We expect it to be ready by 4 pm today.',
    'Sure, we will send photos once we finish.',
    'You are welcome! Anything else you need?',
  ];
  int _replyIndex = 0;

  @override
  void dispose() {
    _replyTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    ref.read(chatProvider.notifier).add(
          widget.requestId,
          ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            fromUser: true,
            text: text,
            time: DateTime.now(),
          ),
        );
    _input.clear();
    _scrollDown();

    setState(() => _typing = true);
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _typing = false);
      ref.read(chatProvider.notifier).add(
            widget.requestId,
            ChatMessage(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              fromUser: false,
              text: _replies[_replyIndex % _replies.length],
              time: DateTime.now(),
            ),
          );
      _replyIndex++;
      _scrollDown();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = ref
        .watch(requestsProvider)
        .firstWhereOrNull((r) => r.id == widget.requestId);
    final messages =
        ref.watch(chatProvider)[widget.requestId] ?? const <ChatMessage>[];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request?.offering.provider.name ?? 'Chat',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              _typing ? 'typing…' : 'Request #${widget.requestId}',
              style: TextStyle(
                fontSize: 11,
                color: _typing ? AppColors.good : AppColors.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Say hello — ask about your car anytime.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.ink3),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, i) =>
                          _Bubble(message: messages[i]),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              color: AppColors.card,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        fillColor: AppColors.field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(
                              color: AppColors.brand, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: mine ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
