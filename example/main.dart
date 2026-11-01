// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_nylas/otel_nylas.dart';

/// Traces Nylas v3 calls with OpenTelemetry.
///
/// `otel_nylas` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Nylas v3 call in
/// [tracedNylas]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'nylas-example');

  // Wraps a Nylas v3 API call in a CLIENT span.
  final nylasId = await tracedNylas<String>(
    operation: 'events.create',
    grantId: 'grant_8f3a2c',
    domain: 'example',
    invoke: () async {
      // Make the Nylas v3 call here, then report what it returned.
      const id = 'nylas_8f3a2c';
      return const NylasCallResult(
          value: id,
          result: NylasResult(
              itemCount: 3,
              provider: 'google',
              grantId: 'grant_8f3a2c',
              grantStatus: 'valid',
              syncState: 'running',
              usedCursor: true,
              nextCursor: 'next_cursor',
              scheduledMessageId: 'scheduledmessage_8f3a2c',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedNylas events.create returned $nylasId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutNylasInstrumentationAsync.
  await runWithoutNylasInstrumentationAsync(
    () => tracedNylas<String>(
      operation: 'events.create',
      grantId: 'grant_8f3a2c',
      domain: 'example',
      invoke: () async {
        const id = 'nylas_8f3a2c';
        return const NylasCallResult(
            value: id,
            result: NylasResult(
                itemCount: 3,
                provider: 'google',
                grantId: 'grant_8f3a2c',
                grantStatus: 'valid',
                syncState: 'running',
                usedCursor: true,
                nextCursor: 'next_cursor',
                scheduledMessageId: 'scheduledmessage_8f3a2c',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
