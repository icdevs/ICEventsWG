|ICRC|Title|Author|Discussions|Status|Type|Category|Created|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|72|Minimal Event-Driven Pub-Sub Standard|Austin Fatheree (@skilesare),Ilia Agafonov @ava-vs, Byron Becker @byronbecker, Ethan Celletti @gekctek, Lachlan Witham, Zhenya Usenko, Matthew Harmon|https://github.com/dfinity/ICRC/issues/72|Draft|Standards Track|Protocols|2024-09-24|

# ICRC-72: Minimal Event-Driven Pub-Sub Standard

ICRC-72, the Minimal Event-Driven Pub-Sub Standard, is designed to establish a robust framework for implementing publish-subscribe messaging patterns on the Internet Computer. This standard facilitates the communication and synchronization of data across different canisters, enabling them to subscribe to and publish events effectively. By formalizing the interactions between Publishers, Subscribers, and Broadcasters, ICRC-72 aims to enhance the interoperability, scalability, and efficiency of decentralized applications on the Internet Computer.

The publish-subscribe pattern, a pivotal architectural style, allows components of distributed systems to exchange information asynchronously. This pattern decouples the service provider (Publisher) from the service consumers (Subscribers), using an event-driven approach that promotes loose coupling and dynamic network topologies. ICRC-72 leverages these benefits to provide a standardized mechanism where canisters can subscribe to specific types of messages and react to them, without needing to poll or maintain a direct linkage to the message originators.

Key components of ICRC-72 include:
- **Publishers** who generate and send messages to Broadcasters.
- **Broadcasters** who receive messages from Publishers and distribute them to all registered Subscribers. When a Broadcaster sends an event notification to a broadcaster on a different subnet it is referred to as an **Event Relayer**.
- **Subscribers** who listen for messages of interest from Broadcasters and process them accordingly.
- **Orchestrator** who manages network topography, subscriptions, publications, and assignments.

This standard describes how these roles interact within the Internet Computer ecosystem, detailing the methods, data structures, and protocols necessary for establishing effective and secure communication channels. ICRC-72 also offers flexible configurations to support various messaging patterns, such as FIFO (First In, First Out), priority-based message delivery, and resilient message handling in the face of temporary canister outages.

## Data Representations

### Event Data Types

#### Namespaces

```candid "Type definitions" +=
type Namespace : text;
```

Events on the IC SHOULD use a namespacing pattern that ensures the event namespace does not infringe on the scope of other possible messages.  For more information see [this thread](https://forum.dfinity.org/t/proposal-to-adopt-the-namespaced-interfaces-pattern-as-a-best-practice-for-ic-developers/9262). 

For example, do not use a namespace of "transfer" as many other canisters on the IC may have similar "transfer" events and your event may become inoperable with other canisters that already consume the "transfer" event. Users SHOULD choose a namespace that they can demonstrate control over. For example, if you own the domain foo.com, a good namespace would be com.foo.{application}.transfer. Future event systems MAY ask you to prove ownership of a domain that you with to create a publication for.

The use of namespaces with wildcards and filters can significantly enhance the usability and effectiveness of subscription systems. This approach offers users the ability to finely adjust event monitoring, providing both precision and adaptability in dynamic information environments. For instance, namespaces can be structured using wildcards such as *.category.* or *.topic.*, allowing for broad or specific event categorization. Filters can then be applied to further refine subscriptions, such as category: [sports, technology] or topic: [finance, marketing], enabling users to tailor their subscriptions to their specific interests and needs.

**Domains vs. Namespaces**

We have deliberately made a decision to keep namespaces as generic as possible so that implementers of ICRC-72 are free to implement the namespace formatting and restrictions of their choice. 

Example implementations:

An implementer may choose to restrict namespaces to a subset of names such as "domain" which would need to follow a set of rules ensuring proper management and ownership of unique domains. ie "com.foo.bar.events.x".

The underlying standard does assume that namespaces of the form "icrcXX:YYYYY" are typically reserved for use by ICRC-72 and its extensions for use in exchange system-level messages.

Appendix - [Discussion about namespacing and wildcards for subscriptions](https://github.com/icdevs/ICEventsWG/issues/33)

#### Event

Events are published from Publishers by being sent to Broadcasters.

```candid "Type definitions" +=

  type Event = {
    eventId: EventIdentifier;
    prevEventId: opt EventIdentifier;
    timestamp: Timestamp
    namespace: Namespace;
    data: ICRC16;
    source: principal;
    headers: opt EventHeaders
  };
```

- **eventId** (`nat`): A unique identifier for the event, allowing for distinct referencing across an event namespace.
- **prevEventId** (`opt nat`): A unique identifier for the previous event if applicable.
- **timestamp** (`nat`): The Unix epoch timestamp in nanos denoting when the event occurred.
- **namespace** (`text`): A textual descriptor that categorizes the event into a domain-specific context for easier management and filtering.
- **data** (`ICRC16`): The payload of the event, conforms to the ICRC-16 data standard which provides a versatile structure to accommodate various data formats.
- **headers** (`opt ICRC16Map`): Data annotation and statistics about the event that may be relevant to intermediate or receiving parties.

```motoko
// An event structure being published
let event = {
  eventId = 123456789;
  prevEventId = 123456788;
  timestamp= 1672525600000000000;  // Example timestamp in nanoseconds
  namespace = "com.example.myapp.events";
  data: #Map([
    ("com.example.myapp.event.host", #Text("John Smith")),
    ("com.example.mayapp.event.date", #Nat(1672525600000000000)),
  ]);
  headers: ?#Map([("content-type", #Text("ICRC16"))])
};
```

### Event Identifiers

```candid "Type definitions" +=
type EventIdentifier = nat;
```

1. Event identifiers MUST be represented as natural numbers with infinite precision. These MAY be blob representations of more complex numbering schemes, converted to natural numbers. If an identifier is encoded, it MUST be encoded using Crockford's Base32, as specified at [Crockford's Base32](https://www.crockford.com/base32.html).

2. Event identifiers MUST be unique for a specific event namespace.

3. Events MAY specify a `prevEventId` to indicate the immediately preceding message identifier known by the broadcasting system. Event systems SHOULD provide `null` in scenarios where event ordering is not critical or where ordering depends on details internal to the identifier. Event systems MAY interpret the `prevId` based on implementation specifics, such that:

   - In Single Publisher, Single Broadcaster systems, a consistent chain of messages SHOULD be maintained with no messages being dropped.
   
   - In Single Publisher, Multi-Broadcaster systems, a consistent chain of messaging SHOULD be maintained according to nonce partitioning, with no messages being dropped.

   - In Multi Publisher, Multi-Broadcaster systems, consistent chains SHOULD be maintained across Publisher-based partitions. Each partition SHOULD either remain consistent or all messages MAY be ordered, provided there is an event-specific epoch close-out schema.

#### Timestamps

```candid "Type definitions" +=
type Timestamp = nat;
```

Timestamps represent the time on the canister that produced the event during the block the event was submitted for publishing. They are represented as Natural numbers and are UTC Nanoseconds.

### EventNotification

Subscribers receive event notifications from Broadcasters.

```candid "Type definitions" +=
  type EventNotification = {
    notificationId: EventNotificationId;
    eventId: nat;
    prevEventId: opt nat;
    timestamp: nat
    namespace: text;
    data: ICRC16;
    headers: opt EventHeaders
    source: Principal;
    filter: opt text;
  };
```

- **notificationId** (`nat`): Unique identifier for the event notification.
- **eventId** (`nat`): The identifier of the original event that triggered this notification.
- **eventPrevId** (`opt nat`): A unique identifier for the previous event if applicable.
- **timestamp** (`nat`): Time at which the notification was generated, in Unix epoch format, nanoseconds.
- **namespace** (`text`): The namespace of the event, serves as a categorization tool to differentiate events.
- **data** (`ICRC16`): Data associated with the event, encoded according to ICRC-16 specifications.
- **headers** (`opt ICRC16Map`): Data annotation and statistics about the event that may be relevant to intermediate or receiving parties.
- **source** (`Principal`): The principal ID of the canister that dispatched the event.
- **filter** (`opt text`): Optional text filter that was used to filter a positive match for this event.

#### Event Notification Identifiers

```candid "Type definitions" +=
type EventNotificationId = nat;
```

1. Event notification identifiers MUST be represented as natural numbers with infinite precision. These numbers MAY be blob representations of more complex numbering schemes, converted to natural numbers. If an identifier is encoded, it MUST be encoded using Crockford's Base32, as specified at [Crockford's Base32](https://www.crockford.com/base32.html).

2. Event Notification IDs will only be consistent and unique in the context of the Broadcaster that is related to the event in the notification.

#### Event Notification Source

Event Notifications include a Source that is the principal of the canister that emitted the event.

#### Event Notification msg.caller

The `icrc72_handle_notification` and `icrc72_handle_notification_trusted` endpoints provide the Broadcaster principal in the msg.caller variable included with the message.  `id` and `prevId` of an event are converted to `eventId` and `prevEventId` in the outgoing notifications.

`icrc72_handle_notification_trusted` may be used in event systems where the Publisher or Broadcaster trusts all possible Subscribers such that there is no risk of a Subscriber rendering the calling canister un-upgradable by withholding a response.

```motoko
// An event structure being published
let eventNotification = {
  notificationId = 987654321;
  eventId = 123456789;
  eventPrevId = 123456788;
  timestamp= 1672525600000000000;  // Example timestamp in nanoseconds
  namespace = "com.example.myapp.events";
  data = #Map([
    ("com.example.mayapp.event.host", #Text("John Smith")),
    ("com.example.mayapp.event.date", #Nat(1672525600000000000)),
  ]);
  headers = ?#Map([("content-type", #Text("ICRC16"))]);
  source = Principal.fromText("aaaaa-aa")
};
```


Appendix: 
  [Use Principal instead of account. Maybe use derived canisterIds in the future](https://github.com/icdevs/ICEventsWG/issues/17)

 Appendix:
  [Notification should include filter used](https://github.com/icdevs/ICEventsWG/issues/17)

#### Event Headers

```candid "Type definitions" +=
type EventHeader = ICRC16MapItem;

type EventHeaders = ICRC16Map;
```

Events also have an optional `headers` property that, if provided should be an ICRC16Map.  This collection allows for the emitter to provide additional data that is not directly relevant for ICRC-72 completeness, but that may be important for validation or measurement of the event.  As the event travels from the Publisher, through a Broadcaster, an Event Relayer, and ultimately to a Subscriber, the network participants may add headers to this collection.

For the purposes of this standard, the following headers are established:

- `icrc72:eventData:hash` - a #Blob containing the representational independent hash of the event. See: https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-3/HASHINGVALUES.md
- `icrc72:broadcaster:received` - a #Nat the timestamp that the Broadcaster received the event.
- `icrc72:broadcaster:priority` - a #Array of #Nat where the first item is the position in priority and the second item is the total Subscriber count.
- `icrc72:relay:sent` - a #Nat the timestamp that the Broadcaster sent the event to a relay.
- `icrc72:relay:received` - a #Nat the timestamp that the relay received the event.
- `icrc72:broadcaster:sent` - a #Nat the timestamp that the Broadcaster sent the event.

#### Event Data

Event data is represented using ICRC-16 generic typing variants.  Implementations that wish to use only the `Value` subset of ICRC-16 that is found in ICRC-3 MAY do so as ICRC-16 is a super type of that type.

```candid "Type definitions" +=
// Generic value in accordance with ICRC-3

type ICRC16MapItem = record { Text; ICRC16};

type ICRC16ValueMapItem = record { ICRC16; ICRC16}

type ICRC16Map = vec ICRC16MapItem;

type ICRC16Property = record {
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
    Class: vec ICRC16Property;
    Float: float64;
    Floats: vec float64;
    Int: int;
    Int16: int16;
    Int32: int32;
    Int64: int64;
    Int8: int8;
    Map: ICRC16Map;
    ValueMap: vec ICRC16ValueMapItem;
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

Event Broadcaster Canisters MUST NOT manipulate the `data` field.  Any data annotations should be done in the `headers` collection and must be append-only such that no headers are overwritten or changed.

While event publishers can use CBOR or other binary encodings to send data, we encourage the use of candid as a lingua franca of the Internet Computer.

### Publication Data Types

#### PublicationRegistration

Publication Registrations should be sent from a Publisher to the Orchestrator to indicate the desire to publish a particular event.  

- **namespace** (`Text`): Defines the topic or category of the events that a Publisher can publish under.
- **config** (`[ICRC16Map]`): Configuration details specific to the publication, catering to customization and control mechanisms like access lists or publication rules. [See Publication Configs](#publication-configs)

```motoko
// Register a new event publication with specific configurations
let publicationRegistration = {
  namespace: "com.example.myapp.events";
  config: [
    ("icrc72:publication:publishers:allowed:list", #Array([#Blob(Principal.toBlob("aaaaa-aa")])),
    ("icrc72:publication:mode", #Text("fifo"))
  ];
  memo: ?Text.toUtf8("Initial registration of MyApp events")
};
```

#### PublicationInfo

Represents a particular publication namespace and any statistics about that publication.

- **namespace** (`text`): Identifier for the category or domain of publication.
- **stats** (`ICRC16Map`): Statistical data relevant to the publication, possibly including metrics like the number of Subscribers, total events published, etc.

#### PublisherInfo

Represents a particular Publisher namespace and any statistics about that publication.

- **publisher** (`principal`): Principal ID of the Publisher.
- **stats** (`ICRC16Map`): Contains statistical data concerning the Publisher, such as number of publications, event counts, etc.

#### PublisherPublicationInfo

Represents a particular publication namespace, Publisher tuple and any statistics about that pair.

- **publisher** (`principal`): The identifier of the Publisher.
- **namespace** (`principal`): The namespace associated with specific publications by the Publisher.
- **stats** (`ICRC16Map`): Detailed metrics related to publications in the specified namespace by the Publisher.

``` candid "Type definitions" += 

type PublicationIdentifier = variant {
  namespace: text;
  publicationId: nat;
};

type PublicationRegistration = record {
  namespace: text;
  config: ICRC16Map;
  memo: blob;
};

type PublicationInfo = record {
  namespace: text;
  publicationId: nat;
  config: ICRC16Map;
  stats: ICRC16Map;
}

type PublicationUpdate = record {
    publication : PublicationIdentifier;
    config : (Text, ICRC16);
    memo: blob;
};

type PublisherInfo = record {
  publisher: principal;
  stats: ICRC16Map;
};

//broken down by namespace
type PublisherPublicationInfo = record {
  publisher: principal;
  namespace: text;
  publicationId: nat;
  config: ICRC16Map;
  stats: ICRC16Map;
};
```

Appendix: [Allowed Publishers and Subscribers should use the config](https://github.com/icdevs/ICEventsWG/issues/18)

Appendix: [Memo and created at time discussion](https://github.com/icdevs/ICEventsWG/issues/35)

#### Publications Configs

When registering a publication, a Publisher MAY provide a configuration as an `ICRC16Map` that contains relevant information for the event such as allow lists, disallow lists, ICRC-75 dynamic lists, publications modes, etc.  It is up to the implementation to decide which are necessary and supported.

The following items SHOULD be used for the indicated patterns:

 * `icrc72:publication:publishers:allowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:publishers:disallowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:publishers:allowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:publishers:disallowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:subscribers:allowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:subscribers:disallowed:list`: Array([#Blob(PrincipalAsBlob])
 * `icrc72:publication:subscribers:allowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:subscribers:disallowed:icrc75`: Array([#Blob(CanisterIDAsBlob), #Text("namespace")]);
 * `icrc72:publication:controllers:add` : Array([#Blob(PrincipalAsBlob]);
 * `icrc72:publication:controllers:remove` : Array([#Blob(PrincipalAsBlob]);

Appendix: [Move allow and disallow to config. Move modes to config](https://github.com/icdevs/ICEventsWG/issues/18)

**Batch Note** - If the client needs more granular control of atomicity they may submit config changes one at a time and react appropriately to failures.  Implementors MAY implement their own transactional system, but it is not required.  Implementors MAY restrict config changes to accept only one item at a time.

### Subscription Data Types

#### Subscription Registration Namespaces

Implementations MAY support wildcards for subscriptions.  For example, a subscription to `*.icrc1.transfer` might register a Subscriber to any events that produce a standard icrc1.transfer event regardless of the canister that emitted it.  The subscription canister must take technical limitations into account when making these subscriptions as the canister may overload itself. The wild-card language that is used is purposely left out of this standard and must be defined by the implementation of the events system.

### Filters

```candid "Type definitions" += 
type Filter = Text;
```

Filters SHOULD the notations provided in ICRC16 Path Standard.  Event system implementers MAY designate their own format if the previous is not sufficient.

#### Filtering records

A Subscriber MAY provide a filter in textual representation to filter out certain records for the subscription in the config. Implementations SHOULD continue to develop CandyPath that can filter through ICRC-16 values, but the implementation MAY use a text query language of their own choosing.

#### Skipping records

A Subscriber MAY provide a skip config to ask the canister to skip broadcasting for either bandwidth or distribution reasons.   The skip parameter is a tuple of the mod and optional offset `Array[Nat, opt Nat]`.  If the mod is set then the Subscriber should only receive a message if the mod of the value provided is 0.  This can be offset for partitioning by using the optional partition variable.  By using this pattern a Subscriber set can ensure that all messages make it to a set of Subscribers with a distributed message set. 

#### SubscriptionRegistration

Sent by a Subscriber to an Orchestrator to register the desire to start listening to a publication.

- **namespace** (`Text`): Defines the topic or category that the Subscriber is interested in.
- **config** (`ICRC16Map`): Configuration for the subscription, including elements like message filters or skip patterns. [See Subscription Configs](#subscription-configs)
- **memo** (`opt Blob`): A 32 Byte memo. Optional.

```candid
// Register a new event publication with specific configurations
let subscriptionRegistration = record {
  namespace: "com.example.myapp.events";
  config: [
    ("icrc72:subscription:skip", #Array([#Nat(5),#Nat(1)])),
    ("icrc72:subscription:filter", #Text("host[name ~= John]"))
  ];
  memo: opt Text.toUtf8("Initial subscription of MyApp events")
};
```

#### SubscriptionInfo

Sent by a Subscriber to an Orchestrator to register the desire to start listening to a publication.

- **subscriptionId** (`Nat`): The ID of a registered Subscription.
- **namespace** (`Text`): Defines the topic or category that the Subscriber is interested in.
- **config** (`ICRC16Map`): Configuration for the subscription, including elements like message filters or skip patterns. [See Subscription Configs](#cubscription-configs)
- **stats** (`ICRC16Map`): Statistical information regarding the Subscriber's activity, such as number of messages received, active subscriptions, etc.


#### SubscriberInfo

Represents data about a particular Subscriber and their statistics.

- **subscriber** (`Principal`): The principal ID of the Subscriber.
- **stats** (`ICRC16Map`): Statistical information regarding the Subscriber's activity, such as number of messages received, active subscriptions, etc.

#### SubscriberSubscriptionInfo

Represents data about a subscription and its statistics.

- **subscriber** (`principal`): The principal ID of the entity subscribed to the events.
- **namespace** (`text`): The namespace pertaining to the subscribed events.
- **config** (`ICRC16Map`): Configuration settings specific to the Subscriber, which may include filters and skip details.[See Subscription Configs](#subscription-configs)
- **stats** (`ICRC16Map`): Vector of key-value pairs capturing statistical data about the subscription.

#### SubscriptionUpdate

- **subscription** (`variant{id: nat; namespace: text;};`): Identifier of the subscription to be updated.
- **config** (`ICRC16Map`): Optional new configuration settings to replace or update the existing subscription configurations.
- **memo** (opt blob): optional memo for record-keeping
- **subscriber** (opt principal) : optional Subscriber record to change.  Controllers can change anyone, Subscribers can controllers themselves

``` candid "Type definitions" +=

  type SubscriptionIdentifier = nat;

   type SubscriptionRegistration = record {
     namespace: text;
     config: ICRC16Map;
     memo: blob
   };

 type SubscriptionIdentifier = variant{
    namespace: text;
    subscriptionId: nat;
  };


type SubscriberSubscriptionInfo = record {
  subscriptionId : SubscriptionIdentifier;
  subscriber: principal;
  config: ICRC16Map;
  stats: ICRC16Map;
};


type SubscriptionInfo = record {
  subscriptionId: SubscriptionIdentifier;
  namespace: text;
  config: ICRC16Map;
  stats: ICRC16Map;
};

type SubscriberInfo = record {
  subscriber: principal;
  stats: ICRC16Map;
};

type SubscriptionUpdate = record {
    subscription : variant {
        id: SubscriptionIdentifier;
        namespace: text;
    };
    config : (Text, ICRC16);
    memo: blob;
};

type SubscriptionDelete = record {
    subscription : variant {
        id: SubscriptionIdentifier;
        namespace: text;
    };
    memo: blob;
};

type PublicationDelete = record {
    publication : variant {
        id: SubscriptionIdentifier;
        namespace: text;
    };
    memo: blob;
};
```

#### Subscription Configs

When registering a subscription, a Publisher MAY provide a configuration as an `ICRC16Map` that contains relevant information for the subscription such as skips, filters, creating stopped, etc.  It is up to the implementation to decide which are necessary and supported.

The following items SHOULD be used for the indicated patterns:

 * `icrc72:subscription:skip`: Array[Nat, Nat]; Get every Xth message with an optional offset.
 * `icrc72:subscription:filter`: Text; The ICRC16 Path filter
 * `icrc72:subscription:stopped`: Bool; Do you want the subscription started upon registration;
 * `icrc72:subscription:controllers:add` : Array([#Blob(PrincipalAsBlob]); Controllers are only relevant for multi-canister round-robin subscriptions where you need an array of handlers.
 * `icrc72:subscription:controllers:remove` : Array([#Blob(PrincipalAsBlob]);

**Batch Note** - If the client needs more granular control of atomicity they may submit config changes one at a time and react appropriately to failures.  Implementors MAY implement their own transactional system, but it is not required.  Implementors MAY restrict config changes to accept only one item at a time.

### Statistics

For statistics please see ICRC-92.

## Recommended Implementation Approaches

The ICRC-72 standard accommodates three primary usage scenarios, each suited for different situations and system scales. Below are recommendations for each approach:

### 1. Direct Inter-Canister Messaging

**Use Case:** When the Publisher knows the list of Subscribers and direct interaction between canisters is required.

**Required Implementations:**
- Publisher: Method for sending events directly to Subscribers
- Subscriber: `icrc72_handle_notification` method for receiving messages

**Recommended Implementations:**
- Methods for subscription and unsubscription, if dynamic Subscriber list management is needed

**Advantages:**
- Simple implementation
- Low latency
- Direct control over communication

**Limitations:**
- Limited scalability
- Requires Subscriber list management on the Publisher side

### 2. Messaging via Broadcaster

**Use Case:** When Publishers and Subscribers are unaware of each other and are linked only through a namespace.

**Required Implementations:**
- Publisher: `icrc72_publish` method for sending events to the Broadcaster
- Subscriber: `icrc72_handle_notification` method for receiving messages from the Broadcaster
- Broadcaster: Methods for receiving events from Publishers and distributing to Subscribers

**Recommended Implementations:**
- Methods for registering publications and subscriptions
- Event filtering mechanisms on the Broadcaster side

**Advantages:**
- Improved scalability
- Independence of Publishers and Subscribers
- Ability to dynamically add new participants

**Limitations:**
- Additional latency due to the intermediate component (Broadcaster)
- Requires implementation and maintenance of a Broadcaster

### 3. Communication via Orchestrator

**Use Case:** For large-scale systems spanning multiple subnets, with multiple Broadcasters.

**Required Implementations:**
- All components from Scenario 2
- Orchestrator: Methods for managing publications, subscriptions, and Broadcaster assignments
- Publishers and Subscribers: Methods for interacting with the orchestrator

**Recommended Implementations:**
- Load balancing mechanisms between Broadcasters
- Monitoring and reporting systems

**Advantages:**
- High scalability
- Ability to distribute load across subnets
- Centralized management of the event system

**Limitations:**
- Most complex implementation
- Potentially higher latency
- Requires additional resources to support the orchestrator

The choice of approach depends on your system's scale, performance requirements, and the complexity of interactions between components. It's recommended to start with simpler implementations and gradually move to more complex ones as system needs grow.

## Ingress methods

Generally, pub/sub should be ONLY inter-canister methods. If you want to publish an event message, have a call to another method and emit the event.

## Methods

### Orchestrator

#### Orchestrator Update Methods

1. **icrc72_register_publication**: This method registers one or more new publications based on provided details in `PublicationRegistration` structures. It returns a list of results, each indicating successful registration with a unique identifier or an error if the registration failed.

2. **icrc72_register_subscription**: Analogous to publication registration, this method registers one or more new subscriptions as described in the `SubscriptionRegistration` structures. Each subscription registration attempts are returned in the resulting list, indicating either successful registration with an identifier or an error.

3. **icrc72_update_publication**: This method takes a vector of `PublicationUpdateRequest` records and returns a vector of optional `UpdatePublicationResult`. It is used to apply changes to registered publications such as updating configuration or namespace details. Each element in the input corresponds to a publication update action, and the method provides corresponding results for each action in the output.
   
4. **icrc72_update_subscription**: Similar to publication updates, this method accepts a vector of `SubscriptionUpdate` records for updating existing subscriptions. The outputs are encapsulated in a vector of optional `UpdateSubscriptionResult`, detailing the success or error of each subscription update action. This allows Subscribers to modify aspects of their subscriptions like filters, skips, or activation status.

5. **icrc72_delete_subscription**: Delete a subscription. The canister should stop receiving events from the broadcaster once this request has diffused through the event system. The canister MAY continue to receive events if that takes some time.
   
6. **icrc72_delete_publication**:  Delete a publication. The publication will be removed from the orchestrator and broadcasters. Once the status has diffused through the system the Broadcaster SHOULD no longer accept events or notification confirmations for that event. 

```candid "Type definitions" +=

type GenericError = record {
  error_code: Nat;
  message: Text;
}

type PublicationRegisterError = variant {
  Unauthorized; //generally unauthorized
  UnauthorizedPublisher : {
    namespace: Namespace; //The Publisher is not allowed, Look up config by message: Text;
  };
  ImproperConfig: Text; //maybe implementation specific
  GenericError: GenericError;
  GenericBatchError : Text;
};

type PublicationDeleteError = variant {
  Unauthorized; //generally unauthorized
  GenericError: GenericError;
  GenericBatchError : Text;
};

type SubscriptionDeleteError = variant {
  Unauthorized; //generally unauthorized
  GenericError: GenericError;
  GenericBatchError : Text;
};


type SubscriptionRegisterError = variant {
  Unauthorized; //generally unauthorized
  UnauthorizedSubscriber: {
    namespace: Namespace; //The Publisher is not allowed, Look up config by message: Text;
  };
  ImproperConfig: Text;  //maybe implementation specific
  GenericError: GenericError;
  GenericBatchError : Text;
};

type PublicationRegisterResult = opt variant {
  Ok: nat;
  Err: PublicationRegisterError;
};

type SubscriptionRegisterResult = opt variant {
  Ok: nat;
  Err: SubscriptionRegisterError;
};

type PublicationUpdateResult = opt variant {
  Ok: bool;
  Err: PublicationRegisterError;
};

type SubscriptionUpdateResult = opt variant {
  Ok: bool;
  Err: SubscriptionRegisterError;
};

```

```candid "Methods" +=
// Register new publications with configurations provided by the caller.
// Returns a vector of results, which may contain either an ID of the registered publication or an error.
icrc72_register_publication : (vec PublicationRegistration) -> (vec PublicationRegisterResult);

// Register new subscriptions with configurations provided by the caller.
// Returns a vector of results, which may contain either an ID of the registered subscription or an error.
icrc72_register_subscription : (vec SubscriptionRegistration) -> (vec SubscriptionRegisterResult);

// Update existing publications based on provided configurations.
// Returns a vector of results, indicating success or providing an error detail for each publication update.
icrc72_update_publication : (vec PublicationUpdate) -> (vec PublicationUpdateResult);

// Update existing subscriptions based on provided configurations.
// Returns a vector of results, indicating success or providing an error detail for each subscription update.
icrc72_update_subscription : (vec SubscriptionUpdate) -> (vec SubscriptionUpdateResult);

// Delete existing subscriptions.
// Returns a vector of results, indicating success or providing an error detail for each subscription deletion.
icrc72_delete_subscription : (vec SubscriptionDelete) -> (vec SubscriptionDeleteResult);

// Delete existing publication.
// Returns a vector of results, indicating success or providing an error detail for each subscription update.
icrc72_delete_publication : (vec PublicationDelete) -> (vec PublicationDeleteResult);
```

### Orchestrator Query Methods

These methods facilitate the orchestration and supervision of the publish/subscribe system’s state without altering any data.

#### icrc72_get_valid_broadcasters

Retrieves details about which Broadcasters a Subscriber should allow notifications from. This is an update call because it may need to check the subnet of the caller as well as because we want it to go through consensus since it has to do with security.

- **Parameters**:
  none

- **Returns**:
  - A variant of `list` which is a  `vec principals` which the Subscriber should accept notifications from.
  - or variant `icrc75` which is an `ICRC75Item` that points to a canister and namespace that contains the valid Broadcasters

#### icrc72_get_publishers

Retrieves a paginated list of Publishers known to the Orchestrator. Filtering based on provided statistical filters is possible.

- **Parameters**:
  - `prev : opt nat`: Optional. The principal of the last Publisher in the previous query to establish pagination context.
  - `take : opt nat`: Optional. Maximum number of Publisher entries to return.
  - `filter : opt OrchestrationFilter`: Optional. Filters for fetching specific slices and statistical data.

- **Returns**:
  - A list of `PublisherInfo` which contains structured information about each known Publisher including statistical data.

#### icrc72_get_publications

Fetches information about registered publications in a paginated format, optionally filtered by statistical metrics.

- **Parameters**:
  - `prev : opt nat`: Optional. The namespace of the last publication fetched which helps in pagination.
  - `take : opt nat`: Optional. The number of publication entries to return.
  - `filter: opt OrchestrationFilter`: Optional. Filters for fetching slices and statistical data retrieval for each publication.

- **Returns**:
  - A list of `PublicationInfo` detailing each publication’s namespace and associated statistics.

#### icrc72_get_subscribers

Retrieves a list of all Subscribers known to the Orchestrator, and supports pagination and statistical filtering.

- **Parameters**:
  - `prev : opt nat`: Optional. The principal of the last Subscriber in the last fetched list for pagination.
  - `take : opt nat`: Optional. The maximum number of Subscriber entries to return.
  - `filter : opt OrchestrationFilter`: Optional. Statistical filters to narrow down the data retrieval.

- **Returns**:
  - A list of `SubscriberInfo` providing detailed information on each Subscriber including their activity statistics.

#### icrc72_get_subscriptions

Fetches details about subscriptions to a specific publication namespace, including optional statistical filtering.

- **Parameters**:
  - `prev`: Optional. Principal of the last Subscriber in the previous fetch to continue pagination.
  - `take`: Optional. Number of subscription entries to return.
  - `filter`: Optional. Filters for retrieving specific statistical data.

- **Returns**:
  - A list of `SubscriptionInfo` offering detailed data on subscriptions to the specified namespace and their statistics.

#### icrc72_get_broadcasters

Returns a list of all Broadcasters known to the system, and supports pagination and statistical filters.

- **Parameters**:
  - `prev : opt nat`: Optional. The principal of the last Broadcaster from the previous query result for pagination continuation.
  - `take : opt nat`: Optional. The maximum number of Broadcaster entries to be returned.
  - `filter : opt OrchestrationFilter`: Optional. Filters to specify which data to fetch about Broadcasters.

- **Returns**:
  - A list of `BroadcasterInfo` which provides structured information about each Broadcaster including associated statistics.

```candid "Methods" +=

type ICRC75Item = record {
    principal: principal;
    namespace: text
  };

type OrchestrationQuerySlice = {
  variant {
    BySubscriber: Principal;
    ByPublisher : Principal;
    ByBroadcaster : Principal;
    ByNamespace : Text;
  }
}

type OrchestrationFilter = record {
  statistics: variant {
    None;
    All;
    List : vec text;
  };
  slice: vec OrchestrationQuerySlice
};

// Returns the Publishers known to the Orchestrator
icrc72_get_valid_broadcasters() -> (variant {
  list : vec principal;
  icrc75 : ICRC75Item;
}) query;

// Returns the Publishers known to the Orchestrator
icrc72_get_publishers({
  prev: opt principal;
  take: opt nat;
  filter: opt OrchestrationFilter;
}) -> (vec PublisherInfo) query;

//get publications known to the Orchestrator
icrc72_get_publications({
  prev: opt text;
  take: opt nat;
  filter: opt OrchestrationFilter;
}) -> (vec PublicationInfo) query;

// Returns the Subscribers known to the Orchestrator
icrc72_get_subscribers({
  prev: opt principal;
  take: opt nat;
  filter: opt OrchestrationFilter;
}) -> (vec SubscriberInfo) query;

icrc72_get_subscriptions({
  prev: opt nat;
  take: opt nat;
  filter: opt OrchestrationFilter;
}) -> (vec SubscriptionInfo) query;

icrc72_get_broadcasters({
  prev: opt principal;
  take: opt nat;
  filter: opt OrchestrationFilter;
}) -> (vec BroadcasterInfo) query;
```

## Broadcaster Canister

### Broadcaster Update Functions

These functions define the capabilities of a Broadcaster Canister in the pub-sub system, focusing on the handling and broadcasting of messages to Subscribers.

#### icrc72_publish

- **Type**: Update method
- **Parameters**: A vector of `Event` records.
- **Returns**: A vector of option types either indicating the successful processing with a vector of `nat` representing notification identifiers, or an error as `PublishError`.
- **Summary**: Accepts a list of events from Publishers and attempts to process and distribute these events to relevant Subscribers. It responds with either a list of event identifiers that have been successfully broadcasted or errors encountered during the process. Note: EventRelayers will use this endpoint and implementations will need to inspect the source to see if it matches the caller...if not, then it should be assumed the item is a relayed event and care should be taken to validate the sender.

#### icrc72_confirm_notifications

- **Type**: Update method
- **Parameters**: A vector of `nat` representing notifications identifiers.
- **Returns**: A variant indicating `allAccepted` if all notifications are successfully confirmed, or `itemized` with a vector of options detailing individual confirmation results.
- **Summary**: Used by Subscribers to confirm the receipt and processing of notifications. It helps in managing notification flow and tracking Subscriber engagement and reliability. Errors specific to each notification confirmation are addressed individually.



```candid "Methods" +=

type PublishError = variant {
  Unauthorized;
  ImproperId: Text;
  Busy; // This Broadcaster is busy at the moment and cannot process requests
  GenericError: GenericError;
  GenericBatchError : Text;
};

icrc72_publish(vec Event) : vec opt variant{
  #Ok: vec Nat; //notification IDs. - implementation dependent. A service may return ok with an empty vector if it is not practical to return all notification IDs.
  #Err: PublishError;
};


icrc72_confirm_notifications(vec nat) -> variant {
  allAccepted;
  itemized: vec opt variant {
    #Ok;
    #Err: ConfirmationError;
  };
};

```

Appendix: [Decision to return simple confirmation message](https://github.com/icdevs/ICEventsWG/issues/29)

## Broadcaster Query Functions

#### icrc72_get_broadcaster_stats

- **Type**: Query method
- **Returns**: `(BroadcasterStats)`
- **Summary**: Returns a comprehensive set of statistics related to the Broadcaster’s performance and usage. This includes metrics such as total events handled, events per time unit, error rates, and system resource usage. Useful for monitoring and optimizing Broadcaster performance.

```candid "Methods" +=

// Provides comprehensive statistics of the Broadcaster.
icrc72_get_broadcaster_stats : () -> (BroadcasterStats) query;
```

A future standard to be published under ICRC-92 will define canonical and generally used statistics for ICRC-72 canisters that implementors SHOULD implement unless they have devised an alternative schema for good reasons.

## Subscriber Canister

### Subscriber Update Functions

#### icrc72_handle_notification

- **Type**: Update method
- **Parameter**: `notification` (type `EventNotification`)
- **Returns**: `()`
- **Description**: Accepts an `EventNotification` which encapsulates an event that a Subscriber is registered to handle. The function processes the notification in the manner defined by the Subscriber canister's logic. This one-shot handling is designed for straightforward notification processes without the need for trust-establishment or additional confirmation from the Broadcaster.

#### icrc72_handle_notification_trusted

- **Type**: Update method
- **Parameter**: `notification` (type `EventNotification`)
- **Returns**: A variant indicating success with an optional value or the error description.
- **Description**: Similar to `icrc72_handle_notification`, but designed for more sensitive or critical operations where additional trust assurances from the Broadcaster are required. The trusted notification handler can process different types of inputs and provide detailed execution feedback. This function is crucial for interactions where the integrity and authenticity of the notification are paramount.
  
```candid "Methods" +=

icrc72_handle_notification :(vec notification) -> () //oneshot

icrc72_handle_notification_trusted : (vec notification) -> (variant{
  #Ok: Value
  #err: Text;
});
```

Appendix: (Add a trusted endpoint for smaller implementations)[https://github.com/icdevs/ICEventsWG/issues/14]

## Subscriber Query Methods

#### icrc72_get_subscriber_stats

- **Type**: Query method
- **Returns**: `(SubscriberStats)`
- **Summary**: Returns a comprehensive set of statistics related to the Subscriber's performance and usage. This includes metrics such as total events handled, events per time unit, error rates, and system resource usage. Useful for monitoring and optimizing Broadcaster performance.

```candid "Methods" +=

// Provides comprehensive statistics of the Subscriber.
icrc72_get_subscriber_stats : () -> (SubscriberStats) query;
```

### Generally-Applicable Specification

Please see the [ICRC-7 specifications](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md) for the Generally-Applicable Specifications as those items apply here as well:

- Batch Update Methods
- Batch Query Methods
- Error Handling

## Publisher Life Cycle

A Publisher that would like to publish events must register its publication with the Orchestrator.  The Orchestrator is responsible for ensuring a Broadcaster exists, notifying the Broadcaster, and then the Broadcaster will alert the Publisher that it is ready to receive events by emitting an ICRC-72 event notification via icrc72_handle_notifications.

This makes each Publisher also a Subscriber and therefore the Publisher should not start broadcasting events until after it has heard from a Broadcaster that it is ready to listen.

In order to ensure that the Publisher only listens to Broadcasters that are overseen by the orchestrator, the Publisher should follow the Subscriber workflow and query the orchestrator for a list of valid Broadcasters before registering publications.

Workflow:

1. Publisher acts as a Subscriber and queries valid Broadcasters via the icrc72_get_valid_broadcasters endpoint.
2. Publisher registers as a Subscriber to the namespace `icrc72:publisher:sys:{principal as Text}` by calling the icrc72_register_subscription method.
3. Publisher registers as a Publisher for the events it will publish with by calling `icrc72_register_publication` and receives back a publicationId from the Orchestrator
4. Publisher will receive Broadcaster assignments via a notification that has a data structure as follows:

  - `icrc72:publisher:broadcaster:add`: #Array[(Nat, Blob)] - ID of the publication and Broadcaster to broadcast to
  - `icrc72:publisher:broadcaster:remove`: #Array(Nat) - ID for the notification
  - `icrc72:publisher:broadcaster:error`: Array[Map[("error", #Text), ("code", Nat)?, ("id",#Nat)]] - ID of the publication for which the error occurred

 4. The Publisher will now be ready to broadcast.

 ### Event Structures

 Subscription Activated:

 ```motoko
  #Map([
    ("icrc72:publication:broadcaster:add": #Array([#Nat(123),#Blob([83...28])]))
  ])
 ```
 
 Error :

 ```motoko
  #Map([
    ("icrc72:publication:broadcaster:error": #Array([#Map([
      ("error", #Text("Subnet not available"),
      ("id", #Nat(123)),
      ("code", #Nat(2)))
    ])]))
  ])
 ```

 [Flow](https://mermaid.live/edit#pako:eNp9kkFv4jAQhf-K5ROVUoSTBRIfKi300kO3q-W2ioQGZxIsJXbWdlZLEf99bQIBVNpcHHnefH4zensqdIGUU4t_OlQCnyVUBppcEf-1YJwUsgXlyM9uQ8CGo5Z2i-aj4s2IbZCEE60z4PQd1WIZNAujoRBgXQD1Ik9-fHoKzZxIYcQ8Xlfo1n-hlsV6c9Hb0cMXLQYrGVRr222sMLJ1UqtRX-Tt2Ty3O8tbWTz0nEAYQCusS3LGBK9Ahj5SakM-g_WsO8RhWPLdWlmpBpW7kS2W_FTq9ysguCZO3-7pfsfqatAPLdeevtpWe3l2pKBB24LAiAitSlldb8kTPIeTX-g6c2v35flWFzye4nI1uO1Fi-WAutTID-1keeLRiDZoGpCFj-c-dOXUbbHBnHL_W2AJXe1ymquDl0Ln9GqnBOUl1BYj2rUFuHOch1sspE_la5_5Y_Qj6mNJ-Z7-ozyeTMezOcvSNEtYNk8iuqP8MY7ZmM1YkqZJPPnGUnaI6LvWHsrGcTqdzDLGknk8zabxEfb7WDs-ePgPK48fMQ)

 ![Publisher Flow](publisher.png "Publisher")

 ```
sequenceDiagram
    participant Pub as Publisher
    participant Orch as Orchestrator
    participant BC as Broadcaster

    Pub->>Orch: icrc72_get_valid_broadcasters()

    Pub->>Orch: icrc72_register_subscription(icrc72:publisher:sys:pid)
    Orch->>Orch: Self-register as a Publisher for icrc72:publisher:sys:pid
    
    Orch->>Orch: Broadcast Assignment
    Orch->>BC: Assign Publication to Broadcaster
    Orch->>BC: Assign Subscription to Broadcaster

    
    Pub->>Orch: icrc72_register_publication(namespace, config)
    Orch-->>Pub: Return Publication ID
    Orch-->>BC: Publish Assignments
    BC-->>Pub: Assignment Notification
```

 ## Broadcaster Life Cycle

A Broadcaster will listen for events from the Orchestrator to make sure it has valid event routing information.  The Orchestrator is responsible for emitting an ICRC-72 event that provides the Broadcaster with its assigned subscriptions and publications.

This makes each Broadcaster also a Subscriber.

Work flow:

1. Broadcaster registers as a Subscriber to the namespace `icrc72:broadcaster:sys:{principal as Text}` by calling the icrc72_register_subscription method.
2. Broadcaster will receive Broadcaster assignments via a notification that has a data structure as follows:

  - `icrc72:broadcaster:publisher:add`: Array[ Array[Text, Blob]] - optional - namespace, Publisher Principal as Blob - Publisher the Broadcaster can expect events for.
  - `icrc72:broadcaster:publisher:remove`: Array[ Array[Text, Blob]] - optional - namespace, Publisher Principal as Blob - Publisher the Broadcaster is no longer responsible for.
  - `icrc72:broadcaster:subscriber:add`: Array[ Array[Text, Blob]] - optional - namespace, Subscriber Principal as Blob -Subscriber the Broadcaster can expect events for.
  - `icrc72:broadcaster:subscriber:remove`: Array[ Array[Text, Blob]] - optional - namespace, Subscriber Principal as Blob - Subscriber the Broadcaster is no longer responsible for.
  - `icrc72:broadcaster:relay:add`: Array[Array[Text, Blob, ?Blob, ?Text, ?Array[Nat,Nat]]] - optional - namespace, targetBroadcaster Principal as Blob - subscriptions being added as an relayed subscription and the target event relayer canister, optionally subscriberBlob, Filter, Skip Array
  - `icrc72:broadcaster:relay:remove`: Array[Array[Text,Blob, ?Blob, ?Text, ?Array[Nat,Nat]]] - optional- namespace, targetBroadcaster Principal as Blob - subscriptions being removed as a relayed subscription and the target event relayer canisters to remove, optionally subscriberBlob, Filter, Skip Array for detail
  - `icrc72:broadcaster:relayer:add`: Array[Array[Text,Blob]] - optional - namespace,targetBroadcaster Principal as Blob - broadcaster being added as an event relayer and the target broadcaster
  - `icrc72:broadcaster:relayer:remove`: Array[Array[Text,Blob]] - optional - namespacetargetBroadcaster Principal as Blob - broadcaster being removed as an event relayer and the target broadcaster

3. Once the Broadcaster receives an event, it needs to pull the needed data from the Orchestrator that it needs to fulfill its job. This includes pulling publication info and subscription info.
 
 
 4. The Subscriber will now start receiving events unless an error has occurred


[Flow](https://mermaid.live/edit#pako:eNqFklFrwjAQx79KuOcqpl21zYOwdnuUDWQgoy9nE2vAJi5Jx5z43Ze2Ticqy0Mv9P_7312420OpuQAGVnw0QpXiSWJlsC4U8WeLxslSblE58mLKNUHbRWGdQafNNZXlLZMZjbxE68QN5LVZtowPG2nXt4h5T_hgSyOXd5DFJbPoof7bNjmYTrOckUdrZaXO5Qgq_sdGnL5u18NH96-Nk-dPoZzt9Sz3ss_BztZev5QXd3QvDY75c61W0tRkJqzFSqrqRCz-QXwRD7QPZeRty9GJvgSZO2z7hABqYWqU3E9333oKcGtRiwKYv3KxwmbjCijUwaPYOD3fqRLYCjdWBNB0KY_bcPoruPRjn_Ur021OAH4ewPbwBSwcxcPxhKZJkkY0nUQB7IANwpAO6ZhGSRKFowea0EMA31r7pHQYJvFonFIaTcI4jcMu2XundQUPP-zX2M8)

  ![Broadcaster Flow](broadcaster.png "Broadcaster")

 ```
 sequenceDiagram
    participant Orch as Orchestrator
    participant BC as Broadcaster
    participant Pub as Publisher
    participant Sub as Subscriber
    participant SubX as SubscriberX
    
    Orch->>BC: Assign Publisher and Subscriber to Broadcaster
    Pub->>BC: Published Events
    BC->>Sub: Broadcast Event
    BC->>SubX: Broadcast Event
    Sub-->>BC: Confirm Messaging
    SubX-->>BC: Confirm Messaging
    BC-->>Orch: Update Event Stats
```

 ## Subscriber Life Cycle

A Subscriber that would like to subscribe to events must register its subscription with the Orchestrator.  The Orchestrator is responsible for emitting an ICRC-72 event that provides the Publisher with its assigned broadcaster canister(s).

Workflow:

1. Subscriber registers as a Subscriber to the namespace `icrc72:subscriber:sys:{principal as Text}` by calling the icrc72_register_subscription method.
2. Subscriber registers as a Subscriber for the events it will publish with by calling `icrc72_register_subscription` and receives back a subscriptionId from the Orchestrator.
3. Subscriber will receive a subscription-activated message via a notification that has a data structure as follows:

  - `icrc72:subscriber:broadcaster:add`: Array[Text,Blob] - ID of the subscriptions activated and the the expected Broadcasters
  - `icrc72:subscriber:broadcaster:remove`: Array[Text,Blob] - ID of the subscriptions activated and the the expected Broadcasters
  - `icrc72:subscriber:error`: Array[Map[("error", #Text), ("code", Nat)?, ("id",#Nat)]] - ID of the subscriptions for which the error occurred
 
 4. The Subscriber will now start receiving events unless an error has occured

 ### Event Structures

 Subscription Activated:

 ```motoko
  #Map([
    ("icrc72:subscriber:activated": #Array([
      #Map([("subscriptionId", #Nat(1230)),("broadcasters", #Array(#Blob("0x12...12)))]),
      #Map([("subscriptionId", #Nat(456)),("broadcasters", #Array(#Blob("0x12...13)))])]))
  ])
 ```
 
 Error :

 ```motoko
  #Map([
    ("icrc72:subscription:error": #Array([#Map([
      ("error", #Text("Subnet not available"),
      ("id", #Nat(123)),
      ("code", #Nat(2)))
    ])]))
  ])
 ```


[Flow](https://mermaid.live/edit#pako:eNptkk1vgzAMhv8K8mmTaNXAaIFDpUJ32GGbtN0mpCoNhkYqCUtCta7qf18C_ZI6DgTZj1-_xjkAkyVCChq_OxQMl5zWijaF8OzTUmU44y0Vxvvs1h7V7tBM8TWqe-RdsY1j3InaKGrkP1SWOyZTkpaManMWGt5WfjSfO4HU40yxWbBSWHOHrfTQujVcigdBG9QtZeh7TIqK14-DgCsdWQkrlHofaDolzp77Qu9leQOeWy205rW4N3WCstxpDTbu_sANc00tmOE7arB83qEwA5jlF2N91HuThlecUedLX-c_ieVuLNX0WdudoR2gEOBDgzbKS7u0gysqwGywwQJS-1liRbutKaAQR4vSzsjPvWCQVnSr0YeuLa2r05IvUSy5XdXrcBP6C-GD3RWkB_iBNJhE4-mMJHGchCSZhT7sIR0FARmTKQnjOAwmTyQmRx9-pbSiZBzE0WSaEBLOgiiJgl7sq8_1DY9_MdDNsg)

 ![Subscriber Flow](subscriber.png "Subscriber")

 ```
 sequenceDiagram
    participant Sub as Subscriber
    participant Orch as Orchestrator
    participant BC as Broadcaster
    
    Sub->>Orch: icrc72_register_subscription(namespace, config)
    Orch-->>Sub: Return Subscription ID
    Orch->>Orch: Assign Broadcaster
    Orch->>BC: Register Subscriber
    Orch->>BC: SubscriberActivatedEvent
    BC-->>Sub: Event Notifications
    Sub-->>BC: Confirmation Receipt
```

## Extensions

The ICRC-72 standard may be extended or replaced by other ICRC Standards in the future.

### ICRC-77 Event Replay

Notification Replay for recovery of missed notifications was specifically removed from this ICRC standard to reduce the size and will submitted under ICRC-77 in the future.

### ICRC-83 Block Schema

Transaction Logs are not required for ICRC-72 implementation but may be added for transparency.  The proposed block schemas are handled in an extension to ICRC-72 in ICRC-83.

### ICRC-92 Statistics Definition and Collection for Event Utility

ICRC-72 provides no official set of statistics but recommendations for namespaces and default statistics are suggested in ICRC-92.

## Transaction Deduplication

Due to the inter-canister nature of the platform, transaction deduplication is not necessary.  The underlying framework of the IC should keep messages from being replayed.

Appendix: [Transaction Dedup Vote](https://github.com/icdevs/ICEventsWG/issues/34)

## Security Considerations

This section highlights some selected areas crucial for security regarding the implementation of ledgers following this standard and Web applications using ledgers following this standard. Note that this is not exhaustive by any means, but rather points out a few selected important areas.

### Protection Against Denial of Service Attacks

See notes on ICRC-7

### Protection Against Web Application Attacks

See notes on ICRC-7

## Data Security Considerations

When implementing the ICRC-72 standard for event-driven pub-sub systems on the Internet Computer (IC), it is crucial to consider the security of data both in transit and at rest. Despite the robust architecture of the IC, there are specific considerations that developers must keep in mind to enhance the privacy and security of the system.

### Transparency of Data on the Internet Computer

The IC does not inherently obfuscate or encrypt data stored within canisters or transmitted between them. This means that data stored in canisters and the data sent from one canister to another is not encrypted by default and could potentially be accessed by node providers. Node providers have physical control over the machines that run the various canisters, and while they are expected to follow strict guidelines and protocols to maintain the security and isolation of canister execution, the theoretical risk of data exposure exists.

### Encryption Requirements for Private Data

For data that needs to remain confidential:

- **External Encryption:** To guarantee the privacy of data, it should be encrypted before it is uploaded to the IC. This encryption should be performed externally using secure and robust encryption standards. By doing so, the data remains encrypted while it is at rest on the IC and during transmission between canisters, ensuring that it is only readable by entities possessing the appropriate decryption keys.
  
- **Handling Sensitive Information:** Any sensitive information that must be kept confidential should not rely solely on the infrastructure's security practices but should be explicitly protected through end-to-end encryption techniques.

### Utilizing vetKeys for Enhanced Privacy

While the IC ecosystem is exploring technologies like `vetKeys` to enhance the privacy and security of inter-canister communications, there are limitations to the privacy guarantees they can provide:

- **Intermediate Access:** Canisters involved in encrypting or decrypting the data may still expose decrypted data at those points. If a broadcasting node (either a Publisher or a Subscriber canister) is responsible for encryption or decryption, the operators of these nodes could theoretically access the unencrypted data.
  
- **Security of Encryption/Decryption Nodes:** Trust in the node handling encryption and decryption is paramount. Careful consideration must be given to the security of these nodes to prevent unauthorized access to sensitive decrypted data. 

## Error Handling

ICRC-72 integrates an inherently asynchronous event-driven system, where Publishers dispatch events without requiring direct interaction or feedback from the subscribing systems. This design philosophy emphasizes loose coupling between Publishers and Subscribers, enhancing system scalability and resilience.

Given the asynchronous communication model, a Publisher's responsibility ends when it successfully sends an event to a Broadcaster or directly to Subscribers. The Publisher remains agnostic to how an event is processed by Subscribers, which aligns with the principles of isolation and independence in distributed systems. This approach ensures that the publishing canister does not depend on the Subscriber’s processing capabilities or state, thereby avoiding tight coupling and complex dependency chains.

### Lack of Synchronous Error Handling

In accordance with the asynchronous communication model:
- **Publishers do not receive feedback** concerning the reception or handling of events by Subscribers. Once an event is dispatched correctly from the Publisher to the Broadcaster (or directly to the Subscribers, if applicable), the Publisher's responsibility concludes.
- **Error propagation is not actively managed** between Publishers and Subscribers. Errors that occur in processing an event on the Subscriber's end do not retroactively influence the Publisher or the Broadcaster. Each component handles its own internal errors independently.
- **Broadcasters**, similar to Publishers, do not track or manage errors related to a Subscriber's ability to process an event. They ensure the events are forwarded as specified but do not confirm processing outcomes.

## Performance and Scalability

Implementing the ICRC-72 standard effectively on the Internet Computer requires careful consideration of performance and scalability factors. This section outlines key considerations and strategies to optimize the efficiency and scalability of pub-sub systems in decentralized environments.

### 1. **Balancing Event Size and Information Content**

On the Internet Computer, the cost of processing requests is tied to the number of cycles consumed, which is directly impacted by the size of the data in the requests. When designing event messages, it is crucial to balance the need to include sufficient information for subscribers against the cost implications of larger message sizes.

- **Minimal Information for Efficiency**: Including only the essential information needed by subscribers in each event can minimize request sizes, thereby reducing the cycle costs associated with processing these requests. This approach minimizes the load on both the Publisher and the Broadcaster, allowing the system to handle more requests efficiently.

- **Reducing Additional Requests**: On the other hand, if an event contains too little information, subscribers may need to make additional requests to retrieve the necessary data. These extra requests can increase overall system load, leading to higher latency and additional cycle costs. To optimize performance, events should be designed to include enough information to avoid unnecessary follow-up queries while keeping the data payload minimal.

- **Strategies for Optimal Event Design**: Implementers should consider strategies such as including summary data or compressed representations of more extensive datasets within the event. For example, a Publisher might include a compact hash of additional data, which subscribers can verify without fetching the entire dataset unless necessary.

### 2. **Impact of Event Size on Throughput**

The size of events directly impacts the throughput of the pub-sub system on the Internet Computer. Each request is limited to approximately 2MB, which constrains the maximum size of individual events.

- **Event Size Limitations**: Larger event sizes reduce the number of events that can be processed concurrently, limiting the throughput of the system. Publishers and Broadcasters must manage these constraints carefully to maximize efficiency. If events are too large, they can clog the network and reduce the overall rate at which messages are transmitted and processed.

- **Optimizing Event Sizes**: To maintain high throughput, event sizes should be kept as small as possible while still containing sufficient information.

### 3. **Managing Outgoing Bandwidth and Subnet Load**

Outgoing bandwidth on the Internet Computer is broad and scales well. Every event published to a subnet involves overhead due to the architecture of the IC's decentralized, peer-to-peer (p2p) network, but only the interested replicas need to download the data from the p2p network. Thus, a subnet's outgoing bandwidth may be significantly higher than the amount of data that may enter via ingress as all incoming data needs to be included in the incoming request.
