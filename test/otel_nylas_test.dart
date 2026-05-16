// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_nylas/otel_nylas.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_nylas-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('events.list records provider + grant + cursor', () async {
    await tracedNylas<String>(
      operation: 'events.list',
      grantId: 'g-1',
      invoke: () async => const NylasCallResult(
        value: 'ok',
        result: NylasResult(
          itemCount: 30,
          provider: 'google',
          grantId: 'g-1',
          grantStatus: 'valid',
          syncState: 'running',
          usedCursor: true,
          nextCursor: 'c-1',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('nylas events.list')!);
    expect(a['nylas.provider'], 'google');
    expect(a['nylas.grant.id'], 'g-1');
    expect(a['nylas.grant.status'], 'valid');
    expect(a['nylas.sync_state'], 'running');
    expect(a['nylas.cursor.used'], true);
  });

  test('invalid grant sets span error', () async {
    await tracedNylas<String>(
      operation: 'events.list',
      invoke: () async => const NylasCallResult(
        value: 'ok',
        result: NylasResult(provider: 'microsoft', grantStatus: 'invalid'),
      ),
    );
    expect(
      spans.findSpanByName('nylas events.list')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutNylasInstrumentationAsync(() async {
      await tracedNylas<String>(
        operation: 'events.list',
        invoke: () async => const NylasCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('nylas '), isEmpty);
  });
}
