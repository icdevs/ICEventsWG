import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import t "mo:candy/types";
import Principal "mo:base/Principal";

module {
    public type Message = {
        id : Nat;
        timestamp : Nat;
        namespace : Text;
        data : ICRC16;
        source : Principal;
        filter : Text;
    };

    public type Filter = {
        topic : Text;
        condition : ?Text; // candyPath
    };

    public type SubscriptionRegistration = {
        namespace : Text;
        config : [(Text, ICRC16)];
        filter : ?Filter;
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

    public type ICRC16 = t.CandyShared;

    // ICRC3
    public type Value = {
        #Nat : Nat;
        #Nat8 : Nat8;
        #Int : Int;
        #Text : Text;
        #Blob : Blob;
        #Bool : Bool;
        #Array : [Value];
        #Map : [(Text, Value)];
    };

    public shared ({ caller }) func register_subscription(broadcaster : Text, subscription : [SubscriptionRegistration]) : async [(Principal, Bool)] {
        Debug.print("Subscriber: Register subscription for namespace: " # subscription[0].namespace);
        [(caller, true)];
    };

    public func icrc72_handle_notification(message : Message) : async () {
        Debug.print("Subscriber: icrc72_event_listener: done, message:  " # Nat.toText(message.id));
    };

    public func icrc72_handle_notification_trusted(message : Message) : async ({
        #Ok : Value;
        #Err : Text;
    }) {
        Debug.print("Subscriber: icrc72_event_listener_trusted: done, message:  " # Nat.toText(message.id));
        #Ok(#Text("Subscriber: OK"));
    };

    public func update_subscription(subscriptionId : Nat) : async Bool {
        Debug.print("Subscriber: Update subscription ID: " # Nat.toText(subscriptionId));
        true;
    };

    public func subscribe(caller : Principal, broadcaster : Text, namespace : Text, filter : ?Filter, skip : ?Nat) : async Nat {
        Debug.print("Subscriber: Subscribe to namespace: " # namespace);
        1;
    };

    public func get_subscription_stats(broadcaster : Text, namespace : Text) : async [(Text, ICRC16)] {
        [("Subscriber: Active Subscriptions", #Nat(5))];
    };
};
