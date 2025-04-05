import 'dart:async';
import 'dart:convert';

import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';

/// A client specifically designed for handling Server-Sent Events (SSE).
///
/// Encapsulates connection details, authentication, and event parsing logic,
/// using the 'flutter_client_sse' package.
class SseClient {

  // --------------- Singleton Pattern (Optional but common) ---------------
  // Private constructor
  SseClient._internal() : _baseUrl = AppConfig.apiBaseUrl;

  // Factory constructor to return the instance
  factory SseClient() {
    return _instance;
  }
  final String _tag = 'SseClient';
  final String _baseUrl;
  
  // 存储活跃连接，以便于管理
  final Map<String, StreamSubscription> _activeConnections = {};

  // Static instance
  static final SseClient _instance = SseClient._internal();
  // --------------- End Singleton Pattern ---------------

  // Or a simple public constructor if singleton is not desired:
  // SseClient() : _baseUrl = AppConfig.apiBaseUrl;


  /// Connects to an SSE endpoint and streams parsed events of type [T].
  ///
  /// Handles base URL construction, authentication, and event parsing using flutter_client_sse.
  ///
  /// - [path]: The relative path to the SSE endpoint (e.g., '/novels/import/jobId/status').
  /// - [parser]: A function that takes a JSON map and returns an object of type [T].
  /// - [eventName]: (Optional) The specific SSE event name to listen for. Defaults to 'message'.
  /// - [queryParams]: (Optional) Query parameters to add to the URL.
  /// - [method]: The HTTP method (defaults to GET).
  /// - [body]: The request body for POST requests.
  /// - [connectionId]: Optional. An identifier for this connection. If not provided, a random ID will be generated.
  Stream<T> streamEvents<T>({
    required String path,
    required T Function(Map<String, dynamic>) parser,
    String? eventName = 'message', // Default event name to filter
    Map<String, String>? queryParams,
    SSERequestType method = SSERequestType.GET, // Default to GET
    Map<String, dynamic>? body, // For POST requests
    String? connectionId,
  }) {
    final controller = StreamController<T>();
    final cid = connectionId ?? 'conn_${DateTime.now().millisecondsSinceEpoch}_${_activeConnections.length}';

    try {
      // 1. Prepare URL
      final fullPath = path.startsWith('/') ? path : '/$path';
      final uri = Uri.parse('$_baseUrl$fullPath');
      final urlWithParams = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;
      final urlString = urlWithParams.toString(); // flutter_client_sse uses String URL
      AppLogger.i(_tag, '[SSE] Connecting via ${method.name} to endpoint: $urlString');

      // 2. Prepare Headers & Authentication
      final authToken = AppConfig.authToken;
      if (authToken == null) {
        AppLogger.e(_tag, '[SSE] Auth token is null. Cannot establish SSE connection.');
        throw ApiException(401, 'Authentication token is missing');
      }
      final headers = {
        // Accept and Cache-Control might be added automatically by the package,
        // but explicitly adding them is safer.
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Authorization': 'Bearer $authToken',
        // Add content-type if needed for POST
        if (method == SSERequestType.POST && body != null)
           'Content-Type': 'application/json',
      };
      AppLogger.d(_tag, '[SSE] Headers: $headers');
      if (body != null) {
         AppLogger.d(_tag, '[SSE] Body: $body');
      }


      // 3. Subscribe using flutter_client_sse
      // This method directly returns the stream subscription management is handled internally.
      // We listen to it and push data/errors into our controller.
      final sseSubscription = SSEClient.subscribeToSSE(
        method: method,
        url: urlString,
        header: headers,
        body: body,
      ).listen(
        (event) {
          AppLogger.v(_tag, '[SSE] Raw Event: ID=${event.id}, Event=${event.event}, Data=${event.data}');

          // 处理心跳消息
          if (event.id != null && event.id!.startsWith('heartbeat-')) {
            AppLogger.v(_tag, '[SSE] 收到心跳消息: ${event.id}');
            return; // 跳过心跳处理
          }

          // Determine event name (treat null/empty as 'message')
          final currentEventName = (event.event == null || event.event!.isEmpty) ? 'message' : event.event;

          // Filter by expected event name
          if (eventName != null && currentEventName != eventName) {
            AppLogger.v(_tag, '[SSE] Skipping event name: $currentEventName (Expected: $eventName)');
            return; // Skip this event
          }

          final data = event.data;
          if (data == null || data.isEmpty || data == '[DONE]') {
             AppLogger.v(_tag, '[SSE] Skipping empty or [DONE] data.');
            return; // Skip this event
          }

          // Parse data
          try {
            final json = jsonDecode(data);
            if (json is Map<String, dynamic>) {
              final parsedData = parser(json);
              AppLogger.v(_tag, '[SSE] Parsed data for event \'$currentEventName\': $parsedData');
              if (!controller.isClosed) {
                controller.add(parsedData); // Add parsed data to our stream
              }
            } else {
              AppLogger.w(_tag, '[SSE] Event data is not a JSON object: $data');
            }
          } catch (e, stack) {
            AppLogger.e(_tag, '[SSE] Failed to parse JSON data: $data', e, stack);
             if (!controller.isClosed) {
                // Report parsing errors through the stream
                controller.addError(ApiException(-1, 'Failed to parse SSE data: $e'), stack);
             }
          }
        },
        onError: (error, stackTrace) {
          AppLogger.e(_tag, '[SSE] Stream error received', error, stackTrace);
          if (!controller.isClosed) {
            // Convert to ApiException for consistency
            controller.addError(ApiException(-1, 'SSE stream error: $error'), stackTrace);
            controller.close(); // Close controller on stream error
          }
          // 移除连接
          _activeConnections.remove(cid);
        },
        onDone: () {
          AppLogger.i(_tag, '[SSE] Stream finished (onDone received).');
          if (!controller.isClosed) {
            controller.close(); // Close controller when the source stream is done
          }
          // 移除连接
          _activeConnections.remove(cid);
        },
      );

      // 保存此连接以便于后续管理
      _activeConnections[cid] = sseSubscription;
      AppLogger.i(_tag, '[SSE] Connection $cid has been registered. Active connections: ${_activeConnections.length}');

      // Handle cancellation of the downstream listener
      controller.onCancel = () {
         AppLogger.i(_tag, '[SSE] Downstream listener cancelled. Cancelling SSE subscription for connection $cid.');
         sseSubscription.cancel();
         // 移除连接
         _activeConnections.remove(cid);
         // Ensure controller is closed if not already
         if (!controller.isClosed) {
            controller.close();
         }
      };

    } catch (e, stack) {
      // Catch synchronous errors during setup (e.g., URI parsing, initial auth check)
      AppLogger.e(_tag, '[SSE] Setup Error', e, stack);
      controller.addError(
          e is ApiException ? e : ApiException(-1, 'SSE setup failed: $e'), stack);
      controller.close();
    }

    return controller.stream;
  }

  /// 取消特定连接
  /// 
  /// - [connectionId]: The ID of the connection to cancel
  /// - 返回: True if connection was found and cancelled, false otherwise
  Future<bool> cancelConnection(String connectionId) async {
    final connection = _activeConnections[connectionId];
    if (connection != null) {
      AppLogger.i(_tag, '[SSE] Manually cancelling connection $connectionId');
      await connection.cancel();
      _activeConnections.remove(connectionId);
      return true;
    }
    AppLogger.w(_tag, '[SSE] Connection $connectionId not found or already closed');
    return false;
  }
  
  /// 取消所有活跃连接
  Future<void> cancelAllConnections() async {
    AppLogger.i(_tag, '[SSE] Cancelling all active connections (count: ${_activeConnections.length})');
    
    // 创建一个连接ID列表，以避免在迭代过程中修改集合
    final connectionIds = _activeConnections.keys.toList();
    
    for (final id in connectionIds) {
      try {
        final connection = _activeConnections[id];
        if (connection != null) {
          await connection.cancel();
          _activeConnections.remove(id);
          AppLogger.d(_tag, '[SSE] Cancelled connection $id');
        }
      } catch (e) {
        AppLogger.e(_tag, '[SSE] Error cancelling connection $id', e);
      }
    }
    
    AppLogger.i(_tag, '[SSE] All connections cancelled. Remaining: ${_activeConnections.length}');
  }
  
  /// 获取活跃连接数
  int get activeConnectionCount => _activeConnections.length;
}
