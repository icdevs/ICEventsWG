|ICRC|Title|Author|Discussions|Status|Type|Category|Created|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|72|Minimal Event-Driven Pub-Sub Standard|Austin Fatheree (@skilesare), @ava-vs|https://github.com/dfinity/ICRC/issues/72|Draft|Standards Track||2024-04-10|



# ICRC-72: Minimal Event-Driven Pub-Sub Standard

ICRC-72, the Minimal Event-Driven Pub-Sub Standard, is designed to establish a robust framework for implementing publish-subscribe messaging patterns on the DFINITY Internet Computer. This standard facilitates the communication and synchronization of data across different canisters, enabling them to subscribe to and publish events effectively. By formalizing the interactions between publishers, subscribers, and broadcasters, ICRC-72 aims to enhance the interoperability, scalability, and efficiency of decentralized applications on the Internet Computer.

The publish-subscribe pattern, a pivotal architectural style, allows components of distributed systems to exchange information asynchronously. This pattern decouples the service provider (publisher) from the service consumers (subscribers), using an event-driven approach that promotes loose coupling and dynamic network topologies. ICRC-72 leverages these benefits to provide a standardized mechanism where canisters can subscribe to specific types of messages and react to them, without needing to poll or maintain a direct linkage to the message originators.

Key components of ICRC-72 include:
- **Publishers** who generate and send messages to broadcasters.
- **Broadcasters** who receive messages from publishers and distribute them to all registered subscribers.
- **Subscribers** who listen for messages of interest from broadcasters and process them accordingly.

This standard describes how these roles interact within the Internet Computer ecosystem, detailing the methods, data structures, and protocols necessary for establishing effective and secure communication channels. ICRC-72 also offers flexible configurations to support various messaging patterns, such as FIFO (First In, First Out), priority-based message delivery, and resilient message handling in the face of temporary canister outages.


## Data Representations

### Message Identifiers

### Data Types

```candid "Type definitions" +=

  type Account {
    owner : principal;
    subaccount: ?Blob
  };

  type Message{
    id: Nat
    //Discussion Point:or
    //publisherTimestamp: nat;
    //publisherNonce: nat;
    //maybe also broadcasterId
    timestamp: nat
    namespace: text;
    data: ICRC16;
    source: Account; // Discussion point: Do we want a sub account here for publisher directed subaccount assignment or do we want to leave that in the data and up to the implementation?
  };

  type ICRC16Property =
  {
    name : text;
    value: ICRC16;
    immutable: bool;
  };

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
    Map: vec record {
      text;
      ICRC16;
    };
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
  publishers: ?[Principal];
  //discussion point
  // dynamic: point to a service canister and method to call
  // blacklist; whitelist
  subscribers: ?[Principal];
  //discussion point
  // dynamic: point to a service canister and method to call
  // blacklist; whitelist
  mode: Nat;
  //discussion point subscription; ranked; etc; captive
};

type PublicationInfo {
  namespace: text;
  publisherCount: nat;
  messages: nat;
  messagesSent: nat;
  notifications: nat;
  notificationConfirmations: nat;
  subscriberCount: nat;
}

type PublisherInfo {
  publisher: Principal;
  publicationCount: nat;
  cyclesReceived: ?nat;
  messagesSent: nat;
  notification: nat;
  notificationsConfirmed: nat;
  subscriberCount;
};
```

## Subscription Info

``` candid "Type definitions" += 
type SubscriptionRegistration {
  namespace: Text;
  filter: ?Text; //candypath
  skip: ?nat;
  stopped: Bool;
};

type SubscriptionInfo {
  namespace: Text;
  subscriber: Principal;
  skipped: ?nat;
  skip: ?nat;
  stopped: bool;
  filter: ?Text; //candypath
  active: Bool;
  messagesReceived: nat;
  messagesRequested: nat;
  messagesConfirmed: nat;
};

type SubscriberInfo {
  subscriber: Principal;
  subscriptionCount: nat;
  cyclesPaid: ?nat;
  messagesReceived: nat;
  messagesRequested: nat;
  messagesConfirmed: nat;
};

type MessageRequest {
  namespace: Text;
  range: (nat, ?nat);
  filter: ?Text;
  skip: ?Text;
};

type MessageFulfillmentId = nat;
```



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
icrc72_get_authorized_publisher({
  namespace: text;
  prev: opt text;
  take: opt nat;
}) -> query vec principal;

icrc72_get_subscribers({
  namespace: text;
  prev: opt principal;
  take: opt nat;
}) -> query vec principal;

icrc72_get_publishers({
  namespace: text;
  prev: opt principal;
  take: opt nat;
}) -> query vec principal;

icrc72_get_broadcasters({
  namespace: text;
  prev: opt principal;
  take: opt nat;
}) -> query vec principal;

icrc72_get_publishers({
  namespace: text;
  prev: opt principal;
  take: opt nat;
}) -> query vec principal;

icrc72_get_subscribers({
  namespace: text;
  prev: opt principal;
  take: opt nat;
}) -> query vec principal;

icrc72_is_authorized_publisher(vec record {
  namespace: Text;
  princpal: princpal;
}) -> query vec[Bool];

icrc72_register_publication(vec PublicationRegistration) ->  vec[Bool];

icrc72_register_subscription(vec SubscriptionRegistration) ->  vec[Bool];

icrc72_update_publication(vec PublicationUpdate) ->  vec[Bool];

icrc72_update_subscription(vec SubscriptionUpdate) ->  vec[Bool];

icrc72_request_messages(vec MessageRequest) ->  vec[MessageFulfillmentId];

icrc72_cancel_messages_request(vec MessageFulfillmentId) ->  vec[MessageFulfillmentId];

Broadcaster Functions

icrc72_publish(vec message) : vec opt variant{
  #Ok: Nat;
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

icrc72_handle_message(vec message) : -> () //oneshot

Authorization Canisters
//discussion point: is there a generalized ICRC for whitelists/allowlists, etc

icrc72_is_authorized_publisher(vec record {
  namespace: Text;
  principal: principal;
}) -> query vec[Bool];
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
