
|ICRC|Title|Author|Discussions|Status|Type|Category|Created|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|83|Extension: Block Schema for ICRC-72|Austin Fatheree (@skilesare),Ilia Agafonov @ava-vs, Byron Becker @byronbecker, Ethan Celletti @gekctek, Lachlan Witham, Zhenya Usenko, Matthew Harmon|https://github.com/dfinity/ICRC/issues/83|Draft|Standards Track||2024-04-10|



# ICRC-72: Minimal Event-Driven Pub-Sub Standard

ICRC-72, the Minimal Event-Driven Pub-Sub Standard, is designed to establish a robust framework for implementing publish-subscribe messaging patterns on the Internet Computer. This standard facilitates the communication and synchronization of data across different canisters, enabling them to subscribe to and publish events effectively. By formalizing the interactions between publishers, subscribers, and broadcasters, ICRC-72 aims to enhance the interoperability, scalability, and efficiency of decentralized applications on the Internet Computer.

The publish-subscribe pattern, a pivotal architectural style, allows components of distributed systems to exchange information asynchronously. This pattern decouples the service provider (publisher) from the service consumers (subscribers), using an event-driven approach that promotes loose coupling and dynamic network topologies. ICRC-72 leverages these benefits to provide a standardized mechanism where canisters can subscribe to specific types of messages and react to them, without needing to poll or maintain a direct linkage to the message originators.

Key components of ICRC-72 include:
- **Publishers** who generate and send messages to broadcasters.
- **Broadcasters** who receive messages from publishers and distribute them to all registered subscribers.
- **Subscribers** who listen for messages of interest from broadcasters and process them accordingly.
- **Orchestrator** who manages network topography, subscriptions, publications, and assignments.

This standard describes how these canisters can record thier transaction log history in an ICRC-3 Transaction log.

## ICRC-72 Block Schema

The ICRC-72 Standard follows the ICRC-3 block schema definitions for basic block types.  It further defines the following blocks that an ICRC-72 canister MAY implement if it has a transaction log. The inclusion of these block types does not require that an ICRC-72 implementation has to have a transaction log and is included for standardization in the case it is desired by an implementation.

### Orchestrator Canister Block Types

#### 72PubReg - Publication Registration

- **Type**: `72PubReg`
- **Fields**:
  - `namespace`: Text - The namespace of the publication.
  - `config`: Map - optional - Configuration settings for the publication.
  - `memo`: Blob - optional - A memo field for including additional unstructured data.
  - `publicationId` - ID assigned by the system to the subscription.

  Publication registration updates are filed as additional 72PubReg methods.

#### 72SubReg - Subscription Registration

- **Type**: `72SubReg`
- **Fields**:
  - `namespace`: Text - The namespace to which the subscription relates.
  - `config`: Map - optional Subscription-specific configuration settings.
  - `memo` : Blob - A memo field for including additional unstructured data.
  - `subscriptionId` - ID assigned by the system to the subscription.

  Subscription registration updates are filed as additional 72SubReg methods.

#### 72BroadcasterAssign - Broadcaster Assignment

- **Type**: `72BroadcasterAssign`
- **Fields**:
  - `publicationId`: Nat - The identifier of the publication.
  - `broadcaster`: Blob - The principal of the assigned broadcaster.
  - `action` : Text - `activate`, `deactviate`

#### 72BroadcasterReg - Broadcaster Registration

- **Type**: `72BroadcasterReg`
- **Fields**:
  - `principal`: Blob - The Principal for the registered broadcaster.

#### 72SubscriptionAssign - Subscription Assignment

- **Type**: `72SubscriptionAssign`
- **Fields**:
  - `subscriptionId`: Nat - The identifier of the subscription.
  - `broadcaster`: Blob - The principal of the assigned broadcaster.
  - `action` : Text - `activate`, `deactviate`

#### 72RelayAssign - Relay Assignment

- **Type**: `72RelayAssign`
- **Fields**:
  - `publicationId`: Nat - The identifier of the subscription.
  - `broadcaster`: Blob - The principal of the assigned broadcaster.
  - `relay`: Blob - The principal of the assigned relay.
  - `action` : Text - `activate`, `deactviate`

### Publisher Canister Blocks 

#### 72BroadcasterUpdate - Broadcaster Update

- **Type**: `72BroadcasterUpdate`
- **Fields**:
  - `broadcaster`: Blob - The principal of the broadcaster being updated.
  - `action`: Text - `add`, `remove`.

Publishers MAY register the sending of an event with a `72Event` block type(see Broadcaster Events).



### Subscriber Block Types

Subscribers MAY register the reciept of a notification with a `72Notification` block type(see Broadcaster Events).

### Broadcaster Events

#### 72Event - Event Publication

- **Type**: `72Event`
- **Fields**:
  - `eventId`: Nat - Unique identifier of the event.
  - `data`: Value - The data associated with the event.
  - `header` : Map - Any Headers received.
  - `ts` : Nat - Timestamp assigned by the publisher
  - `namespace` : Text - Namespace of the Publication.
  - `source` : Blob - Principal of the publisher. Optional if this record is being recorded by a Publisher.

#### 72Notification - Notification Registration

- **Type**: `72Notification`
- **Fields**:
  - `notificationId`: Nat - The identifier of the notification.
  - `namespace` : Text - Namespace of the Publication.
  - `eventId`: Nat - Link to the original event that triggered this notification.
  - `eventPrevId`: Nat - optional - previous event ID if applicable.
  - `timestamp`: Nat - When the notification was generated and sent.
  - `subscriber` : Blob - Principal the notification is directed toward. Optional if this block is being emitted by a subscriber
  - `publisher` : Blob - Principal the event originated from. 
  - `headers` : Map - optional - Any additional headers added by the broadcaster. Initial headers do not need to be repeated.
  - `filter` : Text - optional - a filter if applied.

#### 72Confirmation - Confirmation Received

- **Type**: `72Confirmation`
- **Fields**:
  - `notificationIds`: Array [Nat] - The identifiers of the notifications being confirmed.
  - `subscriber` : Blob - Principal the notification is directed toward.

#### 72Relay - Relay Received

- **Type**: `72Relay`
- **Fields**:
  - `sourceBroadcaster`: Blob - The principal of the broadcaster from which the relay originated.
  - `eventId`: Nat - Unique identifier of the event.
  - `eventPrevId`: Nat - optional - ID of the previous event for tracking order
  - `data`: Value - The data associated with the event.
  - `header` : Map - Any Headers received.
  - `ts` : Nat - Timestamp assigned by the publisher
  - `namespace` : Text - Namespace of the Publication.
  - `source` : Blob - Principal of the publisher.

#### 72SubscriptionAssign - Assignment of a subscription to a broadcaster

- **Type**: `72SubscriptionAdded`
- **Fields**:
  - `namespace`: Text - The namespace to which the subscription relates.
  - `config`: Map - optional Subscription-specific configuration settings.
  - `subscriptionId` - ID assigned by the system to the subscription.

#### 72SubscriptionRemove - Remove a subscription from a broadcaster

- **Type**: `72SubscriptionRemoved`
- **Fields**:
  - `subscriptionId` - ID assigned by the system to the subscription.

#### 72RelayAssign - Assignment of a relay to a broadcaster

- **Type**: `72RelayAdded`
- **Fields**:
  - `namespace`: Text - The namespace to which the relay relates.
  - `config`: Map - optional Subscription-specific configuration settings.
  - `target` : Blog - principal of the relaying broadcaster canister


## Extensions

The ICRC-72 standard may be extended or replaced by other ICRC Standards in the future.

Notification Replay for recovery of missed messages was specifically removed from this ICRC standard to reduce the size and will submitted under ICRC-77 in the future.

