import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
module {
    type Message = {
        id : Nat;
        timestamp : Nat;
        namespace : Text;
        data : ICRC16;
        source : Principal;
        filter : Text;
    };

    type Event = {
        id : Nat;
        timestamp : Nat;
        namespace : Text;
        data : ICRC16;
    };

    type EventRelay = {
        id : Nat;
        timestamp : Nat;
        namespace : Text;
        source : Principal;
        data : ICRC16;
    };

    type PublicationRegistration = {
        namespace : Text;
        config : [(Text, ICRC16)];
    };

    type SubscriptionRegistration = {
        namespace : Text;
        config : [(Text, ICRC16)];
        filter : ?Text;
        skip : ?Nat;
        stopped : Bool;
    };

    public type SubscriptionUpdate = {
        subscriptionId : Nat;
        newConfig : ?[(Text, ICRC16)];
        newFilter : ?Text;
        newSkip : ?Nat;
        newStopped : ?Bool;
    };

    type ICRC16Property = {
        name : Text;
        value : ICRC16;
        immutable : Bool;
    };

    public type ICRC16 = {
        #Array : [ICRC16];
        #Blob : Blob;
        #Bool : Bool;
        #Bytes : [Nat8];
        #Class : [ICRC16Property];
        #Float : Float;
        #Floats : [Float];
        #Int : Int;
        #Int16 : Int16;
        #Int32 : Int32;
        #Int64 : Int64;
        #Int8 : Int8;
        #Map : [(Text, ICRC16)];
        #ValueMap : [(ICRC16, ICRC16)];
        #Nat : Nat;
        #Nat16 : Nat16;
        #Nat32 : Nat32;
        #Nat64 : Nat64;
        #Nat8 : Nat8;
        #Nats : [Nat];
        #Option : ?ICRC16;
        #Principal : Principal;
        #Set : [ICRC16];
        #Text : Text;
    };

    // ICRC3
    type Value = {
        #Nat : Nat;
        #Nat8 : Nat8;
        #Int : Int;
        #Text : Text;
        #Blob : Blob;
        #Bool : Bool;
        #Array : [Value];
        #Map : [(Text, Value)];
    };

    public func icrc72_handle_notification(message : Message) : async () {
        Debug.print("Client: icrc72_event_listener: done, message:  " # Nat.toText(message.id));
    };

    public func icrc72_handle_notification_trusted(message : Message) : async ({
        #Ok : Value;
        #Err : Text;
    }) {
        Debug.print("Client: icrc72_event_listener_trusted: done, message:  " # Nat.toText(message.id));
        #Ok(#Text("OK"));
    };

    /*
    icrc72_publish(vec Eve nt) : vec opt variant{
  #Ok: vec Nat;
  #Err: PublishError;
};

icrc72_publish_relay(vec EventRelay) : vec opt variant{
  #Ok: vec Nat;
  #Err: PublishError;
};
    */
    public func icrc72_publish(event : Event) : async ({
        #Ok : Value;
        #Err : Text;
    }) {
        Debug.print("Client: icrc72_publish: done, event:  " # Nat.toText(event.id));
        #Ok(#Text("OK"));
    };

    public func icrc72_publish_relay(event : EventRelay) : async ({
        #Ok : Value;
        #Err : Text;
    }) {
        Debug.print("Client: icrc72_publish_relay: done, event:  " # Nat.toText(event.id));
        #Ok(#Text("OK"));
    };

    public func publishEvent(hub : Text, publisher : Principal, event : Event, filters : [Text]) : async ({
        #Ok : Value;
        #Err : Text;
    }) {
        // Call hub.icrc72_publish(event) but we need to add publisher and filters
        Debug.print("Client: publishEvent: done, event:  " # Nat.toText(event.id));
        #Ok(#Text("OK"));
    };

    public func register_publication(registration : PublicationRegistration) : async Bool {
        // icrc72_register_publication(vec PublicationRegistration) ->  vec[Bool];
        Debug.print("Register publication for namespace: " # registration.namespace);
        true;
    };

    public func register_subscription(registration : SubscriptionRegistration) : async Bool {
        // icrc72_register_subscription(vec SubscriptionRegistration) ->  vec[Bool];
        Debug.print("Register subscription for namespace: " # registration.namespace);
        true;
    };

    public func publishEventRelay(event : EventRelay) : async ({
        #Ok : Value;
        #Err : Text;
    }) {
        // icrc72_publish_event_relay(vec EventRelay) ->  vec opt variant{
        //   #Ok: vec Nat;
        //   #Err: PublishError;
        // };
        Debug.print("Client: publishEventRelay: done, event:  " # Nat.toText(event.id));
        #Ok(#Text("OK"));
    };

    public func update_subscription(subscriptionId : Nat) : async Bool {
        // icrc72_update_subscription(vec SubscriptionUpdate) ->  vec[Bool];
        Debug.print("Cancel subscription ID: " # Nat.toText(subscriptionId));
        true;
    };
    // ----------------------------------------------------------
    public func get_publication_stats(hub : Text, namespace : Text) : async [(Text, ICRC16)] {
        [("Total Events", #Nat(10))];
    };

    public func get_subscription_stats(hub : Text, namespace : Text) : async [(Text, ICRC16)] {
        [("Active Subscriptions", #Nat(5))];
    };

};
