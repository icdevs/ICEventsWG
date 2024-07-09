import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
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

import AllowListManager "./allowlist/AllowListManager";
import BalanceManager "./balance/BalanceManager";
import T "./EthTypes";
import EthSender "./EventSender";
import Publisher "./publications/PublisherManager";
import SubscriptionManager "./subscriptions/SubscriptionManager";
import Types "ICRC72Types";
import Utils "Utils";

actor class ICRC72Broadcaster() = Self {

    // recieved messages by source
    type Source = Principal;
    private var messagesMap = HashMap.HashMap<Source, [Types.EventNotification]>(10, Principal.equal, Principal.hash);

    type SubscriberActor = actor {
        icrc72_handle_notification([Types.EventNotification]) : async ();
        icrc72_handle_notification_trusted([Types.EventNotification]) : async [{
            #Ok : Types.Value;
            #Err : Text;
        }];
    };

    let default_publication_config = [("key", #Text("value"))];

    var eventHubBalance = "event.hub.balance";

    private let subManager = SubscriptionManager.SubscriptionManager();
    private let pubManager = Publisher.PublisherManager();
    // TODO
    private let allowlist = AllowListManager.AllowListManager();
    // For DAO token support
    private let balanceManager = BalanceManager.BalanceManager();

    // init allowlist on startup
    var initialized = false;

    system func timer(setGlobalTimer : Nat64 -> ()) : async () {
        if (not initialized) {
            let deployer = Principal.fromActor(Self);

            await allowlist.initAllowlist(deployer);
            await pubManager.init(deployer);

            initialized := true;
        };
    };

    public shared (msg) func setBalanceLedgerCanisterId(ledgerCanisterId : Text) : async Bool {
        if (Principal.isController(msg.caller)) {
            return await balanceManager.setBalanceLedgerCanisterId(ledgerCanisterId);
        };
        false;
    };

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
            // case ("Int") { #Int(Int.fromText(data)) };
            case ("Nat") {
                let n = Option.get(Nat.fromText(data), 0);
                #Nat(n);
            };
            case ("Bool") { if (data == "true") #Bool(true) else #Bool(false) };
            // case ("Float") { #Float(Float.fromText(data)) };
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

        // Get all subscriptions for this event
        let subscriptions = await subManager.getSubscriptionsByNamespace(event.namespace);

        if (subscriptions.size() == 0) {
            return [(0, false)];
        };

        for (subscription in subscriptions.vals()) {
            if (subscription.active) {
                let matchesFilter = checkFilters(event.namespace, subscription.filters);

                if (matchesFilter) {
                    let subscriber : Types.Subscriber = {
                        subscriber = subscription.subscriber;
                        filter = subscription.filters;
                    };

                    //Publish event
                    let publish_result = await pubManager.publishEventToSubscribers([subscriber], event);
                    result_buffer.add(event.id, publish_result.size() > 0);

                    // Stats
                };
            };
        };

        Buffer.toArray(result_buffer);
    };

    func checkFilters(namespace : Text, filters : [Text]) : Bool {
        // TODO Add support for dot-split namespace and filter matching
        for (filter in filters.vals()) {
            if (Text.equal(namespace, filter)) {
                return true;
            };
        };
        false;
    };

    public func icrc72_publish(events : [Types.EventRelay]) : async [{
        Ok : [Nat];
        Err : [Types.PublishError];
    }] {
        // TODO check balance
        // TODO check allowlist
        // TODO check if event is valid
        // TODO check if event is already published
        // TODO check if event is expired
        // TODO check if event is already in the queue

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

    public shared func icrc72_register_subscription(subscription : [Types.SubscriptionInfo]) : async [(Types.SubscriptionInfo, Bool)] {
        await subManager.icrc72_register_subscription(subscription);
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

    public func confirm_messages(eventIds : [Nat]) : async [Result.Result<Bool, Text>] {
        // Mark messages as confirmed
        Array.map<Nat, Result.Result<Bool, Text>>(
            eventIds,
            func(id) : Result.Result<Bool, Text> {
                #ok true;
            },
        );
    };

    func textToICRC16(text : Text) : Types.ICRC16 {
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

    // // Subscription handling

    public func icrc72_handle_notification(messages : [Types.EventNotification]) : async () {
        for (message in messages.vals()) {
            // eventHubBalance namespace handling
            if (message.namespace == eventHubBalance) {
                switch (message.data) {
                    case (#Map(data)) {
                        var newBalance : ?Nat = null;
                        var user : ?Text = null;

                        for ((key, value) in data.vals()) {
                            switch (key, value) {
                                case ("balance", #Nat(balance)) newBalance := ?balance;
                                case ("user", #Text(userText)) user := ?userText;
                                case _ {}; // Ignore other keys
                            };
                        };

                        switch (newBalance, user) {
                            case (?balance, ?userText) {
                                if (userText == Principal.toText(Principal.fromActor(Self))) {
                                    ignore await updateBalance(Principal.fromActor(Self), balance);
                                };
                            };
                            case _ {
                                // Missing balance or user data in the message
                                Debug.print("Error: Missing balance or user data in the message");
                            };
                        };
                    };
                    case _ {
                        // Incorrect data format
                        Debug.print("Error: Incorrect data format in the message");
                    };
                };
            };

            let existingMessage = messagesMap.get(message.source);
            switch (existingMessage) {
                case (null) messagesMap.put(message.source, [message]);
                case (?m) {
                    let newMessages = Utils.pushIntoArray<Types.EventNotification>(message, m);
                    messagesMap.put(message.source, newMessages);
                };
            };
        };
    };

    public func icrc72_handle_notification_trusted(messages : [Types.EventNotification]) : async [Result.Result<Bool, Text>] {
        for (message in messages.vals()) {
            let existingMessage = messagesMap.get(message.source);
            switch (existingMessage) {
                case (null) messagesMap.put(message.source, [message]);
                case (?m) {
                    let newMessages = Utils.pushIntoArray(message, m);
                    messagesMap.put(message.source, newMessages);
                };
            };
        };
        Array.map<Types.EventNotification, Result.Result<Bool, Text>>(
            messages,
            func(message) : Result.Result<Bool, Text> {
                #ok true;
            },
        );
    };

    public shared (msg) func getReceivedMessages() : async Result.Result<[(Principal, [Types.EventNotification])], Text> {
        // if (not Principal.isController(msg.caller)) return #err("Only controller can call this method");
        let res = Iter.toArray(messagesMap.entries());
        #ok res;
    };

    public shared (msg) func getReceivedMessagesBySource(source : Text) : async Result.Result<[Types.EventNotification], Text> {
        // if (not Principal.isController(msg.caller)) return #err("Only controller can call this method");

        let publisher = Principal.fromText(source);
        let messages = messagesMap.get(publisher);
        switch (messages) {
            case (null) #ok([]);
            case (?m) #ok m;
        };
    };

    public func getReceivedMessagesByNamespace(namespace : Text) : async [Types.EventNotification] {
        var resultMap = HashMap.HashMap<Types.EventNotification, Null>(
            0,
            func(x : Types.EventNotification, y : Types.EventNotification) : Bool {
                x.timestamp == y.timestamp and x.namespace == y.namespace
            },
            func(x : Types.EventNotification) : Hash.Hash {
                let namespaceHash = Text.hash(namespace);
                let timestampHash = Hash.hash(x.timestamp);
                return namespaceHash ^ timestampHash;
            },
        );
        for (messages in messagesMap.vals()) {
            for (message in messages.vals()) {
                if (message.namespace == namespace) {
                    resultMap.put(message, null);
                };
            };
        };

        Iter.toArray(resultMap.keys());
    };

    public shared (msg) func removeAllMessages(messages : [Types.EventNotification]) : async Result.Result<Nat, Text> {
        if (not Principal.isController(msg.caller)) return #err("Only controller can remove all notifications");
        messagesMap := HashMap.HashMap<Principal, [Types.EventNotification]>(10, Principal.equal, Principal.hash);
        #ok 0;
    };

    public shared (msg) func removeAllMessagesBySource(source : Text) : async Result.Result<Bool, Text> {
        if (not Principal.isController(msg.caller)) return #err("Only controller can remove notifications");
        let publisher = Principal.fromText(source);
        switch (messagesMap.get(publisher)) {
            case (null) {
                #err("No messages for source: " # source);
            };
            case (?messages) {
                ignore messagesMap.remove(publisher);
                #ok true;
            };
        };
    };

    // ----------------------------------------------------------------------------
    // Balance
    // For DAO token balance management
    private func updateBalance(user : Principal, balance : Nat) : async Result.Result<Nat, Text> {
        ignore await balanceManager.updateBalance(user, balance);
        #ok(await balanceManager.getBalance(user));
    };
    //-----------------------------------------------------------------------------
    // Stable Upgrade Canister Part

    stable var messagesStore : [(Principal, [Types.EventNotification])] = [];
    // TODO add local copy of subscriptionStore, publicationStore, allowlistStore
    // stable var subscriptionStore : [(Principal, [Types.SubscriptionInfo])] = [];
    // stable var publicationStore : [(Principal, [Types.PublicationInfo])] = [];
    // stable var allowlistStore : [(Principal, Types.Permission)] = [];

    system func preupgrade() {
        messagesStore := Iter.toArray(messagesMap.entries());
        // TODO add local copy of subscriptionStore, publicationStore, allowlistStore
        // subscriptionStore := getSubcriptionsState();
        // publicationStore := await pubManager.getAllPublications();
        // allowlistStore := await allowlist.getAllowlist();

        // TODO other stats (events, etc)
    };

    system func postupgrade() {
        for (entry in messagesStore.vals()) {
            messagesMap.put(entry.0, entry.1);
        };
        messagesStore := [];

        // subManager.initStore(subscriptionStore);
        // subscriptionStore := [];

        // pubManager.initStore(publicationStore);
        // publicationStore := [];

        // allowlist.initStore(allowlistStore);
        // allowlistStore := [];
        // TODO other states
    };

    //-----------------------------------------------------------------------------
    // Registers a publication for a subscriber in the specified namespace.
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

    //----------------------------------------------------------------------------------------
    // Tests
    // public func test_subc() : async (Bool, Text) {
    //     let subscriber = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
    //     let subscription : Types.SubscriptionInfo = {
    //         namespace = "hackathon.hackathon";
    //         subscriber = subscriber;
    //         active = true;
    //         filters = ["hackathon"];
    //         messagesReceived = 0;
    //         messagesRequested = 0;
    //         messagesConfirmed = 0;
    //     };

    //     let result = await subscribe(subscription);
    //     let subscribersList = await subManager.getSubscribersByNamespace(subscription.namespace);
    //     Debug.print("Test_subc: subscribersList size: " # Nat.toText(subscribersList.size()));
    //     (result, subscription.namespace);
    // };

    // public func test() : async [(Principal, Types.Response)] {
    //     // register publication and subcsribe using e2e_subscriber canister
    //     // for this test publisher = subscriber
    //     let subscriber = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
    //     let namespace = "hackathon.hackathon";
    //     let subscription : Types.SubscriptionInfo = {
    //         namespace = namespace;
    //         subscriber = subscriber;
    //         active = true;
    //         filters = ["hackathon"];
    //         messagesReceived = 0;
    //         messagesRequested = 0;
    //         messagesConfirmed = 0;
    //     };

    //     let reg_pub_result = await pubManager.register_publications(
    //         subscriber,
    //         [
    //             {
    //                 namespace = namespace;
    //                 config = default_publication_config;
    //             },
    //         ],
    //     );
    //     Debug.print("test: reg_pub_result: namespace = " # reg_pub_result[0].0 # " , result = " # Bool.toText(reg_pub_result[0].1));
    //     let sub_result = await subscribe(subscription);
    //     Debug.print("test: sub_result: " # Bool.toText(sub_result));

    //     // publish event using e2e_publisher canister
    //     let event : Types.EventRelay = {
    //         namespace = namespace;
    //         source = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
    //         timestamp = 0;
    //         data = #Text("fff");
    //         id = 1;
    //         headers = null;
    //         prevId = null;
    //     };
    //     let handle_result = await handleNewEvent(event);
    //     Debug.print("test: handle_result: " # Bool.toText(handle_result[0].1));
    //     let subscribersList = await subManager.getSubscribersByNamespace(namespace);
    //     Debug.print("test: subscribersList size: " # Nat.toText(subscribersList.size()));
    //     let subscribers = Array.map<Principal, Types.Subscriber>(subscribersList, func(p : Principal) : Types.Subscriber { { subscriber = p; filter = [namespace] } });
    //     for (subscriber in subscribers.vals()) {
    //         Debug.print("test: subscriber: " # Principal.toText(subscriber.subscriber) # " , filter: " # subscriber.filter[0]);
    //     };
    //     // publish to trusted canister
    //     let publish_result = await pubManager.publishEventWithResponse(subscribers, event); // send event to trusted subscribers
    //     Debug.print("test: publish_result: ");
    //     publish_result;
    // };

    // public func test_hackathon() : async Bool {
    //     // Create principals for Dev, Broadcaster, and OnLineSchool
    //     let dev = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
    //     // let broadcaster = Principal.fromActor(Self);
    //     let school = Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai");
    //     // Test Wrong Namespace
    //     let wrongNamespaceEvent = {
    //         namespace = "nonexistent.news";
    //         source = school;
    //         timestamp = 1;
    //         data = #Text("This should not be delivered.");
    //         id = 5;
    //         headers = null;
    //         prevId = null;
    //     };
    //     let wrongNamespaceResult = await Self.handleNewEvent(wrongNamespaceEvent);
    //     Debug.print("test_hackathon: Test for wrong namespace event handling: " # Bool.toText(wrongNamespaceResult[0].1));
    //     assert (not wrongNamespaceResult[0].1);

    //     // School registers publications
    //     let school_publications : [Types.PublicationRegistration] = [
    //         {
    //             namespace = "school.news";
    //             config = default_publication_config;
    //         },
    //         {
    //             namespace = "hackathon";
    //             config = default_publication_config;
    //         },
    //     ];

    //     let result_reg = await pubManager.register_publications(school, school_publications);
    //     Debug.print("test_hackathon: result_reg: " # result_reg[0].0 # " " # Bool.toText(result_reg[0].1)); // result_reg: school.news true
    //     let school_sub_result = await Self.subscribe({
    //         namespace = school_publications[0].namespace;
    //         subscriber = school;
    //         active = true;
    //         filters = ["school.news", "hackathon"];
    //         messagesReceived = 0;
    //         messagesRequested = 0;
    //         messagesConfirmed = 0;
    //     });
    //     Debug.print("test_hackathon: school_sub_result: " # Bool.toText(school_sub_result));
    //     assert school_sub_result == true;

    //     // Dev registers subscription to school.news
    //     let dev_sub_result = await Self.subscribe({
    //         namespace = "school.news";
    //         subscriber = dev;
    //         active = true;
    //         filters = ["school.news"];
    //         messagesReceived = 0;
    //         messagesRequested = 0;
    //         messagesConfirmed = 0;
    //     });
    //     Debug.print("test_hackathon: dev_sub_result: " # Bool.toText(dev_sub_result));
    //     assert dev_sub_result == true;

    //     // School publishes events to school.news
    //     let event1 = {
    //         namespace = "school.news";
    //         source = school;
    //         timestamp = 1;
    //         data = #Text("Hackathon announced! Get ready for coding challenges and prizes!");
    //         id = 1;
    //         headers = null;
    //         prevId = null;
    //     };
    //     let event2 = {
    //         namespace = school_publications[1].namespace;
    //         source = school;
    //         timestamp = 1;
    //         data = #Text("Hackathon registration is now open!");
    //         id = 2;
    //         headers = null;
    //         prevId = null;
    //     };
    //     let handle_event1 = await Self.handleNewEvent(event1);
    //     Debug.print("test_hackathon: handle_event1: " # Nat.toText(handle_event1[0].0));
    //     let handle_event2 = await Self.handleNewEvent(event2);
    //     Debug.print("test_hackathon: handle_event2: " # Nat.toText(handle_event2[0].0));

    //     // School registers subscription to school.hackathon
    //     let school_sub_result2 = await Self.subscribe({
    //         namespace = school_publications[1].namespace;
    //         subscriber = school;
    //         active = true;
    //         filters = ["hackathon"];
    //         messagesReceived = 0;
    //         messagesRequested = 0;
    //         messagesConfirmed = 0;
    //     });
    //     Debug.print("test_hackathon: school_sub_result2: " # Bool.toText(school_sub_result));
    //     assert school_sub_result2 == true;

    //     // Dev registers publication to dev.hackathon
    //     let dev_reg_pub_result = await pubManager.register_publications(dev, [{ namespace = "hackathon"; config = default_publication_config }]);
    //     Debug.print("test_hackathon: dev_reg_pub_result: " # Bool.toText(dev_reg_pub_result[0].1) # " namespace " # dev_reg_pub_result[0].0);
    //     let dev_sub_result2 = await Self.subscribe({
    //         namespace = "hackathon";
    //         subscriber = dev;
    //         active = true;
    //         filters = ["hackathon"];
    //         messagesReceived = 0;
    //         messagesRequested = 0;
    //         messagesConfirmed = 0;
    //     });
    //     Debug.print("test_hackathon: dev_sub_result: " # Bool.toText(dev_sub_result2));
    //     assert dev_sub_result2 == true;

    //     // Dev publishes event to dev.hackathon
    //     let event3 = {
    //         namespace = "hackathon";
    //         source = dev;
    //         timestamp = 1;
    //         data = #Text("I'm registering for the hackathon!");
    //         id = 3;
    //         headers = null;
    //         prevId = null;
    //     };
    //     let event3_result = await Self.handleNewEvent(event3);
    //     Debug.print("test_hackathon: event3_result: " # Nat.toText(event3_result[0].0));
    //     assert event3_result[0].1 == true;

    //     // School publishes final event to school.news
    //     let event4 = {
    //         namespace = "hackathon";
    //         source = school;
    //         timestamp = 1;
    //         data = #Text("Hackathon results are in! Congratulations to all participants.");
    //         id = 4;
    //         headers = null;
    //         prevId = null;
    //     };
    //     let handle_event3 = await Self.handleNewEvent(event4);
    //     Debug.print("test_hackathon: handle_event3: " # Nat.toText(handle_event3[0].0));
    //     assert (handle_event3[0].1 == true);
    //     // All assertions passed
    //     return true;
    // };

    //-----------------------------------------------------------------------------
    // Ethereum Event Sender

    // public func ethTest() : async (Text) {
    //     let source = #EthMainnet(?[#Cloudflare]);
    //     let config = ?{ responseSizeEstimate = ?Nat64.fromNat(2000) };
    //     let getLogArgs = {
    //         addresses = ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"];
    //         fromBlock : ?T.BlockTag = ? #Number(19188367);
    //         toBlock : ?T.BlockTag = ? #Number(19188367);
    //         topics = ?[["0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c", "0x0000000000000000000000003fc91a3afd70395cd496c647d5a6cc9d4b2b7fad"]];
    //     };
    //     let result = await EthSender.eth_getLogs(source, config, getLogArgs, 2000000000);
    //     switch (result) {
    //         case (#Consistent(_)) {
    //             Debug.print("ethTest: Ok. Consistent response from EthMainnet, block 19188367");
    //             return "ethTest: Ok. Consistent response from EthMainnet, block 19188367";
    //         };
    //         case (_) {
    //             Debug.print("ethTest: Inconsistent");
    //             "ethTest: Inconsistent";
    //         };
    //     };
    // };

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
