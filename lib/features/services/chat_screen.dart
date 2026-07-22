import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

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
  bool _typing = false;


  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    final isArabic = S.of(context).isAr;
    final chat = ref.read(chatProvider.notifier);

    await chat.send(widget.requestId, text);
    if (!mounted) return;
    _input.clear();
    _scrollDown();

    // The repository resolves this when the provider next replies — a canned
    // answer today, an inbound socket frame once the chat backend lands.
    setState(() => _typing = true);
    await chat.awaitProviderReply(widget.requestId, isArabic: isArabic);
    if (!mounted) return;
    setState(() => _typing = false);
    _scrollDown();
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
    final s = S.of(context);
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
            Text(request?.offering.provider.name.of(s) ??
                    s.t('محادثة', 'Chat'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              _typing
                  ? s.t('يكتب…', 'typing…')
                  : s.t('الطلب #${widget.requestId}',
                      'Request #${widget.requestId}'),
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
                  ? Center(
                      child: Text(
                        s.t('ابدأ المحادثة — اسأل عن سيارتك في أي وقت.',
                            'Say hello — ask about your car anytime.'),
                        style: const TextStyle(
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
                        hintText: s.t('اكتب رسالة…', 'Write a message…'),
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
