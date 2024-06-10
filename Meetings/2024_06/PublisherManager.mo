import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Types "../ICRC72Types";
import Utils "../Utils";

module {
    public class PublisherManager() = Self {
        type Namespace = Text;
        type PublicationId = (Principal, Namespace);
        type EventNotificationId = Nat;        

        private var publications = HashMap.HashMap<Principal, [Types.PublicationInfo]>(10, Principal.equal, Principal.hash);
        
        private var notifications = HashMap.HashMap<Principal, [EventNotificationId]>(10, Principal.equal, Principal.hash);

        private var events = HashMap.HashMap<Principal, [Types.EventRelay]>(10, Principal.equal, Principal.hash);

        // Register an single future publication by publisher with the specified namespace.
        public func register_single_publication(publisher : Principal, publication : Types.PublicationRegistration) : async (Namespace, Bool) {
            // Validate the publication
            if (publication.namespace == "") {
                return (publication.namespace, false);
            };
            let pub = await getPublicationsByNamespace(publisher, publication.namespace);
            switch (pub) {
                case (?(_)) {
                    // If the publication is already registered, return false
                    return (publication.namespace, false);
                };
                case (null) {
                    let publicationInfo : Types.PublicationInfo = {
                        namespace = publication.namespace;
                        stats = [];
                    };
                    var publication_list = publications.get(publisher);
                    switch (publication_list) {
                        case (null) {
                            publications.put(publisher, [publicationInfo]);
                        };
                        case (?list) {
                            let updatedList : [Types.PublicationInfo] = Utils.pushIntoArray(publicationInfo, list);
                            publications.put(publisher, updatedList);
                        };
                    };
                };
            };

            (publication.namespace, true);
        };

        // Register an array of future publications by publisher with the specified namespace.
        public func register_publications(publisher : Principal, publications : [Types.PublicationRegistration]) : async [(Namespace, Bool)] {
            let result = Buffer.Buffer<(Namespace, Bool)>(publications.size());
            for (publication in publications.vals()) {
                let single_result = await register_single_publication(publisher, publication);
                result.add(single_result);
            };
            Buffer.toArray(result);
        };

        public func removePublication(publisher : Principal, namespace : Namespace) : async Bool {
            var publication_list = publications.get(publisher);
            switch (publication_list) {
                case (null) {
                    // If the publisher is not registered, return false
                    false;
                };
                case (?list) {
                    // Remove the publication from the publications map
                    let updatedList = Array.filter<Types.PublicationInfo>(
                        list,
                        func(item) {
                            item.namespace != namespace;
                        },
                    );
                    publications.put(publisher, updatedList);
                    true;
                };
            };
        };

        public func unregisterPublisher(publisher : Principal) : async Bool {
            var publication_list = publications.get(publisher);
            switch (publication_list) {
                case (null) {
                    // If the publisher is not registered, return false
                    false;
                };
                case (?list) {
                    // Remove the publication from the publications map
                    ignore publications.remove(publisher);
                    true;
                };
            };
        };

        public func getPublications(publisher : Principal) : async [Types.PublicationInfo] {
            Option.get(publications.get(publisher), []);
        };

        public func getPublishers() : async [Principal] {
            Iter.toArray(publications.keys());
        };

        public func getPublicationsByNamespace(publisher : Principal, namespace : Namespace) : async ?Types.PublicationInfo {
            var publication_list = publications.get(publisher);
            switch (publication_list) {
                case (null) {
                    // If the publisher is not registered, return an empty list
                    return null;
                };
                case (?list) {
                    // Get the publication by namespace
                    let publication = Array.find<Types.PublicationInfo>(
                        list,
                        func(item) {
                            item.namespace == namespace;
                        },
                    );
                    publication;
                };
            };
        };

        // Method to publish an event to all subscribers
        public func publishEventWithResponse(subscribers : [Types.Subscriber], event : Types.EventRelay) : async [(Principal, Types.Response)] {
            let buffer = Buffer.Buffer<(Principal, Types.Response)>(0);
            for (subscriber in subscribers.vals()) {
                let subscriber_actor : Types.SubscriberActor = actor (Principal.toText(subscriber.subscriber));
                let message : Types.EventNotification = {
                    id = notifications.size();
                    eventId = event.id;
                    preEventId = event.prevId;
                    namespace = event.namespace;
                    source = event.source;
                    timestamp = event.timestamp;
                    data = event.data;
                    headers = event.headers;
                    filter = ?subscriber.filter[0];
                };
                Debug.print("PubManager.publishEventWithResponse: Sending message to subscriber: " # Principal.toText(subscriber.subscriber));
                let response = await subscriber_actor.icrc72_handle_notification_trusted([message]);
                saveNotification(subscriber.subscriber, message);
                saveEvent(event);
                buffer.add((subscriber.subscriber, response));
            };
            return Buffer.toArray(buffer);
        };

        public func publishEventToSubscribers(subscribers : [Types.Subscriber], event : Types.EventRelay) : async [Nat] {
            var result = Buffer.Buffer<Nat>(subscribers.size());
            // send event to all subscribers
            for (subscriber in subscribers.vals()) {
                let subscriber_actor : Types.SubscriberActor = actor (Principal.toText(subscriber.subscriber));

                let message : Types.EventNotification = {
                    id = notifications.size();
                    eventId = event.id;
                    preEventId = event.prevId;
                    namespace = event.namespace;
                    source = event.source;
                    timestamp = event.timestamp;
                    data = event.data;
                    headers = event.headers;
                    filter = ?subscriber.filter[0];
                };
                saveEvent(event);

                await subscriber_actor.icrc72_handle_notification([message]);
                saveNotification(subscriber.subscriber, message);

            };
            Buffer.toArray(result);
        };

        private func saveEvent(event : Types.EventRelay) {
            let exist_events = events.get(event.source);
            switch (exist_events) {
                case (null) {
                    events.put(event.source, [event]);
                };
                case (?_exist) {
                    let new_events = Utils.pushIntoArray<Types.EventRelay>(event, _exist);
                    events.put(event.source, new_events);
                };
            };
        };

        private func saveNotification(subscriber : Principal, notification : Types.EventNotification) {
            let exist_notification = notifications.get(subscriber);
            switch (exist_notification) {
                case (null) {
                    notifications.put(subscriber, [notification.id]);
                };
                case (?_exist) {
                    // TODO: check for duplicate ids
                    let new_notifications = Utils.pushIntoArray<EventNotificationId>(notification.id, _exist);
                    notifications.put(subscriber, new_notifications);
                };
            };
        };        
    };
};
