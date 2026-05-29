import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/meeting_speech_recorder.dart';
import '../../core/network/api_result.dart';
import '../../core/network/websocket_manager.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/models.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';
import 'chat_room_utils.dart';

String _initialsFromName(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

String _formatMsgTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  if (iso.contains('T')) return iso.split('T').last.split('.').first;
  return iso;
}

ChatMessage _messageFromRow(Map<String, dynamic> m, String? myId) {
  final senderId = m['sender_id']?.toString() ?? '';
  final senderName = m['sender_name']?.toString() ?? 'User';
  final created = m['created_at']?.toString() ?? '';
  return ChatMessage(
    id: m['id']?.toString() ?? '',
    senderId: senderId,
    senderName: senderName,
    senderInitials: _initialsFromName(senderName),
    message: m['content']?.toString() ?? '',
    time: _formatMsgTime(created),
    isMe: myId != null && senderId == myId,
  );
}

// ── Chat List ─────────────────────────────────────────────────────────────────
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _reloadToken = 0;

  Future<List<ChatRoom>> _loadRooms() {
    return context
        .read<AppServices>()
        .chat
        .listRooms(forceRefresh: true)
        .unwrap()
        .then((rows) => rows.map(chatRoomFromApi).toList());
  }

  Future<void> _invalidateAndReload() async {
    await context.read<AppServices>().chat.invalidateRooms();
    if (mounted) setState(() => _reloadToken++);
  }

  Future<void> _showNewTeamChatSheet() async {
    final services = context.read<AppServices>();
    List<ApiProject> projects;
    try {
      projects =
          await services.projects.listProjects(forceRefresh: true).unwrap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load projects: $e')),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (projects.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Create a project first — each project has a team chat.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Team project chat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  itemBuilder: (_, i) {
                    final p = projects[i];
                    return ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(p.name),
                      subtitle: const Text('Open team conversation'),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await openProjectTeamChat(
                          context,
                          projectId: p.id,
                          projectName: p.name,
                        );
                        await _invalidateAndReload();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roomTile(BuildContext context, ChatRoom r) {
    return TCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => Navigator.pushNamed(
        context,
        r.isGroup ? R.groupChat : R.directChat,
        arguments: r,
      ),
      child: Row(children: [
        TAvatar(
          initials: r.initials,
          radius: 24,
          bg: r.isGroup ? AppColors.primary : AppColors.accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    r.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                r.lastMessage,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Center(
          child: Text(
            'No conversations yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TButton(
            label: 'Start team chat',
            onTap: _showNewTeamChatSheet,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New team chat',
            onPressed: _showNewTeamChatSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _invalidateAndReload,
        child: RepositoryLoader<List<ChatRoom>>(
          key: ValueKey(_reloadToken),
          load: _loadRooms,
          builder: (context, rooms) {
            if (rooms.isEmpty) return _emptyState();
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (_, i) => _roomTile(context, rooms[i]),
            );
          },
        ),
      ),
      bottomNavigationBar:
          TBottomNav(current: 3, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }
}

// ── Conversation (group + direct) ─────────────────────────────────────────────
/// Shared shell for direct + group conversations (same backend room model).
abstract class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class GroupChatScreen extends ConversationScreen {
  const GroupChatScreen({super.key});
}

class DirectChatScreen extends ConversationScreen {
  const DirectChatScreen({super.key});
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _ctrl = TextEditingController();
  final List<ChatMessage> _messages = [];
  final Set<String> _seenIds = {};
  final MeetingSpeechRecorder _voiceRecorder = MeetingSpeechRecorder();
  StreamSubscription<SocketPayload>? _socketSub;
  WebSocketManager? _ws;
  bool _loadingHistory = true;
  bool _recordingVoice = false;
  bool _transcribingVoice = false;
  String? _roomId;
  String _roomName = 'Chat';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    final rid = _roomId;
    if (rid != null) {
      _ws?.leaveRoom(rid);
    }
    _voiceRecorder.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    _ws = context.read<WebSocketManager>();
    final args = ModalRoute.of(context)?.settings.arguments;
    final room = args is ChatRoom ? args : null;
    if (room == null) {
      setState(() => _loadingHistory = false);
      return;
    }
    setState(() {
      _roomId = room.id;
      _roomName = room.name;
    });
    await _loadHistory();
    _subscribeSocket();
  }

  void _subscribeSocket() {
    final ws = _ws;
    final rid = _roomId;
    if (ws == null || rid == null) return;
    ws.joinRoom(rid);
    _socketSub?.cancel();
    _socketSub = ws.stream.listen((payload) {
      if (payload.event != SocketEvent.chatMessage) return;
      final d = payload.data;
      final msgRoom = d['room_id']?.toString();
      if (msgRoom != rid) return;
      _appendServerMessage(Map<String, dynamic>.from(d));
    });
  }

  void _appendServerMessage(Map<String, dynamic> d) {
    if (!mounted) return;
    final session = context.read<SessionController>();
    final myId = session.currentUser?.id;
    final id = d['id']?.toString() ?? '';
    final content = d['content']?.toString() ?? '';
    if (id.isNotEmpty && _seenIds.contains(id)) return;
    if (id.isNotEmpty) _seenIds.add(id);
    final incoming = _messageFromRow(d, myId);
    setState(() {
      _messages.removeWhere((m) =>
          m.isPending &&
          m.isMe &&
          m.message == content &&
          (myId == null || m.senderId == myId));
      _messages.add(incoming);
    });
  }

  Future<void> _loadHistory() async {
    final rid = _roomId;
    if (rid == null) return;
    final svc = context.read<AppServices>();
    try {
      final raw = await svc.chat.getMessages(rid).unwrap();
      if (!mounted) return;
      final session = context.read<SessionController>();
      final myId = session.currentUser?.id;
      setState(() {
        _messages
          ..clear()
          ..addAll(raw.map((m) => _messageFromRow(m, myId)));
        _seenIds
          ..clear()
          ..addAll(_messages.map((e) => e.id).where((id) => id.isNotEmpty));
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _openMeeting() async {
    final rid = _roomId;
    if (rid == null) return;
    String? projectId;
    try {
      final room =
          await context.read<AppServices>().chat.getRoom(rid).unwrap();
      projectId = room['project_id']?.toString();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      R.meeting,
      arguments: {
        'roomName': _roomName,
        'roomId': rid,
        if (projectId != null) 'projectId': projectId,
      },
    );
  }

  void _openChatSummary() {
    final rid = _roomId;
    if (rid == null) return;
    Navigator.pushNamed(
      context,
      R.chatSummary,
      arguments: ChatRoom(
        id: rid,
        name: _roomName,
        lastMessage: '',
        time: '',
        initials: _roomName.isNotEmpty ? _roomName[0] : 'C',
        isGroup: widget is GroupChatScreen,
      ),
    );
  }

  void _showInputMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic, color: AppColors.primary),
              title: const Text('Voice message (Whisper)'),
              subtitle: const Text('Record speech → text → send'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleVoiceMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('AI chat summary'),
              onTap: () {
                Navigator.pop(ctx);
                _openChatSummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Start meeting'),
              subtitle: const Text('Live speech + chat transcript'),
              onTap: () {
                Navigator.pop(ctx);
                _openMeeting();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoiceMessage() async {
    if (_transcribingVoice) return;
    final rid = _roomId;
    if (rid == null) return;

    if (!_recordingVoice) {
      final ok = await _voiceRecorder.ensurePermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow microphone access to use voice messages.'),
          ),
        );
        return;
      }
      final started = await _voiceRecorder.startVoiceNote();
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start microphone.')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _recordingVoice = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording… Tap mic again to transcribe & send.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _recordingVoice = false;
      _transcribingVoice = true;
    });

    final captured = await _voiceRecorder.stopVoiceNote();
    if (!mounted) return;

    if (captured == null) {
      setState(() => _transcribingVoice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio captured. Try again.')),
      );
      return;
    }

    final result = await context.read<AppServices>().ai.transcribe(
          captured.bytes,
          filename: captured.filename,
        );

    if (!mounted) return;
    setState(() => _transcribingVoice = false);

    if (!result.isSuccess || result.data!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error?.contains('502') == true ||
                    result.error?.toLowerCase().contains('stt') == true
                ? 'Speech service offline. Run: python run.py in ml_models'
                : 'Transcription failed: ${result.error ?? 'empty'}',
          ),
        ),
      );
      return;
    }

    _ctrl.text = result.data!.text.trim();
    await _send();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final rid = _roomId;
    if (text.isEmpty || rid == null || !mounted) return;

    final ws = _ws ?? context.read<WebSocketManager>();
    final session = context.read<SessionController>();
    final myId = session.currentUser?.id ?? '';
    final displayName = session.currentUser?.displayName ??
        session.currentUser?.fullName ??
        'You';

    if (!ws.isConnected) {
      await ws.connect();
    }
    if (!mounted) return;
    
    final bool isOnline = ws.isConnected;

    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pending = ChatMessage(
      id: pendingId,
      senderId: myId,
      senderName: displayName,
      senderInitials: _initialsFromName(displayName),
      message: text,
      time: '…',
      isMe: true,
      isPending: true,
    );
    setState(() {
      _messages.add(pending);
      _ctrl.clear();
    });
    
    if (isOnline) {
      ws.sendMessage(rid, text);
    } else {
      // Fallback to offline REST queue
      final svc = context.read<AppServices>();
      await svc.chat.sendMessage(rid, {'content': text});
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final myInitials =
        _initialsFromName(session.currentUser?.displayName ?? 'Me');

    if (_roomId == null && !_loadingHistory) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Messages',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Choose a conversation from the list to start messaging.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          TAvatar(
            initials: _roomName.isNotEmpty ? _roomName[0] : 'C',
            radius: 18,
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_roomName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              _loadingHistory
                  ? 'Loading messages…'
                  : (_ws?.isConnected ?? false)
                      ? 'Connected'
                      : 'Offline — connect to send',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'AI summary',
            onPressed: _openChatSummary,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Meeting',
            onPressed: _openMeeting,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: TChip(label: 'Today', bg: AppColors.border)));
                  }
                  final m = _messages[i - 1];
                  return _buildBubble(m, myInitials);
                },
              ),
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage m, String myInitials) {
    final isMe = m.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            TAvatar(initials: m.senderInitials, radius: 16, bg: AppColors.primary),
            const SizedBox(width: 8)
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(m.senderName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isMe ? null : Border.all(color: AppColors.border),
                  ),
                  child: Text(m.message,
                      style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 13)),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        '${m.time}${m.isPending ? ' · sending' : ''}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary))),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Opacity(
              opacity: m.isPending ? 0.5 : 1,
              child: TAvatar(initials: myInitials, radius: 16),
            )
          ],
        ],
      ),
    );
  }

  Widget _buildInput() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: SafeArea(
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.textSecondary),
              tooltip: 'More',
              onPressed: _showInputMenu,
            ),
            IconButton(
              icon: Icon(
                _transcribingVoice
                    ? Icons.hourglass_top
                    : _recordingVoice
                        ? Icons.stop_circle
                        : Icons.mic_none,
                color: _recordingVoice
                    ? const Color(0xFFDC2626)
                    : AppColors.primary,
              ),
              tooltip: 'Voice message',
              onPressed:
                  _transcribingVoice ? null : _toggleVoiceMessage,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _ctrl,
                  enabled: !_transcribingVoice,
                  decoration: InputDecoration(
                    hintText: _recordingVoice
                        ? 'Recording voice…'
                        : _transcribingVoice
                            ? 'Transcribing with Whisper…'
                            : 'Type a message...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _transcribingVoice ? null : _send),
          ]),
        ),
      );
}

// ── Chat Summary ──────────────────────────────────────────────────────────────
class ChatSummaryScreen extends StatefulWidget {
  const ChatSummaryScreen({super.key});

  @override
  State<ChatSummaryScreen> createState() => _ChatSummaryScreenState();
}

class _ChatSummaryScreenState extends State<ChatSummaryScreen> {
  bool _loading = true;
  String? _error;
  String _summaryText = '';
  List<String> _speechLines = const [];
  List<String> _keyPoints = const [];
  List<String> _actions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final room = ModalRoute.of(context)?.settings.arguments as ChatRoom?;
    if (room == null) {
      setState(() {
        _loading = false;
        _error = 'Open Chat Summary from a conversation.';
      });
      return;
    }
    try {
      final services = context.read<AppServices>();
      final msgs =
          await services.chat.getMessages(room.id).unwrap();
      final transcript = msgs
          .map((m) =>
              '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}')
          .join('\n');
      if (transcript.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No messages to summarise yet.';
        });
        return;
      }
      Map<String, dynamic> summary;
      try {
        summary = await services.ai.summarizeChat(transcript, topN: 6).unwrap();
      } catch (_) {
        summary = {
          'summary': transcript.split('\n').take(3).join(' '),
          'key_points': transcript
              .split('\n')
              .map((l) => l.contains(':') ? l.split(':').last.trim() : l)
              .where((s) => s.length >= 4)
              .take(6)
              .toList(),
        };
      }
      final kp = summary['key_points'];
      final ai = summary['action_items'];
      final speech = summary['speech_transcript'];
      setState(() {
        _summaryText = summary['summary']?.toString().trim() ?? '';
        if (_summaryText.isEmpty && kp is List && kp.isNotEmpty) {
          _summaryText = kp.map((e) => e.toString()).join('. ');
        }
        _speechLines = speech is List
            ? speech.map((e) => e.toString()).toList()
            : const [];
        _keyPoints = kp is List ? kp.map((e) => e.toString()).toList() : const [];
        _actions = ai is List ? ai.map((e) => e.toString()).toList() : const [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Chat Summary',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _load();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const AIBanner(
                      title: 'AI Summary',
                      subtitle: 'Whisper speech + chat via Teamify AI'),
                  const SizedBox(height: 16),
                  if (_summaryText.isNotEmpty)
                    TCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Summary',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 12),
                          Text(_summaryText,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  if (_speechLines.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Speech transcript',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 12),
                          Text(_speechLines.join('\n'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Key Points',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16)),
                        const SizedBox(height: 12),
                        if (_keyPoints.isEmpty)
                          const Text('No key points returned.',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary))
                        else
                          ..._keyPoints.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(
                                            top: 6, right: 8),
                                        decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle)),
                                    Expanded(
                                        child: Text(p,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary))),
                                  ]))),
                      ])),
                  const SizedBox(height: 12),
                  TCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Action Items',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16)),
                        const SizedBox(height: 12),
                        if (_actions.isEmpty)
                          const Text('No action items returned.',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary))
                        else
                          ..._actions.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                const Icon(Icons.check_box_outline_blank,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(a,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary))),
                              ]))),
                      ])),
                ]),
    );
  }
}

// ── Pinned Messages ───────────────────────────────────────────────────────────
class PinnedMessagesScreen extends StatelessWidget {
  const PinnedMessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Pinned Messages',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pinned messages are not exposed by the API yet. '
            'Backend support is required to list pins per room.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ── Smart Q&A ─────────────────────────────────────────────────────────────────
class SmartQAScreen extends StatefulWidget {
  const SmartQAScreen({super.key});
  @override
  State<SmartQAScreen> createState() => _SmartQAScreenState();
}

class _SmartQAScreenState extends State<SmartQAScreen> {
  final _ctrl = TextEditingController();
  final _answers = <Map<String, String>>[];
  bool _asking = false;
  String? _roomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ChatRoom) {
        setState(() => _roomId = args.id);
      } else if (args is Map && args['room_id'] != null) {
        setState(() => _roomId = args['room_id'].toString());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || !mounted) return;
    final rid = _roomId;
    if (rid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open Smart Q&A from a chat (with a room) first.'),
        ),
      );
      return;
    }
    setState(() => _asking = true);
    try {
      final services = context.read<AppServices>();
      final msgs = await services.chat.getMessages(rid).unwrap();
      final transcript = msgs
          .map((m) =>
              '${m['sender_name'] ?? 'User'}: ${m['content'] ?? ''}')
          .join('\n');
      final prompt =
          '$transcript\n\nUser question: $q\nAnswer concisely using only the conversation.';
      final summary =
          await services.ai.summarizeChat(prompt, topN: 8).unwrap();
      final kp = summary['key_points'];
      final answer = kp is List && kp.isNotEmpty
          ? kp.map((e) => e.toString()).join('\n')
          : summary.toString();
      if (!mounted) return;
      setState(() {
        _answers.add({'q': q, 'a': answer});
        _ctrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Smart Q&A',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const AIBanner(
              title: 'Ask AI about this chat',
              subtitle:
                  'Answers are derived server-side from the latest messages in this room'),
          const SizedBox(height: 16),
          ..._answers.map((a) => Column(children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(a['q']!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)))),
                TCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 14)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(a['a']!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary))),
                        ])),
              ])),
        ])),
        Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SafeArea(
                child: Row(children: [
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                          controller: _ctrl,
                          enabled: !_asking,
                          decoration: const InputDecoration(
                              hintText: 'Ask about this conversation…',
                              border: InputBorder.none)))),
              const SizedBox(width: 8),
              _asking
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : GestureDetector(
                      onTap: _ask,
                      child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 18))),
            ]))),
      ]),
    );
  }
}

// ── File Sharing ──────────────────────────────────────────────────────────────
class FileSharingScreen extends StatefulWidget {
  const FileSharingScreen({super.key});
  @override
  State<FileSharingScreen> createState() => _FileSharingScreenState();
}

class _FileSharingScreenState extends State<FileSharingScreen> {
  late Future<List<ApiFile>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = context.read<AppServices>().files.listFiles().unwrap();
  }

  void _reload() {
    setState(() {
      _filesFuture = context.read<AppServices>().files.listFiles().unwrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Shared Files',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                icon: const Icon(Icons.upload_file_outlined), onPressed: () {})
          ]),
      body: FutureBuilder<List<ApiFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  snapshot.error?.toString() ?? 'Failed to load files',
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ]),
            );
          }
          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return const Center(
              child: Text('No shared files yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _filesFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: files.map((f) => TCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.insert_drive_file_outlined,
                          color: AppColors.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(f.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 13)),
                        Text('${f.size} • ${f.uploadedBy}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ])),
                  IconButton(
                      icon: const Icon(Icons.download_outlined,
                          color: AppColors.primary),
                      onPressed: () {}),
                ]),
              )).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ── File Integrity ────────────────────────────────────────────────────────────
class FileIntegrityScreen extends StatefulWidget {
  const FileIntegrityScreen({super.key});
  @override
  State<FileIntegrityScreen> createState() => _FileIntegrityScreenState();
}

class _FileIntegrityScreenState extends State<FileIntegrityScreen> {
  late Future<List<ApiFile>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = context.read<AppServices>().files.listFiles().unwrap();
  }

  void _reload() {
    setState(() {
      _filesFuture = context.read<AppServices>().files.listFiles().unwrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('File Integrity',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<ApiFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  snapshot.error?.toString() ?? 'Failed to load files',
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ]),
            );
          }
          final files = snapshot.data ?? [];
          final verified =
              files.where((f) => f.sha256.isNotEmpty).length;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _filesFuture;
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TCard(
                  child: Column(children: [
                Icon(
                  verified == files.length && files.isNotEmpty
                      ? Icons.verified_user
                      : Icons.info_outline,
                  color: verified > 0 ? AppColors.success : AppColors.warning,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  files.isEmpty
                      ? 'No files uploaded'
                      : '$verified / ${files.length} files report a SHA-256 hash',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hashes come from the backend file metadata.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                )
              ])),
              const SizedBox(height: 12),
              if (files.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No files to verify.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...files.map((f) => TCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(
                          f.sha256.isNotEmpty
                              ? Icons.check_circle
                              : Icons.help_outline,
                          color: f.sha256.isNotEmpty
                              ? AppColors.success
                              : AppColors.warning,
                          size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(f.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary))),
                      TChip(
                          label: f.sha256.isNotEmpty ? 'SHA-256 ✓' : 'No hash',
                          bg: (f.sha256.isNotEmpty
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.1),
                          textColor: f.sha256.isNotEmpty
                              ? AppColors.success
                              : AppColors.warning),
                    ]))),
            ]),
          );
        },
      ),
    );
  }
}
