// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_nylas_suppression.dart';

const _tracerName = 'dartastic_otel_libs_nylas';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class NylasResult {
  const NylasResult({
    this.itemCount,
    this.provider,
    this.grantId,
    this.grantStatus,
    this.syncState,
    this.usedCursor,
    this.nextCursor,
    this.scheduledMessageId,
    this.requestId,
    this.statusCode,
  });

  /// `data.length` for list endpoints.
  final int? itemCount;

  /// Upstream provider: `google` / `microsoft` / `imap` / `icloud` /
  /// `outlook` / `exchange` / `yahoo`. Different providers have very
  /// different latency + reliability profiles — primary slice dim.
  final String? provider;

  /// Nylas Grant ID (the connected mailbox — also Nylas's billing
  /// unit since v3 prices per active grant).
  final String? grantId;

  /// `valid` / `invalid` / `revoked` — invalid grants are a high
  /// support signal.
  final String? grantStatus;

  /// `running` / `partial` / `stopped` / `invalid` for mailbox sync.
  final String? syncState;

  /// Whether `cursor` pagination was used (incremental sync).
  final bool? usedCursor;

  /// `next_cursor` returned.
  final String? nextCursor;

  /// Scheduled-send id from /messages/send-after.
  final String? scheduledMessageId;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class NylasCallResult<T> {
  const NylasCallResult({required this.value, this.result});
  final T value;
  final NylasResult? result;
}

/// Wraps a Nylas v3 API call in a CLIENT span. [operation] is one of
/// `events.list`, `events.get`, `events.create`, `events.update`,
/// `events.delete`, `freebusy`, `availability`, `messages.list`,
/// `messages.send`, `threads.list`, `drafts.create`, `contacts.list`,
/// `calendars.list`, `grants.list`, `grants.get`, `connectors.list`,
/// `webhooks.create`, `scheduling.bookings`, `notetakers.create`.
Future<T> tracedNylas<T>({
  required String operation,
  required Future<NylasCallResult<T>> Function() invoke,
  String? grantId,
  String? domain,
}) async {
  if (nylasInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'nylas',
    'rpc.method': operation,
    'nylas.operation': operation,
  };
  if (grantId != null) m['nylas.grant.id'] = grantId;
  if (domain != null) m['nylas.domain'] = domain;

  final span = _tracer().startSpan(
    'nylas $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'nylas.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.provider != null) {
        extras.add(OTel.attributeString(
          'nylas.provider',
          r.result!.provider!,
        ));
      }
      if (r.result!.grantId != null) {
        extras.add(OTel.attributeString(
          'nylas.grant.id',
          r.result!.grantId!,
        ));
      }
      if (r.result!.grantStatus != null) {
        extras.add(OTel.attributeString(
          'nylas.grant.status',
          r.result!.grantStatus!,
        ));
        if (r.result!.grantStatus == 'invalid' ||
            r.result!.grantStatus == 'revoked') {
          span.setStatus(
            SpanStatusCode.Error,
            'Nylas grant ${r.result!.grantStatus}',
          );
        }
      }
      if (r.result!.syncState != null) {
        extras.add(OTel.attributeString(
          'nylas.sync_state',
          r.result!.syncState!,
        ));
      }
      if (r.result!.usedCursor != null) {
        extras.add(OTel.attributeBool(
          'nylas.cursor.used',
          r.result!.usedCursor!,
        ));
      }
      if (r.result!.nextCursor != null) {
        extras.add(OTel.attributeBool(
          'nylas.cursor.next.present',
          true,
        ));
      }
      if (r.result!.scheduledMessageId != null) {
        extras.add(OTel.attributeString(
          'nylas.scheduled_message.id',
          r.result!.scheduledMessageId!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'nylas.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Nylas HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
