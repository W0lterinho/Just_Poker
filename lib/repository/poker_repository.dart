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

  StompClient createStompClient({
    required void Function(StompFrame) onConnect,
    required void Function(dynamic) onError,
    required void Function() onDisconnect,
  }) {
    // Upewnij się, że stary klient jest zamknięty przed utworzeniem nowego
    _stompClient?.deactivate();
    _stompClient = null;

    final client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        onConnect: onConnect,
        onWebSocketError: onError,
        onStompError: (f) => onError(f.body),
        onDisconnect: (_) => onDisconnect(),
        // Wyłączamy automatyczny reconnect biblioteki (reconnectDelay: 0),
        // ponieważ chcemy kontrolować logikę 25 prób * 5s ręcznie w Cubicie
        // i zapewnić pełne czyszczenie ("Zombie Sockets").
        reconnectDelay: const Duration(seconds: 0),
        // Heartbeat co 10s (incoming & outgoing) zgodnie z wymaganiami
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    )..activate();
    _stompClient = client;
    return client;
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
          // Use dynamic first to avoid cast exception if the format is unexpected
          final dynamic decoded = jsonDecode(frame.body!);

          if (decoded is Map<String, dynamic>) {
             controller.add(fromJson(decoded));
          } else {
             print('WS Error: Expected Map<String, dynamic> but got ${decoded.runtimeType}');
             // Attempt unsafe cast if necessary or handle other types if required
             // But for now, just print error instead of swallowing it silently.
             // If fromJson can handle it, maybe we can try:
             // controller.add(fromJson(decoded as Map<String, dynamic>));
             // But that would throw.
          }
        } catch (e, stack) {
          print('WS Parsing Error on $topic: $e');
          print(stack);
        }
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
