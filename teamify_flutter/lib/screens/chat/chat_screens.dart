import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/meeting_browser_speech.dart';
import '../../core/audio/meeting_speech_recorder.dart';
import '../../core/files/file_downloader.dart';
import '../../core/files/file_actions.dart';
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

DateTime? _parseMessageDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  var parsed = DateTime.tryParse(iso);
  if (parsed != null) return parsed.toLocal();
  // SQLite / API sometimes returns "2026-05-25 10:00:00" without "T".
  final normalized =
      iso.contains(' ') && !iso.contains('T') ? iso.replaceFirst(' ', 'T') : iso;
  parsed = DateTime.tryParse(normalized);
  if (parsed != null) return parsed.toLocal();
  if (!iso.endsWith('Z') && !iso.contains('+')) {
    parsed = DateTime.tryParse('${normalized}Z');
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

String _formatChatDateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  final month = months[dt.month - 1];
  if (dt.year == now.year) return '${dt.day} $month';
  return '${dt.day} $month ${dt.year}';
}

class _ChatListItem {
  final String? dateLabel;
  final ChatMessage? message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const _ChatListItem.date(this.dateLabel)
      : message = null,
        isFirstInGroup = false,
        isLastInGroup = false;

  const _ChatListItem.msg(
    this.message, {
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  }) : dateLabel = null;
}

bool _sameMessageGroup(ChatMessage a, ChatMessage b) {
  if (a.isMe != b.isMe) return false;
  if (a.senderId.isNotEmpty && b.senderId.isNotEmpty) {
    if (a.senderId != b.senderId) return false;
  } else if (a.senderName != b.senderName) {
    return false;
  }
  final da = a.createdAt;
  final db = b.createdAt;
  if (da == null || db == null) return true;
  return db.difference(da).inMinutes.abs() <= 4;
}

List<_ChatListItem> _chatListItems(List<ChatMessage> messages) {
  final sorted = [...messages]
    ..sort((a, b) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    });
  final items = <_ChatListItem>[];
  String? lastLabel;
  for (var i = 0; i < sorted.length; i++) {
    final m = sorted[i];
    if (m.createdAt == null) continue;
    final label = _formatChatDateLabel(m.createdAt!);
    if (label != lastLabel) {
      items.add(_ChatListItem.date(label));
      lastLabel = label;
    }
    final prev = i > 0 ? sorted[i - 1] : null;
    final next = i < sorted.length - 1 ? sorted[i + 1] : null;
    final first = prev == null || !_sameMessageGroup(prev, m);
    final last = next == null || !_sameMessageGroup(m, next);
    items.add(_ChatListItem.msg(m, isFirstInGroup: first, isLastInGroup: last));
  }
  return items;
}

String _formatMsgTime(String? iso) {
  final dt = _parseMessageDate(iso);
  if (dt == null) return '—';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _formatMsgTimeFromDateTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

ChatMessage _messageFromRow(Map<String, dynamic> m, String? myId) {
  final senderId = m['sender_id']?.toString() ?? '';
  final senderName = m['sender_name']?.toString() ?? 'User';
  final created = m['created_at']?.toString() ?? '';
  final createdAt = _parseMessageDate(created);
  final attachment = m['attachment'] is Map
      ? Map<String, dynamic>.from(m['attachment'] as Map)
      : null;
  final fileId =
      m['file_id']?.toString() ?? attachment?['file_id']?.toString();
  return ChatMessage(
    id: m['id']?.toString() ?? '',
    senderId: senderId,
    senderName: senderName,
    senderInitials: _initialsFromName(senderName),
    message: m['content']?.toString() ?? '',
    time: _formatMsgTime(created),
    isMe: myId != null && senderId == myId,
    messageType: m['message_type']?.toString() ?? 'text',
    fileId: fileId,
    fileName: attachment?['filename']?.toString(),
    mimeType: attachment?['mime_type']?.toString(),
    createdAt: createdAt,
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
          TBottomNav(current: 3, onTap: (i) => handleRoleNav(context, i)),
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
  final MeetingBrowserSpeech _voiceSpeech = MeetingBrowserSpeech();
  String _voiceDraft = '';
  StreamSubscription<SocketPayload>? _socketSub;
  WebSocketManager? _ws;
  bool _loadingHistory = true;
  bool _recordingVoice = false;
  bool _transcribingVoice = false;
  String? _roomId;
  String? _projectId;
  String _roomName = 'Chat';
  int _memberCount = 0;
  bool _sendingAttachment = false;
  final ScrollController _chatScroll = ScrollController();

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
    if (_recordingVoice) {
      unawaited(_voiceSpeech.stop(null));
    }
    _voiceRecorder.dispose();
    _ctrl.dispose();
    _chatScroll.dispose();
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
      _projectId = room.projectId;
    });
    try {
      final roomData =
          await context.read<AppServices>().chat.getRoom(room.id).unwrap();
      if (mounted) {
        _projectId ??= projectIdFromChatRoomPayload(roomData);
        final members =
            (roomData['members'] as List?)?.whereType<Map<String, dynamic>>();
        _memberCount = members?.length ?? 0;
        if (_projectId != null || _memberCount > 0) setState(() {});
      }
    } catch (_) {}
    await _loadHistory();
    await _ws?.connect();
    _subscribeSocket();
  }

  void _subscribeSocket() {
    final ws = _ws;
    final rid = _roomId;
    if (ws == null || rid == null) return;
    if (ws.isConnected) ws.joinRoom(rid);
    _socketSub?.cancel();
    _socketSub = ws.stream.listen((payload) {
      if (payload.event == SocketEvent.connected) {
        ws.joinRoom(rid);
        return;
      }
      if (payload.event == SocketEvent.chatMessage) {
        final d = payload.data;
        final msgRoom = d['room_id']?.toString();
        if (msgRoom != rid) return;
        _appendServerMessage(Map<String, dynamic>.from(d));
      } else if (payload.event == SocketEvent.messageDeleted) {
        final d = payload.data;
        final msgRoom = d['room_id']?.toString();
        if (msgRoom != rid) return;
        final id =
            d['message_id']?.toString() ?? d['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _removeMessageById(id);
        }
      }
    });
  }

  void _appendServerMessage(Map<String, dynamic> d) {
    if (!mounted) return;
    final session = context.read<SessionController>();
    final myId = session.currentUser?.id;
    final id = d['id']?.toString() ?? '';
    final content = d['content']?.toString() ?? '';
    if (id.isNotEmpty && _seenIds.contains(id)) {
      setState(() {
        _messages.removeWhere((m) =>
            m.isPending &&
            m.isMe &&
            m.message == content &&
            (myId == null || m.senderId == myId));
      });
      return;
    }
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

  void _confirmPendingFromServer(String pendingId, Map<String, dynamic> row) {
    if (!mounted) return;
    final session = context.read<SessionController>();
    final myId = session.currentUser?.id;
    final incoming = _messageFromRow(row, myId);
    final id = incoming.id;
    if (id.isNotEmpty && _seenIds.contains(id)) {
      setState(() => _messages.removeWhere((m) => m.id == pendingId));
      return;
    }
    if (id.isNotEmpty) _seenIds.add(id);
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == pendingId);
      if (idx >= 0) {
        _messages[idx] = incoming;
      } else {
        _messages.removeWhere((m) =>
            m.isPending &&
            m.isMe &&
            m.message == incoming.message &&
            (myId == null || m.senderId == myId));
        if (id.isEmpty || !_messages.any((m) => m.id == id)) {
          _messages.add(incoming);
        }
      }
    });
  }

  void _failPending(String pendingId, String message) {
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m.id == pendingId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleSendResult(
    String pendingId,
    ApiResult<Map<String, dynamic>> result,
  ) {
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final raw = result.data!;
      final row = raw['data'];
      if (row is Map) {
        _confirmPendingFromServer(
          pendingId,
          Map<String, dynamic>.from(row),
        );
        return;
      }
      if (raw.containsKey('id') && raw.containsKey('content')) {
        _confirmPendingFromServer(pendingId, raw);
        return;
      }
    }
    if (result.isOfflineQueued) return;
    _failPending(pendingId, result.error ?? 'Could not send message');
  }

  Future<void> _confirmPendingViaRestIfNeeded(
    String pendingId,
    String rid,
    Map<String, dynamic> payload,
  ) async {
    await Future.delayed(const Duration(seconds: 8));
    if (!mounted) return;
    if (!_messages.any((m) => m.id == pendingId && m.isPending)) return;
    final ws = _ws ?? context.read<WebSocketManager>();
    if (ws.isConnected) return;
    final result =
        await context.read<AppServices>().chat.sendMessage(rid, payload);
    _handleSendResult(pendingId, result);
  }

  void _removeMessageById(String id) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.id == id);
      _seenIds.remove(id);
    });
  }

  Future<void> _confirmDeleteMessage(ChatMessage m) async {
    final rid = _roomId;
    if (rid == null) return;

    if (m.isPending) {
      _removeMessageById(m.id);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be removed for everyone in this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result =
        await context.read<AppServices>().chat.deleteMessage(rid, m.id);
    if (!mounted) return;

    if (result.isSuccess) {
      _removeMessageById(m.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: ${result.error}')),
      );
    }
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
      _scrollChatToEnd();
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Share',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachAction(
                    ctx,
                    icon: Icons.photo_outlined,
                    label: 'Photo',
                    color: const Color(0xFF10B981),
                    onTap: () => _pickAndSendAttachment(
                      ctx,
                      type: FileType.image,
                      messageType: 'image',
                    ),
                  ),
                  _attachAction(
                    ctx,
                    icon: Icons.insert_drive_file_outlined,
                    label: 'File',
                    color: AppColors.primary,
                    onTap: () => _pickAndSendAttachment(
                      ctx,
                      type: FileType.any,
                      messageType: 'file',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
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
                subtitle: const Text('Live speech + transcript'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMeeting();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachAction(
    BuildContext sheetCtx, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendAttachment(
    BuildContext sheetCtx, {
    required FileType type,
    required String messageType,
  }) async {
    Navigator.pop(sheetCtx);
    if (_sendingAttachment || _roomId == null) return;

    final fileSvc = context.read<AppServices>().files;
    final result = await FilePicker.pickFiles(
      type: type,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    final path = picked.path;
    if (bytes == null && (path == null || path.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file from device.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _sendingAttachment = true);
    final upload = await fileSvc.uploadFile(
      filePath: path ?? '',
      filename: picked.name,
      projectId: _projectId,
      fileBytes: bytes,
    );
    if (!mounted) return;
    setState(() => _sendingAttachment = false);

    if (!upload.isSuccess || upload.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(upload.error ?? 'Upload failed')),
      );
      return;
    }

    final caption = _ctrl.text.trim();
    _ctrl.clear();
    await _sendAttachmentMessage(
      fileId: upload.data!.id,
      messageType: messageType,
      caption: caption.isNotEmpty ? caption : null,
      displayName: picked.name,
    );
  }

  Future<void> _sendAttachmentMessage({
    required String fileId,
    required String messageType,
    String? caption,
    String? displayName,
  }) async {
    final rid = _roomId;
    if (rid == null || !mounted) return;

    final ws = _ws ?? context.read<WebSocketManager>();
    final session = context.read<SessionController>();
    final myId = session.currentUser?.id ?? '';
    final displayNameUser = session.currentUser?.displayName ??
        session.currentUser?.fullName ??
        'You';
    final label = caption ?? displayName ?? 'Attachment';

    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    setState(() {
      _messages.add(ChatMessage(
        id: pendingId,
        senderId: myId,
        senderName: displayNameUser,
        senderInitials: _initialsFromName(displayNameUser),
        message: label,
        time: _formatMsgTimeFromDateTime(now),
        isMe: true,
        isPending: true,
        messageType: messageType,
        fileId: fileId,
        fileName: displayName,
        createdAt: now,
      ));
    });

    final payload = {
      'content': label,
      'message_type': messageType,
      'file_id': int.tryParse(fileId) ?? fileId,
    };

    if (!ws.isConnected) {
      await ws.connect();
    }
    if (!mounted) return;

    if (ws.isConnected) {
      ws.sendChatPayload(rid, payload);
      unawaited(_confirmPendingViaRestIfNeeded(pendingId, rid, payload));
    } else {
      final result =
          await context.read<AppServices>().chat.sendMessage(rid, payload);
      _handleSendResult(pendingId, result);
    }
  }

  Future<void> _toggleVoiceMessage() async {
    if (_transcribingVoice) return;
    final rid = _roomId;
    if (rid == null) return;

    if (!_recordingVoice) {
      if (kIsWeb) {
        final ok = await _voiceSpeech.initialize();
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Speech recognition is not available in this browser.',
              ),
            ),
          );
          return;
        }
        _voiceDraft = '';
        final started = await _voiceSpeech.startListening((text, isFinal) {
          if (!mounted || text.trim().isEmpty) return;
          setState(() => _voiceDraft = text.trim());
        });
        if (!started) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not start speech recognition.'),
            ),
          );
          return;
        }
        if (!mounted) return;
        setState(() => _recordingVoice = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Listening… Tap mic to send, or ✕ to cancel.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

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
          content: Text(
            'Recording… Tap mic to send, or ✕ to cancel.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (kIsWeb) {
      setState(() {
        _recordingVoice = false;
        _transcribingVoice = true;
      });
      await _voiceSpeech.stop((text, isFinal) {
        if (text.trim().isNotEmpty) {
          _voiceDraft = text.trim();
        }
      });
      if (!mounted) return;
      setState(() => _transcribingVoice = false);

      final text = _voiceDraft.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No speech detected. Try again.')),
        );
        return;
      }

      _ctrl.text = text;
      _voiceDraft = '';
      await _send();
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
                ? 'Speech service is unavailable right now. Try again later.'
                : 'Transcription failed: ${result.error ?? 'empty'}',
          ),
        ),
      );
      return;
    }

    _ctrl.text = result.data!.text.trim();
    await _send();
  }

  Future<void> _cancelVoiceMessage() async {
    if (!_recordingVoice || _transcribingVoice) return;
    if (kIsWeb) {
      await _voiceSpeech.stop(null);
    } else {
      await _voiceRecorder.cancelVoiceNote();
    }
    if (!mounted) return;
    setState(() {
      _recordingVoice = false;
      _voiceDraft = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice recording cancelled.'),
        duration: Duration(seconds: 2),
      ),
    );
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

    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final pending = ChatMessage(
      id: pendingId,
      senderId: myId,
      senderName: displayName,
      senderInitials: _initialsFromName(displayName),
      message: text,
      time: _formatMsgTimeFromDateTime(now),
      isMe: true,
      isPending: true,
      createdAt: now,
    );
    final payload = {'content': text, 'message_type': 'text'};
    setState(() {
      _messages.add(pending);
      _ctrl.clear();
    });
    _scrollChatToEnd();

    if (ws.isConnected) {
      ws.sendMessage(rid, text);
      unawaited(_confirmPendingViaRestIfNeeded(pendingId, rid, payload));
    } else {
      final result =
          await context.read<AppServices>().chat.sendMessage(rid, payload);
      _handleSendResult(pendingId, result);
    }
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _chatStatusLine() {
    if (_loadingHistory) return 'Loading messages…';
    final connected = _ws?.isConnected ?? false;
    final status = connected ? 'Connected' : 'Offline';
    if (_memberCount > 0) {
      final n = _memberCount;
      return '$status · $n ${n == 1 ? 'member' : 'members'}';
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final myInitials =
        _initialsFromName(session.currentUser?.displayName ?? 'Me');
    final chatItems = _chatListItems(_messages);
    final connected = _ws?.isConnected ?? false;

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
        titleSpacing: 0,
        title: Row(
          children: [
            TAvatar(
              initials: _roomName.isNotEmpty ? _roomName[0] : 'C',
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: connected
                              ? AppColors.success
                              : AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _chatStatusLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.primaryLight.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: chatItems.length,
                  itemBuilder: (_, i) {
                    final item = chatItems[i];
                    if (item.dateLabel != null) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: 8,
                            top: i > 0 ? 6 : 0,
                          ),
                          child: TChip(
                            label: item.dateLabel!,
                            bg: AppColors.border,
                          ),
                        ),
                      );
                    }
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(item.message!.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 6),
                          child: child,
                        ),
                      ),
                      child: _buildBubble(
                        item.message!,
                        myInitials,
                        isFirstInGroup: item.isFirstInGroup,
                        isLastInGroup: item.isLastInGroup,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(
    ChatMessage m,
    String myInitials, {
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    final isMe = m.isMe;
    final bubbleColor = isMe ? AppColors.primary : Colors.white;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;

    final topPad = isFirstInGroup ? 10.0 : 2.0;
    final bottomPad = isLastInGroup ? 8.0 : 2.0;

    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 20 : (isFirstInGroup ? 18 : 6)),
      topRight: Radius.circular(isMe ? (isFirstInGroup ? 18 : 6) : 20),
      bottomLeft: Radius.circular(isMe ? 20 : (isLastInGroup ? 6 : 18)),
      bottomRight: Radius.circular(isMe ? (isLastInGroup ? 6 : 18) : 20),
    );

    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: isLastInGroup
                  ? TAvatar(
                      initials: m.senderInitials,
                      radius: 15,
                      bg: AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isFirstInGroup)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      m.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onLongPress: isMe && !m.isPending
                        ? () => _confirmDeleteMessage(m)
                        : null,
                    borderRadius: radius,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                      padding: m.hasAttachment && m.isImage
                          ? const EdgeInsets.all(6)
                          : const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: radius,
                        border: isMe
                            ? null
                            : Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.hasAttachment)
                            _ChatAttachmentBody(
                              message: m,
                              isMe: isMe,
                              onOpen: () => _openAttachment(m),
                            ),
                          if (m.message.isNotEmpty &&
                              (!m.hasAttachment || !m.isImage))
                            Text(
                              m.message,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14.5,
                                height: 1.35,
                                letterSpacing: 0.1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isLastInGroup)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(
                      '${m.time}${m.isPending ? ' · sending' : ''}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) ...[
            SizedBox(
              width: 34,
              child: isLastInGroup
                  ? Opacity(
                      opacity: m.isPending ? 0.5 : 1,
                      child: TAvatar(initials: myInitials, radius: 15),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAttachment(ChatMessage m) async {
    final fid = m.fileId;
    if (fid == null || fid.isEmpty) return;

    if (m.isImage) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => _ChatImageViewerDialog(
          fileId: fid,
          title: m.fileName ?? 'Photo',
        ),
      );
      return;
    }

    try {
      final bytes =
          await context.read<AppServices>().files.downloadFile(fid).unwrap();
      if (!mounted) return;
      final name = m.fileName ?? 'attachment';
      await saveDownloadedBytes(
        filename: name,
        bytes: Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e')),
      );
    }
  }

  Widget _buildInput() => Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ChatInputIconButton(
                icon: _sendingAttachment
                    ? null
                    : Icons.add_rounded,
                tooltip: 'Attach',
                onPressed: _sendingAttachment || _transcribingVoice
                    ? null
                    : _showInputMenu,
                child: _sendingAttachment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              _ChatInputIconButton(
                icon: _transcribingVoice
                    ? Icons.hourglass_top_rounded
                    : _recordingVoice
                        ? Icons.stop_circle_rounded
                        : Icons.mic_rounded,
                tooltip: 'Voice',
                iconColor: _recordingVoice
                    ? const Color(0xFFDC2626)
                    : AppColors.primary,
                bgColor: _recordingVoice
                    ? const Color(0xFFFEE2E2)
                    : null,
                onPressed: _transcribingVoice || _sendingAttachment
                    ? null
                    : _toggleVoiceMessage,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: _recordingVoice
                        ? const Color(0xFFFEF2F2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: _recordingVoice
                          ? const Color(0xFFFECACA)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_recordingVoice) ...[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 12, right: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          minLines: 1,
                          maxLines: 5,
                          enabled: !_transcribingVoice &&
                              !_sendingAttachment &&
                              !_recordingVoice,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: _recordingVoice
                                ? (_voiceDraft.isNotEmpty
                                    ? _voiceDraft
                                    : 'Listening… tap mic to send')
                                : _transcribingVoice
                                    ? 'Transcribing…'
                                    : _sendingAttachment
                                        ? 'Uploading…'
                                        : 'Message',
                            hintStyle: const TextStyle(
                              color: AppColors.textHint,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      if (_recordingVoice)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                          tooltip: 'Cancel',
                          onPressed: _cancelVoiceMessage,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                elevation: 0,
                child: InkWell(
                  onTap: _transcribingVoice ||
                          _sendingAttachment ||
                          _recordingVoice
                      ? null
                      : _send,
                  borderRadius: BorderRadius.circular(24),
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ChatInputIconButton extends StatelessWidget {
  const _ChatInputIconButton({
    this.icon,
    this.child,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.bgColor,
  });

  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor ?? AppColors.background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: child ??
                  Icon(
                    icon,
                    size: 22,
                    color: iconColor ?? AppColors.primary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline image or file chip inside a chat bubble.
class _ChatAttachmentBody extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback onOpen;

  const _ChatAttachmentBody({
    required this.message,
    required this.isMe,
    required this.onOpen,
  });

  @override
  State<_ChatAttachmentBody> createState() => _ChatAttachmentBodyState();
}

class _ChatAttachmentBodyState extends State<_ChatAttachmentBody> {
  Uint8List? _thumbBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.isImage && widget.message.fileId != null) {
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    setState(() => _loading = true);
    try {
      final bytes = await context
          .read<AppServices>()
          .files
          .downloadFile(widget.message.fileId!)
          .unwrap();
      if (mounted) setState(() => _thumbBytes = Uint8List.fromList(bytes));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    if (m.isImage) {
      return GestureDetector(
        onTap: widget.onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _loading
              ? const SizedBox(
                  width: 200,
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _thumbBytes != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.memory(
                          _thumbBytes!,
                          width: 220,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Tap to open',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: 200,
                      height: 100,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_outlined,
                        color: widget.isMe ? Colors.white70 : AppColors.primary,
                      ),
                    ),
        ),
      );
    }

    return InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file,
              size: 20,
              color: widget.isMe ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                m.fileName ?? m.message,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen image viewer when tapping a chat photo.
class _ChatImageViewerDialog extends StatefulWidget {
  final String fileId;
  final String title;

  const _ChatImageViewerDialog({
    required this.fileId,
    required this.title,
  });

  @override
  State<_ChatImageViewerDialog> createState() => _ChatImageViewerDialogState();
}

class _ChatImageViewerDialogState extends State<_ChatImageViewerDialog> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context
          .read<AppServices>()
          .files
          .downloadFile(widget.fileId)
          .unwrap();
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    if (_bytes == null) return;
    final name = widget.title.contains('.')
        ? widget.title
        : '${widget.title}.jpg';
    await saveDownloadedBytes(filename: name, bytes: _bytes!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_bytes != null)
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: Colors.white),
                  tooltip: 'Download',
                  onPressed: _download,
                ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.black,
                child: _loading
                    ? const SizedBox(
                        width: 320,
                        height: 280,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      )
                    : _error != null
                        ? SizedBox(
                            width: 320,
                            height: 200,
                            child: Center(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4,
                            child: Image.memory(
                              _bytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin_outlined,
                  size: 48, color: AppColors.textHint),
              SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pinned messages will appear here once backend support is available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
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
  bool _uploading = false;

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

  Future<void> _uploadFile() async {
    if (_uploading) return;
    final fileSvc = context.read<AppServices>().files;
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    final path = picked.path;
    if (bytes == null && (path == null || path.isEmpty)) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read file from device.')),
      );
      return;
    }

    setState(() => _uploading = true);
    final upload = await fileSvc.uploadFile(
          filePath: path ?? '',
          filename: picked.name,
          fileBytes: bytes,
        );
    if (!mounted) return;
    setState(() => _uploading = false);

    if (!upload.isSuccess) {
      messenger.showSnackBar(
        SnackBar(content: Text(upload.error ?? 'Upload failed')),
      );
      return;
    }
    _reload();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Uploaded ${picked.name}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _downloadFile(ApiFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes =
          await context.read<AppServices>().files.downloadFile(file.id).unwrap();
      final actions = FileActions();
      final savedPath = await actions.saveBytes(file.name, bytes);
      await actions.openPath(savedPath);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
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
          title: const Text('Shared Files',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            _uploading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.upload_file_outlined),
                    onPressed: _uploadFile,
                  ),
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
                      onPressed: () => _downloadFile(f)),
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
