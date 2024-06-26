import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import T "./EthTypes";
import EthSender "./EventSender";
import Publisher "./publications/PublisherManager";
import SubscriptionManager "./subscriptions/SubscriptionManager";
import Types "ICRC72Types";
import Utils "Utils";

actor class ICRC72Broadcaster() = Self {
  
    type EventRelay = {
        id : Nat;
        prevId : ?Nat;
        timestamp : Nat;
        namespace : Text;
        source : Principal;
        data : ICRC16;
        headers : ?ICRC16Map;
    };

    type EventNotification = {
        id : Nat;
        eventId : Nat;
        preEventId : ?Nat;
        timestamp : Nat;
        namespace : Text;
        data : ICRC16;
        source : Principal;
        headers : ?ICRC16Map;
        filter : ?Text;
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

    type ICRC16Map = (Text, ICRC16);

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
  

    type SubscriptionInfo = {
        subscriber : Principal;
        namespace : Text;
        config : [ICRC16Map];
        stats : [ICRC16Map];
    };

    type SubscriberActor = actor {
        icrc72_handle_notification([EventNotification]) : async ();
        icrc72_handle_notification_trusted([EventNotification]) : async [{
            #Ok : Value;
            #Err : Text;
        }];
    };

    let default_publication_config = [("key", #Text("value"))];

    private let subManager = SubscriptionManager.SubscriptionManager();
    private let pubManager = Publisher.PublisherManager();

    // Create event part

    public func createEvent({
        id : Nat;
        namespace : Text;
        source : Principal;
        dataType : Text;
        data : Text;
    }) : async Bool {
        let data_type = switch (dataType) {
            case ("Text") { #Text(data) };
            // TODO other casees like case ("Int") { #Int(Int.fromText(data)) };
            case ("Nat") {
                let n = Option.get(Nat.fromText(data), 0);
                #Nat(n);
            };
            case ("Bool") { if (data == "true") #Bool(true) else #Bool(false) };
            
            case (_) { #Text(data) };
        };
        let event : Types.EventRelay = {
            id = id;
            timestamp = Nat32.toNat(Nat32.fromIntWrap(Time.now()));
            namespace = namespace;
            source = source;
            data = data_type;
            headers = null;
            prevId = null;
        };
        let result = await handleNewEvent(event);
        result[0].1;
    };

    public shared func handleNewEvent(event : Types.EventRelay) : async [(Nat, Bool)] {
        let result_buffer = Buffer.Buffer<(Nat, Bool)>(0);
        let eventFilters = parseNamespace(event.namespace);
        if (eventFilters.size() == 0) {
            return [(0, false)];
        };
        // Get subscribers by filter
        for (filter in eventFilters.vals()) {
            let _principals = await subManager.getSubscribersByNamespace(filter);
            if (_principals.size() == 0) {
                return [(0, false)];
            };
            // Convert Principals to Subscribers
            let _subscribers = Array.map<Principal, Types.Subscriber>(_principals, func(p : Principal) : Types.Subscriber { { subscriber = p; filter = eventFilters } });
            // send event to subscribers
            let publish_result = await pubManager.publishEventToSubscribers(_subscribers, event);
            result_buffer.add(event.id, publish_result.size() > 0);
            // ignore await increasePublicationMessagesSentStats(event.source, event.namespace, "messagesSent");
        };
        Buffer.toArray(result_buffer);
    };

    public func icrc72_publish(events : [Types.EventRelay]) : async [{
        Ok : [Nat];
        Err : [Types.PublishError];
    }] {
        let success_buffer = Buffer.Buffer<Nat>(0);
        let error_buffer = Buffer.Buffer<Types.PublishError>(0);
        for (event in events.vals()) {
            let result = await handleNewEvent(event);
            switch (result[0].1) {
                case (true) {
                    success_buffer.add(result[0].0);
                };
                case (false) {
                    error_buffer.add(#Unauthorized);
                };
            };
        };
        return [{
            Ok = Buffer.toArray(success_buffer);
            Err = Buffer.toArray(error_buffer);
        }];
    };    

    func parseNamespace(namespace : Text) : [Text] {
        let delimiter = #char '.';
        let partsIter = Text.split(namespace, delimiter);
        Iter.toArray(partsIter);
    };

    // Subscription part

    public func createSubscription({
        subscriber : Principal;
        namespace : Text;
        filters : [Text];
        active : Bool;
    }) : async Bool {

        let config : [(Text, Text)] = [("key", "value")];
        let stats : [(Text, Text)] = [("key", "value")];
        let subscription : Types.SubscriptionInfo = {
            subscriber = subscriber;
            namespace = namespace;
            config = [#Text(config[0].1)];
            stats = [#Text(stats[0].1)];
            active = active;
            filters = filters;
            messagesConfirmed = 0;
            messagesReceived = 0;
            messagesRequested = 0;

        };
        await subscribe(subscription);
    };

    public shared func subscribe(subscription : Types.SubscriptionInfo) : async Bool {
        await subManager.icrc72_register_single_subscription(subscription);
    };

    // TODO: add allowlist for getting subscribers by namespace
    public func getSubscribersByNamespace(namespace : Text) : async [Principal] {
        await subManager.getSubscribersByNamespace(namespace);
    };

    // TODO: add allowlist for getting all subscriptions
    public func getSubcriptions() : async [Types.SubscriptionInfo] {
        await subManager.getSubscriptions();
    };

    public shared ({ caller }) func unsubscribeAll(subscriber : Principal) : async () {
        // TODO change to allow list
        if (Principal.equal(caller, subscriber)) {
            await subManager.unsubscribeAll(subscriber);
        };
    };

    public func unsubscribeByNamespace(subscriber : Principal, namespace : Text) : async () {
        await subManager.unsubscribeByNamespace(subscriber, namespace);
    };

	// TODO 
    public func confirm_messages(eventIds : [Nat]) : async [Result.Result<Bool, Text>] {
        // Mark messages as confirmed
        Array.map<Nat, Result.Result<Bool, Text>>(
            eventIds,
            func(id) : Result.Result<Bool, Text> {
                #ok true;
            },
        );
    };

    public func notify_subscribers(event : EventRelay) : async Result.Result<Bool, Text> {
        // Send notification to all subscribers
        Debug.print("notify_subscribers: event: " # Nat.toText(event.id) # " " # event.namespace);
        #ok true;
    };

    func textToICRC16(text : Text) : ICRC16 {
        #Text(text);
    };

    func textArrayToPublicationInfo(stats : [(Text, Text)]) : [Types.PublicationInfo] {
        Array.map<(Text, Text), Types.PublicationInfo>(
            stats,
            func(stat) : Types.PublicationInfo {
                {
                    namespace = stat.0;
                    stats = [(stat.0, textToICRC16(stat.1))];
                };
            },
        );
    };


    // Registers a publication for future using the specified namespace.
    //
    // Arguments:
    // - publisher: The principal of the subscriber.
    // - namespace: The namespace of the publication.
    //
    // Returns:
    // boolean indicating success.
    public func register_publication(
        publisher : Principal,
        namespace : Text,
    ) : async Bool {
        let publication : Types.PublicationRegistration = {
            namespace = namespace;
            config = default_publication_config;
        };
        let res = await pubManager.register_single_publication(publisher, publication);
        res.1;
    };

    public func getPublications(publisher : Principal) : async [Types.PublicationInfo] {
        await pubManager.getPublications(publisher);
    };

    public func getPublishers() : async [Principal] {
        await pubManager.getPublishers();
    };

    public func unregisterPublisher(publisher : Principal) : async Bool {
        await pubManager.unregisterPublisher(publisher);
    };

    public func removePublication(publisher : Principal, namespace : Text) : async Bool {
        await pubManager.removePublication(publisher, namespace);
    };

    //Tests and Ethereum ---------------------------------------------------
    // Tests
    public func test_subc() : async (Bool, Text) {
        let subscriber = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
        let subscription : Types.SubscriptionInfo = {
            namespace = "hackathon.hackathon";
            subscriber = subscriber;
            active = true;
            filters = ["hackathon"];
            messagesReceived = 0;
            messagesRequested = 0;
            messagesConfirmed = 0;
        };

        let result = await subscribe(subscription);
        let subscribersList = await subManager.getSubscribersByNamespace(subscription.namespace);
        Debug.print("Test_subc: subscribersList size: " # Nat.toText(subscribersList.size()));
        (result, subscription.namespace);
    };

    public func test() : async [(Principal, Types.Response)] {
        // register publication and subcsribe using e2e_subscriber canister
        // for this test publisher = subscriber
        let subscriber = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
        let namespace = "hackathon.hackathon";
        let subscription : Types.SubscriptionInfo = {
            namespace = namespace;
            subscriber = subscriber;
            active = true;
            filters = ["hackathon"];
            messagesReceived = 0;
            messagesRequested = 0;
            messagesConfirmed = 0;
        };

        let reg_pub_result = await pubManager.register_publications(
            subscriber,
            [
                {
                    namespace = namespace;
                    config = default_publication_config;
                },
            ],
        );
        Debug.print("test: reg_pub_result: namespace = " # reg_pub_result[0].0 # " , result = " # Bool.toText(reg_pub_result[0].1));
        let sub_result = await subscribe(subscription);
        Debug.print("test: sub_result: " # Bool.toText(sub_result));

        // publish event using e2e_publisher canister
        let event : Types.EventRelay = {
            namespace = namespace;
            source = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
            timestamp = 0;
            data = #Text("fff");
            id = 1;
            headers = null;
            prevId = null;
        };
        let handle_result = await handleNewEvent(event);
        Debug.print("test: handle_result: " # Bool.toText(handle_result[0].1));
        let subscribersList = await subManager.getSubscribersByNamespace(namespace);
        Debug.print("test: subscribersList size: " # Nat.toText(subscribersList.size()));
        let subscribers = Array.map<Principal, Types.Subscriber>(subscribersList, func(p : Principal) : Types.Subscriber { { subscriber = p; filter = [namespace] } });
        for (subscriber in subscribers.vals()) {
            Debug.print("test: subscriber: " # Principal.toText(subscriber.subscriber) # " , filter: " # subscriber.filter[0]);
        };
        // publish to trusted canister
        let publish_result = await pubManager.publishEventWithResponse(subscribers, event); // send event to trusted subscribers
        Debug.print("test: publish_result: ");
        publish_result;
    };

    public func test_hackathon() : async Bool {
        // Create principals for Dev, Broadcaster, and OnLineSchool
        let dev = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
        // let broadcaster = Principal.fromActor(Self);
        let school = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
        // Test Wrong Namespace
        let wrongNamespaceEvent = {
            namespace = "nonexistent.news";
            source = school;
            timestamp = 1;
            data = #Text("This should not be delivered.");
            id = 5;
            headers = null;
            prevId = null;
        };
        let wrongNamespaceResult = await Self.handleNewEvent(wrongNamespaceEvent);
        Debug.print("test_hackathon: Test for wrong namespace event handling: " # Bool.toText(wrongNamespaceResult[0].1));
        assert (not wrongNamespaceResult[0].1);

        // School registers publications
        let school_publications : [Types.PublicationRegistration] = [
            {
                namespace = "school.news";
                config = default_publication_config;
            },
            {
                namespace = "hackathon";
                config = default_publication_config;
            },
        ];

        let result_reg = await pubManager.register_publications(school, school_publications);
        Debug.print("test_hackathon: result_reg: " # result_reg[0].0 # " " # Bool.toText(result_reg[0].1)); // result_reg: school.news true
        let school_sub_result = await Self.subscribe({
            namespace = school_publications[0].namespace;
            subscriber = school;
            active = true;
            filters = ["school.news", "hackathon"];
            messagesReceived = 0;
            messagesRequested = 0;
            messagesConfirmed = 0;
        });
        Debug.print("test_hackathon: school_sub_result: " # Bool.toText(school_sub_result));
        assert school_sub_result == true;

        // Dev registers subscription to school.news
        let dev_sub_result = await Self.subscribe({
            namespace = "school.news";
            subscriber = dev;
            active = true;
            filters = ["school.news"];
            messagesReceived = 0;
            messagesRequested = 0;
            messagesConfirmed = 0;
        });
        Debug.print("test_hackathon: dev_sub_result: " # Bool.toText(dev_sub_result));
        assert dev_sub_result == true;

        // School publishes events to school.news
        let event1 = {
            namespace = "school.news";
            source = school;
            timestamp = 1;
            data = #Text("Hackathon announced! Get ready for coding challenges and prizes!");
            id = 1;
            headers = null;
            prevId = null;
        };
        let event2 = {
            namespace = school_publications[1].namespace;
            source = school;
            timestamp = 1;
            data = #Text("Hackathon registration is now open!");
            id = 2;
            headers = null;
            prevId = null;
        };
        let handle_event1 = await Self.handleNewEvent(event1);
        Debug.print("test_hackathon: handle_event1: " # Nat.toText(handle_event1[0].0));
        let handle_event2 = await Self.handleNewEvent(event2);
        Debug.print("test_hackathon: handle_event2: " # Nat.toText(handle_event2[0].0));

        // School registers subscription to school.hackathon
        let school_sub_result2 = await Self.subscribe({
            namespace = school_publications[1].namespace;
            subscriber = school;
            active = true;
            filters = ["hackathon"];
            messagesReceived = 0;
            messagesRequested = 0;
            messagesConfirmed = 0;
        });
        Debug.print("test_hackathon: school_sub_result2: " # Bool.toText(school_sub_result));
        assert school_sub_result2 == true;

        // Dev registers publication to dev.hackathon
        let dev_reg_pub_result = await pubManager.register_publications(dev, [{ namespace = "hackathon"; config = default_publication_config }]);
        Debug.print("test_hackathon: dev_reg_pub_result: " # Bool.toText(dev_reg_pub_result[0].1) # " namespace " # dev_reg_pub_result[0].0);
        let dev_sub_result2 = await Self.subscribe({
            namespace = "hackathon";
            subscriber = dev;
            active = true;
            filters = ["hackathon"];
            messagesReceived = 0;
            messagesRequested = 0;
            messagesConfirmed = 0;
        });
        Debug.print("test_hackathon: dev_sub_result: " # Bool.toText(dev_sub_result2));
        assert dev_sub_result2 == true;

        // Dev publishes event to dev.hackathon
        let event3 = {
            namespace = "hackathon";
            source = dev;
            timestamp = 1;
            data = #Text("I'm registering for the hackathon!");
            id = 3;
            headers = null;
            prevId = null;
        };
        let event3_result = await Self.handleNewEvent(event3);
        Debug.print("test_hackathon: event3_result: " # Nat.toText(event3_result[0].0));
        assert event3_result[0].1 == true;

        // School publishes final event to school.news
        let event4 = {
            namespace = "hackathon";
            source = school;
            timestamp = 1;
            data = #Text("Hackathon results are in! Congratulations to all participants.");
            id = 4;
            headers = null;
            prevId = null;
        };
        let handle_event3 = await Self.handleNewEvent(event4);
        Debug.print("test_hackathon: handle_event3: " # Nat.toText(handle_event3[0].0));
        assert (handle_event3[0].1 == true);
        // All assertions passed
        return true;
    };

    //-----------------------------------------------------------------------------
    // Ethereum Event Sender

    public func ethTest() : async (Text) {
        let source = #EthMainnet(?[#Cloudflare]);
        let config = ?{ responseSizeEstimate = ?Nat64.fromNat(2000) };
        let getLogArgs = {
            addresses = ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"];
            fromBlock : ?T.BlockTag = ? #Number(19188367);
            toBlock : ?T.BlockTag = ? #Number(19188367);
            topics = ?[["0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c", "0x0000000000000000000000003fc91a3afd70395cd496c647d5a6cc9d4b2b7fad"]];
        };
        let result = await EthSender.eth_getLogs(source, config, getLogArgs, 2000000000);
        switch (result) {
            case (#Consistent(_)) {
                Debug.print("ethTest: Ok. Consistent response from EthMainnet, block 19188367");
                return "ethTest: Ok. Consistent response from EthMainnet, block 19188367";
            };
            case (_) {
                Debug.print("ethTest: Inconsistent");
                "ethTest: Inconsistent";
            };
        };
    };

    public func requestCost(source : T.RpcService, jsonRequest : Text, maxResponseBytes : Nat) : async Nat {
        await EthSender.requestCost(source, jsonRequest, Nat64.fromNat(maxResponseBytes));
    };

    public func getEthLogs(source_text : Text, provider : Text, config_text : Nat, addresses : [Text], blockTagFrom : Text, fromBlock : Nat, blockTagTo : Text, toBlock : Nat, topics : [Text], cycles : Nat) : async () {
        let source = parseRpcSource(source_text, provider);
        let config = parseRpcConfig(config_text);
        let getLogArgs = parseGetLogsArgs(addresses, blockTagFrom, fromBlock, blockTagTo, toBlock, topics);
        Debug.print("getEthLogs: source: " # source_text # " , provider: " # provider # " , config: " # Nat.toText(config_text) # " , addresses: " # addresses[0] # " , blockTag: " # blockTagFrom # " , fromBlock: " # Nat.toText(fromBlock) # " , toBlock: " # Nat.toText(toBlock) # " , topics: " # topics[0]);
        // TODO result handling
        let result = await EthSender.eth_getLogs(source, config, getLogArgs, cycles);
        switch (result) {
            case (#Consistent(_)) {
                Debug.print("getEthLogs: Consistent");
            };
            case (_) {
                Debug.print("getEthLogs: Inconsistent");
            };
        };

        return;
    };

    func parseRpcSource(source_text : Text, provider : Text) : T.RpcSources {
        if (source_text == "Sepolia") {
            return #EthSepolia(?[parseEthSepoliaService(provider)]);
        } else if (source_text == "Mainnet") {
            return #EthMainnet(?[parseEthMainnetService(provider)]);
        } else {
            return #EthSepolia(?[#Alchemy]);
        };

    };

    func parseRpcConfig(config : Nat) : ?T.RpcConfig {
        ?{ responseSizeEstimate = ?Nat64.fromNat(config) };
    };

    func parseGetLogsArgs(addresses : [Text], blockTagFrom : Text, fromBlock : Nat, blockTagTo : Text, toBlock : Nat, topics : [Text]) : T.GetLogsArgs {
        {
            addresses = addresses;
            fromBlock = parseBlockTag(blockTagFrom, fromBlock);
            toBlock = parseBlockTag(blockTagTo, toBlock);
            topics = ?[topics];
        };
    };

    func parseBlockTag(blockTag : Text, number : Nat) : ?T.BlockTag {
        switch (blockTag) {
            case ("Earliest") { return ? #Earliest };
            case ("Safe") { return ? #Safe };
            case ("Finalized") { return ? #Finalized };
            case ("Latest") { return ? #Latest };
            case ("Pending") { return ? #Pending };
            case ("Number") {
                return ? #Number(number);
            };
            case (_) { return null };
        };
    };

    func parseEthSepoliaService(service : Text) : T.EthSepoliaService {
        switch (service) {
            case ("Alchemy") { return #Alchemy };
            case ("BlockPi") { return #BlockPi };
            case ("PublicNode") { return #PublicNode };
            case ("Ankr") { return #Ankr };
            case (_) { return #Alchemy };
        };
    };

    func parseEthMainnetService(service : Text) : T.EthMainnetService {
        switch (service) {
            case ("Alchemy") { return #Alchemy };
            case ("BlockPi") { return #BlockPi };
            case ("Cloudflare") { return #Cloudflare };
            case ("PublicNode") { return #PublicNode };
            case ("Ankr") { return #Ankr };
            case (_) { return #Alchemy };
        };
    };
};
