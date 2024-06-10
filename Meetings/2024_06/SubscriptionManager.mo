import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Types "../ICRC72Types";
import Utils "../Utils";

module {
    public class SubscriptionManager() = Self {
        /**
         * Maps a subscriber's Principal to their SubscriptionInfo.
         *
         * This data structure is used to keep track of subscribers and their subscriptions.
         * It maps a subscriber's Principal to a list of their subscriptions.
         * The Principal is used as the key to uniquely identify each subscriber.
         * The SubscriptionInfo contains information about the subscriber's subscriptions.
         * type SubscriptionInfo : {
         *   namespace : Text; // The namespace to which the subscription pertains
         *   filters : [Text]; // Filters defining what messages should be received
         *   skip : ?Nat; // Optional parameter to skip certain numbers of messages (e.g., for paging)
         *   stopped : Bool; // Flag to determine whether the subscription is active or temporarily stopped
         *   config : Map;
         *   }
         */
        private var subscriptions : HashMap.HashMap<Principal, [Types.SubscriptionInfo]> = HashMap.HashMap<Principal, [Types.SubscriptionInfo]>(10, Principal.equal, Principal.hash);

        public func icrc72_register_single_subscription(subscription : Types.SubscriptionInfo) : async Bool {
            var subscriber_list = subscriptions.get(subscription.subscriber);
            switch (subscriber_list) {
                case (null) {
                    // if the subscriber is not found, add the subscription to the list
                    subscriptions.put(subscription.subscriber, [subscription]);
                };
                case (?list) {
                    // else, check if the subscription already exists
                    let exists = Array.find<Types.SubscriptionInfo>(
                        list,
                        func(s) {
                            s.namespace == subscription.namespace and s.subscriber == subscription.subscriber
                        },
                    );
                    switch (exists) {
                        case (null) {
                            // if the subscription is not found, add it to the list
                            var l = Utils.pushIntoArray<Types.SubscriptionInfo>(subscription, list);
                            subscriptions.put(subscription.subscriber, l);
                        };
                        case (_) {
                            // else, return false
                        };
                    };
                };
            };
            true;
        };

        public func icrc72_register_subscription(subscriptionInfos : [Types.SubscriptionInfo]) : async [(Types.SubscriptionInfo, Bool)] {
            var results = Buffer.Buffer<(Types.SubscriptionInfo, Bool)>(subscriptions.size());
            for (subscription in subscriptionInfos.vals()) {
                subscriptions.put(subscription.subscriber, [subscription]);
                results.add((subscription, true));
            };
            return Buffer.toArray(results);
        };

        public func getSubscribersByNamespace(namespace : Text) : async [Principal] {
            let result = Buffer.Buffer<Principal>(0);
            label a for (subscriber in subscriptions.keys()) {
                let subscriber_subscriptions = await getSubscriptionInfo(subscriber);
                for (subscription in subscriber_subscriptions.vals()) {
                    if (subscription.namespace == namespace) {
                        result.add(subscriber);
                        continue a;
                    };
                };
            };
            return Buffer.toArray(result);
        };

        public func getSubscriptionsByNamespace(namespace : Text) : async [Types.SubscriptionInfo] {
            let result = Buffer.Buffer<Types.SubscriptionInfo>(0);
            label b for (subscriber in subscriptions.keys()) {
                let subscriber_subscriptions = await getSubscriptionInfo(subscriber);
                for (subscription in subscriber_subscriptions.vals()) {
                    if (subscription.namespace == namespace) {
                        result.add(subscription);
                        continue b;
                    };
                };
            };
            return Buffer.toArray(result);
        };

        // Get subscription information for a specific subscriber
        public func getSubscriptionInfo(subscriber : Principal) : async [Types.SubscriptionInfo] {
            Option.get(subscriptions.get(subscriber), []);
        };

        // Get all subscriptions for all subscribers
        public func getSubscriptions() : async [Types.SubscriptionInfo] {
            let result = Buffer.Buffer<Types.SubscriptionInfo>(0);
            for (subscriber in subscriptions.keys()) {
                let subscriber_subscriptions = await getSubscriptionInfo(subscriber);
                for (subscription in subscriber_subscriptions.vals()) {
                    result.add(subscription);
                };
            };
            return Buffer.toArray(result);
        };       

        // Unsubscribe a subscriber from a specific namespace
        public func unsubscribeByNamespace(subscriber : Principal, namespace : Text) : async () {
            let existingSubs = Option.get(subscriptions.get(subscriber), []);
            let filteredSubs = Array.filter<Types.SubscriptionInfo>(
                existingSubs,
                func(info : Types.SubscriptionInfo) : Bool {
                    info.namespace != namespace;
                },
            );
            if (filteredSubs.size() == 0) {
                ignore subscriptions.remove(subscriber);
            } else {
                subscriptions.put(subscriber, filteredSubs);
            };
        };

        // Unsubscribe a subscriber from all namespaces
        public func unsubscribeAll(subscriber : Principal) : async () {
            ignore subscriptions.remove(subscriber);
        };       

        // Update the status of a subscription (e.g., pause or resume)
        public func updateSubscriptionStatus(subscriber : Principal, namespace : Text, active : Bool) : async () {
            let existingSubs = Option.get(subscriptions.get(subscriber), []);
            let updatedSubs = Array.map<Types.SubscriptionInfo, Types.SubscriptionInfo>(
                existingSubs,
                func(info : Types.SubscriptionInfo) {
                    if (info.namespace == namespace) {
                        {
                            namespace = info.namespace;
                            subscriber = info.subscriber;
                            active = active;
                            filters = info.filters;
                            messagesReceived = info.messagesReceived;
                            messagesRequested = info.messagesRequested;
                            messagesConfirmed = info.messagesConfirmed;
                        };
                    } else {
                        info;
                    };
                },
            );
            subscriptions.put(subscriber, updatedSubs);
        };
    };
};
