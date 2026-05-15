import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Event types emitted by the WebSocket manager.
enum SocketEvent {
  connected,
  disconnected,
  chatMessage,
  notification,
  taskUpdate,
}

/// Payload delivered with every [SocketEvent].
class SocketPayload {
  final SocketEvent event;
  final Map<String, dynamic> data;

  const SocketPayload({required this.event, this.data = const {}});
}

/// Centralized WebSocket manager with auto-reconnect and event streaming.
///
/// Usage:
/// ```dart
/// final ws = WebSocketManager(tokenStorage);
/// ws.stream.listen((payload) { ... });
/// await ws.connect();
/// ws.joinRoom('room_123');
/// ws.sendMessage('room_123', 'Hello!');
/// ```
class WebSocketManager {
  final TokenStorage _tokenStorage;

  io.Socket? _socket;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;

  final _controller = StreamController<SocketPayload>.broadcast();

  /// Stream of all incoming events.
  Stream<SocketPayload> get stream => _controller.stream;

  /// Whether the socket is currently connected.
  bool get isConnected => _socket?.connected ?? false;

  WebSocketManager(this._tokenStorage);

  /// Establish a Socket.IO connection authenticated via JWT.
  Future<void> connect() async {
    if (_disposed) return;

    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) return;

    _socket?.dispose();
    _socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(_maxReconnectAttempts)
          .build(),
    );

    _socket!.onConnect((_) {
      _reconnectAttempts = 0;
      debugPrint('[WS] Connected');
      _emit(SocketEvent.connected);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[WS] Disconnected');
      _emit(SocketEvent.disconnected);
    });

    _socket!.onReconnectAttempt((_) async {
      _reconnectAttempts++;
      debugPrint('[WS] Reconnect attempt $_reconnectAttempts');
      // Read fresh token for reconnect (old one may have been refreshed)
      final freshToken = await _tokenStorage.readAccessToken();
      if (freshToken != null && freshToken.isNotEmpty) {
        _socket?.io.options?['extraHeaders'] = {
          'Authorization': 'Bearer $freshToken'
        };
        _socket?.io.options?['auth'] = {'token': freshToken};
      }
    });

    _socket!.onReconnectFailed((_) {
      debugPrint('[WS] Reconnect failed after $_maxReconnectAttempts attempts');
      _emit(SocketEvent.disconnected, {'reason': 'reconnect_failed'});
      disconnect(); // Clean up the dead socket
    });

    // ── Chat events ──────────────────────────────────────────────────────
    _socket!.on('new_message', (data) {
      _emit(SocketEvent.chatMessage, _asMap(data));
    });

    _socket!.on('message', (data) {
      _emit(SocketEvent.chatMessage, _asMap(data));
    });

    // ── Notification events ──────────────────────────────────────────────
    _socket!.on('notification', (data) {
      _emit(SocketEvent.notification, _asMap(data));
    });

    // ── Task events ──────────────────────────────────────────────────────
    _socket!.on('task_update', (data) {
      _emit(SocketEvent.taskUpdate, _asMap(data));
    });

    _socket!.on('task_status_changed', (data) {
      _emit(SocketEvent.taskUpdate, _asMap(data));
    });

    _socket!.connect();
  }

  /// Join a chat room.
  void joinRoom(String roomId) {
    _socket?.emit('join_chat', {'room_id': roomId});
  }

  /// Leave a chat room.
  void leaveRoom(String roomId) {
    _socket?.emit('leave_chat', {'room_id': roomId});
  }

  /// Send a chat message to a room.
  void sendMessage(String roomId, String content) {
    _socket?.emit('send_message', {
      'room_id': roomId,
      'content': content,
    });
  }

  /// Disconnect and clean up.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Permanently dispose — no reconnect possible after this.
  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _emit(SocketEvent event, [Map<String, dynamic> data = const {}]) {
    if (!_controller.isClosed) {
      _controller.add(SocketPayload(event: event, data: data));
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}
