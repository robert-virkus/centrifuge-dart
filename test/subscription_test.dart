import 'dart:convert';

import 'package:centrifuge/centrifuge.dart';
import 'package:centrifuge/src/proto/client.pb.dart';
import 'package:centrifuge/src/subscription.dart';
import 'package:test/test.dart';

import 'src/utils.dart';

void main() {
  MockClient client;
  Subscription subscription;

  setUp(() {
    client = MockClient();
    subscription = SubscriptionImpl('test channel', client);
  });

  test('subscribe sends request and triggers success event', () async {
    final subscribeSuccess = subscription.subscribeSuccessStream.first;

    subscription.subscribe();
    final send = client.sendListLast<SubscribeRequest, SubscribeResult>();
    send.completeWith(send.result..recovered = true);

    final event = await subscribeSuccess;

    expect(event.isRecovered, isTrue);
    expect(event.isResubscribed, isFalse);
  });

  test('success subscribe triggers publish events', () async {
    final publish = subscription.publishStream.take(2).toList();

    subscription.subscribe();

    final send = client.sendListLast<SubscribeRequest, SubscribeResult>();
    send.completeWith2((result) => result
      ..publications.addAll([
        Publication()..data = utf8.encode('test message 1'),
        Publication()..data = utf8.encode('test message 2'),
      ]));

    final events = await publish;

    expect(utf8.decode(events[0].data), equals('test message 1'));
    expect(utf8.decode(events[1].data), equals('test message 2'));
  });

  test('failed subscribe triggers error events', () async {
    final errorFuture = subscription.subscribeErrorStream.first;

    subscription.subscribe();

    final send = client.sendListLast<SubscribeRequest, SubscribeResult>();
    send.completeWithError('test error');

    final error = await errorFuture;
    expect(error.message, 'test error');
  });

  test('history sends correct data', () async {
    final historyFuture = subscription.history();

    final send = client.sendListLast<HistoryRequest, HistoryResult>();

    send.completeWith2(
      (result) => result
        ..publications.addAll(
          [
            Publication()..data = utf8.encode('test history 1'),
            Publication()..data = utf8.encode('test history 2')
          ],
        ),
    );

    final events = await historyFuture;

    expect(events, hasLength(equals(2)));
    expect(utf8.decode(events[0].data), equals('test history 1'));
    expect(utf8.decode(events[1].data), equals('test history 2'));
  });
}
