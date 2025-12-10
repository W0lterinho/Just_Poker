import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/sync_dto.dart';
import '../exceptions/conflict_exception.dart';

import '../models/request_dto.dart';
import '../models/state_dto.dart';

class PokerRepository {
  final Uri _joinPokerUrl = Uri.parse('http://10.0.2.2:8081/poker/join');
  final String _wsUrl = 'ws://10.0.2.2:8081/ws';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  StompClient? _stompClient;
  StompUnsubscribe? _userTopicUnsubscribe;
  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isConnected => _stompClient?.connected ?? false;

  Future<void> joinPoker({ required String nickName }) async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null) throw Exception('Lack of Authorization, please log in');
    final resp = await http.post(
      _joinPokerUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nickName': nickName}),
    );

    if (resp.statusCode == 409) {
      // Gracz jest już w grze - rzuć ConflictException
      throw ConflictException('Player is already in an ongoing game');
    }

    if (resp.statusCode != 200) {
      throw Exception('Join failed: ${resp.statusCode}');
    }
  }

  StompClient createStompClient() {
    _stompClient?.deactivate(); // Czyścimy starego klienta

    final client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        onConnect: (frame) {
          print('PokerRepo: Connected');
          _connectionStatusController.add(true);
        },
        onWebSocketError: (err) {
          print('PokerRepo: WS Error: $err');
          _connectionStatusController.add(false);
        },
        onStompError: (f) {
          // Logowanie błędów STOMP
          print('PokerRepo: Stomp Error: ${f.body}');
        },
        onDisconnect: (frame) {
          print('PokerRepo: Disconnected');
          _connectionStatusController.add(false);
        },
        reconnectDelay: const Duration(seconds: 5),
        connectionTimeout: const Duration(seconds: 5),
      ),
    )..activate();

    _stompClient = client;
    return client;
  }
  void dispose() {
    _connectionStatusController.close();
  }

  /// Wysyła payload.toJson() na [destination], czeka na pierwszą
  /// wiadomość z /topic/user/{email}, dekoduje JSON na dynamic,
  /// a następnie zwraca fromJson(decoded).
  Future<TRes> sendRequest<TReq, TRes>(
      String destination,
      TReq payload,
      Map<String, dynamic> Function(TReq) toJson,
      TRes Function(dynamic) fromJson,
      ) async {
    final client = _stompClient;
    if (client == null) {
      throw Exception('WebSocket nie jest połączony');
    }
    final completer = Completer<TRes>();
    final email = await _storage.read(key: 'userEmail');
    final topic = '/topic/user/$email';

    client.subscribe(
      destination: topic,
      callback: (frame) {
        print('WS INCOMING on $topic: ${frame.body}'); // do wyświetlania logów
        if (completer.isCompleted) return;
        final dynamic decoded = jsonDecode(frame.body!);
        try {
          final result = fromJson(decoded);
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    client.send(
      destination: destination,
      body: jsonEncode(toJson(payload)),
    );

    return completer.future;
  }

  Stream<T> subscribeTopic<T>(
      String topic,
      T Function(Map<String, dynamic>) fromJson,
      ) {
    final client = _stompClient!;
    final controller = StreamController<T>();
    final sub = client.subscribe(
      destination: topic,
      callback: (frame) {
        print('WS INCOMING on $topic: ${frame.body}'); // do wyświetlania logów
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          controller.add(fromJson(json));
        } catch (_) {}
      },
    );
    if (topic.startsWith('/topic/user/')) {
      _userTopicUnsubscribe = sub;
    }
    return controller.stream;
  }

  void unsubscribeUserTopic() {
    _userTopicUnsubscribe?.call();
    _userTopicUnsubscribe = null;
  }
  void disconnectWebSocket() {
    unsubscribeUserTopic(); // DODANE – zamknie subskrypcję usera
    _stompClient?.deactivate();
    _stompClient = null;
  }

  Future<SyncDTO> sendSync() async {
    final email = await _storage.read(key: 'userEmail');
    if (email == null || email.isEmpty) {
      throw Exception('Brak userEmail - nie można wysłać sync request');
    }

    final dto = RequestDTO(playerMail: email);

    return await sendRequest<RequestDTO, SyncDTO>(
      '/app/sync',
      dto,
          (d) => d.toJson(),
          (data) {
        print('sendSync otrzymał dane: $data');

        // Backend wysyła: {"type":"sync", "object": {...SyncDTO...}}
        if (data is Map<String, dynamic>) {
          // Sprawdź czy jest wrapper z type="sync"
          if (data['type'] == 'sync' && data['object'] != null) {
            print('Wykryto wrapper - wyciągam object');
            final syncData = data['object'] as Map<String, dynamic>;
            print('Object do parsowania: $syncData');
            return SyncDTO.fromJson(syncData);
          }

          // Fallback - jeśli backend wysyła bezpośrednio SyncDTO (bez wrappera)
          print('Brak wrappera - parsowanie bezpośrednie');
          return SyncDTO.fromJson(data);
        }

        throw Exception('Invalid sync response format: $data');
      },
    );
  }

  /// Wykonuje "świeże" dołączenie gracza (po odrzuceniu reconnect)
  Future<void> freshJoin({required String nickName}) async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null) throw Exception('Brak tokenu autoryzacji');

    final resp = await http.post(
      Uri.parse('http://10.0.2.2:8081/poker/freshJoin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nickName': nickName}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Fresh join failed: ${resp.statusCode}');
    }
  }
}

extension FireAndForget on PokerRepository {
  /// Wyślij STOMP-em bez czekania na odpowiedź.
  void sendFireAndForget<T>(
      String destination,
      T payload,
      Map<String, dynamic> Function(T) toJson,
      ) {
    if (_stompClient == null) {
      throw Exception('WebSocket not connected');
    }
    _stompClient!.send(
      destination: destination,
      body: jsonEncode(toJson(payload)),
    );
  }
}
