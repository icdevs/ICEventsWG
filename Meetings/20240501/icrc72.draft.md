Here is the ICRC-72 Standard:

|ICRC|Title|Author|Discussions|Status|Type|Category|Created|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|72|Minimal Event-Driven Pub-Sub Standard|Austin Fatheree (@skilesare),Ilia Agafonov @ava-vs, Byron Becker@byronbecker, Ethan Celletti @gektek, Lachlan Witham, Zhenya Usenko, Matthew Harmon|https://github.com/dfinity/ICRC/issues/72|Draft|Standards Track||2024-04-10|



# ICRC-72: Minimal Event-Driven Pub-Sub Standard

ICRC-72, the Minimal Event-Driven Pub-Sub Standard, is designed to establish a robust framework for implementing publish-subscribe messaging patterns on the DFINITY Internet Computer. This standard facilitates the communication and synchronization of data across different canisters, enabling them to subscribe to and publish events effectively. By formalizing the interactions between publishers, subscribers, and broadcasters, ICRC-72 aims to enhance the interoperability, scalability, and efficiency of decentralized applications on the Internet Computer.

The publish-subscribe pattern, a pivotal architectural style, allows components of distributed systems to exchange information asynchronously. This pattern decouples the service provider (publisher) from the service consumers (subscribers), using an event-driven approach that promotes loose coupling and dynamic network topologies. ICRC-72 leverages these benefits to provide a standardized mechanism where canisters can subscribe to specific types of messages and react to them, without needing to poll or maintain a direct linkage to the message originators.

Key components of ICRC-72 include:
- **Publishers** who generate and send messages to broadcasters.
- **Broadcasters** who receive messages from publishers and distribute them to all registered subscribers.
- **Subscribers** who listen for messages of interest from broadcasters and process them accordingly.

This standard describes how these roles interact within the Internet Computer ecosystem, detailing the methods, data structures, and protocols necessary for establishing effective and secure communication channels. ICRC-72 also offers flexible configurations to support various messaging patterns, such as FIFO (First In, First Out), priority-based message delivery, and resilient message handling in the face of temporary canister outages.


## Data Representations

### Event Identifiers

1. Event identifiers MUST be represented as natural numbers with infinite precision. These numbers MAY be blob representations of more complex numbering schemes, converted to natural numbers. If an identifier is encoded, it MUST be encoded using Crockford's Base32, as specified at [Crockford's Base32](https://www.crockford.com/base32.html).

2. Events MAY specify a `prev_id` to indicate the immediately preceding message identifier known by the broadcasting system. Event systems SHOULD provide `null` in scenarios where event ordering is not critical or where ordering depends on details internal to the identifier. Event systems MAY interpret the `prev_id` based on implementation specifics, such that:

   - In Single Publisher, Single Broadcaster systems, a consistent chain of messages SHOULD be maintained with no messages being dropped.
   
   - In Single Publisher, Multi-Broadcaster systems, a consistent chain of messaging SHOULD be maintained according to nonce partitioning, with no messages being dropped.

   - In Multi Publisher, Multi-Broadcaster systems, consistent chains SHOULD be maintained across publisher-based partitions. Each partition SHOULD either remain consistent or all messages MAY be ordered, provided there is an event-specific epoch close-out schema.

### Timestamps

Timestamps represent the time on the canister that produced the event during the block the event was submitted for publishing.

### Namespaces

Events on the IC SHOULD use a namespacing pattern that ensures the event namespace does not infringe on the scope of other possible messages.  For more information see [this thread](https://forum.dfinity.org/t/proposal-to-adopt-the-namespaced-interfaces-pattern-as-a-best-practice-for-ic-developers/9262). 

For example, do not use a namespace of "transfer" as many other canisters on the IC may have similar "transfer" events and your event may become inoperable with other canisters that already consume the "transfer" event. Users SHOULD choose a namespace that they can demonstrate control over. For example if you own the domain foo.com, a good namespace would be com.foo.{application}.transfer. Future event systems MAY ask you to prove ownership of a domain that you with to create a publication for.

### Event Data

Discussion point. Do we use ICRC3 based Value or ICRC16? https://github.com/icdevs/ICEventsWG/issues/13

### Event Notification Identifiers

1. Event notification identifiers MUST be represented as natural numbers with infinite precision. These numbers MAY be blob representations of more complex numbering schemes, converted to natural numbers. If an identifier is encoded, it MUST be encoded using Crockford's Base32, as specified at [Crockford's Base32](https://www.crockford.com/base32.html).

2. Event Notification Ids will only be consistent and unique in the context of the broadcaster that related the event in the notification.

### Event Notification Source

Event Notifications include a Source that is the principal of the canister that emitted the event.

### Event Notification msg.caller

The `icrc72_handle_notification` and `icrc72_handle_notification_trusted` endpoints provide the broadcaster principal in the msg.caller variable included with the message.

### Filters

Filters SHOULD the notations provided in ICRC16 Path Standard.  Event system implementers MAY designate their own format if the previous is not sufficient.

### Publications Configs

When registering a publication, a publisher MAY provide a configuration as a `vec ICRC16Map` that contains relevant information for the event such as allow lists, disallow lists, ICRC-75 dynamic lists, publications modes, etc.  It is up to the implementation to decide which are necessary and supported.

The following items SHOULD be used for the indicated patterns:

 * `icrc72:publication:publishers:allowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:publishers:disallowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:publishers:allowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:publishers:disallowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:subscribers:allowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:subscribers:disallowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:subscribers:allowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:subscribers:disallowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);

Appendix: [Move allow and disallow to config. Move modes to config](https://github.com/icdevs/ICEventsWG/issues/18)

### Subscription Configs

When registering a subscription, a publisher MAY provide a configuration as a `vec ICRC16Map` that contains relevant information for the subscription such as skips, filters, creating stopped, etc.  It is up to the implementation to decide which are necessary and supported.

The following items SHOULD be used for the indicated patterns:

 * `icrc72:subscription:skip`: Nat; Get every Xth message
 * `icrc72:subscription:filter`: Text; The ICRC16 Path filter
 * `icrc72:subscription:stopped`: Bool; Do you want the subscription started upon registration;

### Statistics

Certain query endpoints MAY provide statistics for the requested items.

### Data Types

```candid "Type definitions" +=

  type Event{
    id: Nat
    timestamp: nat
    namespace: text;
    data: ICRC16;
  };

  Appendix: 
  [Use Principal instead of account. Maybe use derived canisterIds in the future](https://github.com/icdevs/ICEventsWG/issues/17)

  type EventRelay{
    id: Nat
    timestamp: nat
    namespace: text;
    source: principal;
    data: ICRC16;
  };

  type EventNotification{
    id: nat;
    eventId: nat;
    timestamp: nat
    namespace: text;
    data: ICRC16;
    source: Principal;
    filter: ?text;
  };

  Appendix:
  [Notification should include filter used](https://github.com/icdevs/ICEventsWG/issues/17)

  type ICRC16Property =
  {
    name : text;
    value: ICRC16;
    immutable: bool;
  };

  type ICRC16Map = record { Text; ICRC16}

  type ICRC16 =
  variant {
    Array: vec ICRC16;
    Blob: blob;
    Bool: bool;
    Bytes: vec nat8;
    Class: vec PropertyShared;
    Float: float64;
    Floats: vec float64;
    Int: int;
    Int16: int16;
    Int32: int32;
    Int64: int64;
    Int8: int8;
    Map: vec ICRC16Map;
    ValueMap: vec record {
      ICRC16;
      ICRC16;
    };
    Nat: nat;
    Nat16: nat16;
    Nat32: nat32;
    Nat64: nat64;
    Nat8: nat8;
    Nats: vec nat;
    Option: opt ICRC16;
    Principal: principal;
    Set: vec ICRC16;
    Text: text;
};
```

## Publication Info

``` candid "Type definitions" += 
type PublicationRegistration {
  namespace: Text;
  config: [ICRC16Map];
};

Appendix: [Allowed Publishers and subscribers should use the config](https://github.com/icdevs/ICEventsWG/issues/18)

type PublicationInfo {
  namespace: text;
  stats: [Map];
}
```

* `icrc72:publication:stats:publishers`- #Nat; the number of canisters registered as a publisher for this event
* `icrc72:publication:stats:events`- #Nat; the number of events that have been published
* `icrc72:publication:stats:events:sent`- #Nat; the number of events that have been completely sent
* `icrc72:publication:stats:notifications`- #Nat; the number of notifications sent
* `icrc72:publication:stats:confirmations`- #Nat;  the number confirmations received from subscribers

```
type PublisherInfo {
  publisher: principal;
  stats: [Map];
};
```

* `icrc72:publisher:stats:publications`- #Nat; the number of publications being published by the Publisher
* `icrc72:publisher:stats:cyclesReceived`- #Nat; the number of cycles sent by the system
* `icrc72:publisher:stats:events`- #Nat; the number of events the publisher has sent

```
//broken down by namespace
type PublisherPublicationInfo {
  publisher: principal;
  namespace: principal;
  stats: [Map];
};
```

* `icrc72:publisher:stats:publications`- #Nat; the number of publications being published by the Publisher
* `icrc72:publisher:stats:cyclesReceived`- #Nat; the number of cycles sent by the system
* `icrc72:publisher:stats:events`- #Nat; the number of events the publisher has sent

## Subscription Info

``` candid "Type definitions" += 
type SubscriptionRegistration {
  namespace: Text;
  config: [ICRC16Map];
  filter: ?Text; 
  skip: ?nat;
  stopped: Bool;
};
```

 * `icrc72:subscription:filter`: #Text; ICRC16Path
 * `icrc72:subscription:skip`: #Nat; Skip every X number of items; for throttling
 * `icrc72:subscription:stopped`: #Blob; Start mode;

```
type SubscriberInfo {
  subscriber: Principal;
  stats: [Map];
};
```
* `icrc72:subscriber:stats:subscriptions`- #Nat; the number of subscriptions the subscriber has registered.
* `icrc72:subscriber:stats:subscriptions:active`- #Nat; the number of subscriptions the subscriber has registered and active.
* `icrc72:subscriber:stats:notifications`- #Nat; the number of notifications the subscriber has been sent
* `icrc72:subscriber:stats:confirmations`- #Nat; the number of confirmations the subscriber has sent
* `icrc72:subscriber:stats:cyclesPaid`- #Nat; the number of cycles the subscriber has paid upon confirmation
* `icrc76:subscriber:stats:requests`- #Nat; the number of message requests the subscriber has sent

```

type SubscriptionInfo {
  subscriber: principal;
  namespace: text;
  config: vec ICRC16Map
  stats: vec ICRC16Map;
};

```

* `icrc72:subscription:stats:notifications`- #Nat; the number of notifications sent to the subscription
* `icrc72:subscription:stats:confirmations`- #Nat; the number of confirmations subscription has sent.
* `icrc72:subscription:stats:notifications`- #Nat; the number of notifications sent
* `icrc72:subscription:stats:confirmations`- #Nat;  the number confirmations received from subscribers
* `icrc72:subscription:stats:cyclesPaid`- #Nat; the number of cycles the subscriber has paid upon confirmation
* `icrc76:subscription:stats:requests`- #Nat; the number of message requests the subscriber has sent


## Ingress methods

{Generally pub/sub should be ONLY intercanister methods. If you want to publish an event message, have a call to another method and emit the event.}

### Methods

Admin Methods

- register a publication
- register a subscription
- return publication statistics
- return subscription statistics

Subscription Methods:

- Start Subscription
- Stop Subscription
- Request Missed messages
- Cancel Request Missed messages stream

BroadcastMethods
- Receive a messages
- Receive a message receipt confirmation and accept cycles
- Store a message in the stream DB
- Scale if busy
- Scale down if not busy

Publication Methods:

- Ask to publish an event
- Publish an Event

Possible methods:

Admin Function

```

// Returns the publishers known to the admin canister
icrc72_get_publishers({
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec PublisherInfo;

//get publications known to the admin canister
icrc72_get_publications({
  prev: opt text;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec PublicationInfo;

//get publications known to the admin canister
icrc72_get_publication_publishers({
  namespace: text;
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec PublisherPublicationInfo;


// Returns the subscribers known to the admin canister
icrc72_get_subscribers({
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec SubscriberInfo;

icrc72_get_subscriptions({
  namespace: text;
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec principal;


icrc72_get_broadcasters({
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec BroadcasterInfo;

icrc72_get_publication_broadcasters({
  namespace: text;
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec BroadcasterInfo;

icrc72_get_broadcaster_subscriptions({
  prev: opt principal;
  take: opt nat;
  statsFilter: ??(vec map);
}) -> query vec SubscriptionInfo;

icrc72_register_publication(vec PublicationRegistration) ->  vec[Bool];

icrc72_register_subscription(vec SubscriptionRegistration) ->  vec[Bool];

icrc72_update_publication(vec PublicationUpdate) ->  vec[Bool];

icrc72_update_subscription(vec SubscriptionUpdate) ->  vec[Bool];


Broadcaster Functions

icrc72_publish(vec Eve nt) : vec opt variant{
  #Ok: vec Nat;
  #Err: PublishError;
};

icrc72_publish_relay(vec EventRelay) : vec opt variant{
  #Ok: vec Nat;
  #Err: PublishError;
};

icrc72_confirm_messages(vec nat) -> variant{
  allAccepted;
  itemized: vec opt variant {
    #Ok; //discussion point: cycles charged?
    #Err: ConfirmationError;
  };
}
//discussion : able to return more info? deficit in cycles, costs, etc

Subscriber functions

icrc72_handle_notification(vec message) : -> () //oneshot

icrc72_handle_notification_trusted(vec message) : -> variant{
  //discussion point https://github.com/icdevs/ICEventsWG/issues/2#issuecomment-2054079257
  #Ok: Value
  #err: Text;
};

Appendix: (Add a trusted endpoint for smaller implementations)[https://github.com/icdevs/ICEventsWG/issues/14]


```

### Queries

### Generally-Applicable Specification

Please see the ICRC-7 specifications for the Generally-Applicable Specifications as those items apply here as well:

- Batch Update Methods
- Batch Query Methods
- Error Handling

## ICRC-72 Block Schema

## Extensions


## Transaction Deduplication

See notes on ICRC-7

## Security Considerations

This section highlights some selected areas crucial for security regarding the implementation of ledgers following this standard and Web applications using ledgers following this standard. Note that this is not exhaustive by any means, but rather points out a few selected important areas.

### Protection Against Denial of Service Attacks

See notes on ICRC-7

### Protection Against Web Application Attacks

See notes on ICRC-7


-----------------------

ICRC-77 Event Message Replay Interface

```

type MessageRequest {
  namespace: Text;
  range: (nat, ?nat);
  filter: ?Text;
  skip: ?Text;
};

type MessageFulfillmentId = nat;



icrc77_request_messages(vec MessageRequest) ->  vec[MessageFulfillmentId];
icrc77_cancel_messages_request(vec MessageFulfillmentId) ->  vec[MessageFulfillmentId];

```



---------------
ICRC-75 Allow List standard

Authorization Canisters
//discussion point: is there a generalized ICRC for whitelists/allowlists, etc

icrc72_is_authorized_publisher(vec record {
  namespace: Text;
  principal: principal;
}) -> query vec[Bool];
