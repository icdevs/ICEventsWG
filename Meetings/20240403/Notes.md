The following were meeting notes collected during the meeting:

Intros

Austin
Ilia


Meeting note otter.ai

Rough consensus



Sam
Matthew H
Joseph Ebin
Byron Becker
Ilia Aga
Zhenya Usenco
Dclan Nnadozi
Unicorn

Issue 1 for ICRC:

# Generic Data Types:

{
   owner: principal;
   subaccount: blob;
}

The superpower of pub/sub and events : We don't have to coordinate to interoperate.

```
public type GenericEvent = {
    eventFilter : [EventFilter];
    publisher : Principal;
    schema : ?DataSchema;
    issue_at : Nat64;
    expire_at : ?Nat64;
    data : [(Text, Value)];
    details : ?Text;
};

public type DataSchema = {
        id : Text;
        version : Text;
        fields : [(Text, Value)];
    };
	
	public type EventField = {
        name : Text;
        value : Blob;
    };

    public type EventFilter = {
        eventType : ?EventName;
        fieldFilters : [EventField];
    };
	
	public type Subscriber = {
        callback : Principal; // subscriber's canister_id
        filter : [(EventFilter, MethodName)];
		};
		
	public type MethodName : Text;	// ex.: eventHandler()
 ```
- Do we use Just a blob.
- Value type from ICRC3. (Metadata) - Stricrict definiton hash calculation
- ICRC16 - Superset of Value.
  - https://github.com/ZhenyaUsenko/motoko-candy-utils


# Generic Methods / Client

How small can we keep it and keep it interesting and useful?


# Best Practices
 - Event data is small


Byron Becker
12:45 PM
One thing I'd like to also note is that we maybe start from a few different use cases, and talk to projects so that we understand the requirements and needs of who would actually use this, how large the data is, etc.

The design for an event pub-sub system varies depending on the size and schema of the data

- Steady stream vs. spikes.
- Broad use case vs. specific use case.

High throughput via schema and constraints.
Examples - Segments, other web 2 event publishing frameworks.

Kafka.

Next Action:
 - Byron - Web2 messaging/event research
 - Everyone: Bring a proposal. - External Actor end point. Internal Data structure/workflow
 - Everyone: Review ICRC-16 vs. ICRC-3 value - Pros & Cons
 - Austin - More descriptive Token tracking solution.
 - Matt - Multi player - pubsub - websockets - Can it support it? Webrtc?
