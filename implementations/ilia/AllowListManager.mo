import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Hash "mo:base/Hash";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import T "../ICRC72Types";
import SubscriptionManager "../subscriptions/SubscriptionManager";
import BalanceManager "../balance/BalanceManager";

module {
    public class AllowListManager() = Self {
        type Set<T> = HashMap.HashMap<T, Null>;

        type UserPermission = (Principal, T.Permission);

        var _deployer = Principal.fromText("aaaaa-aa");
        var _initialized = false;

        let balanceManager = BalanceManager.BalanceManager();

        public func initAllowlist(deployer : Principal) : async () {
            let initResult = await setDeployer(deployer);
            switch (initResult) {
                case (#ok(t)) {};
                case (#err(e)) { Debug.print("Failed to initialize allowlist") };
            };
            // create subscription to get $EVENT balance updates
            let subManager = SubscriptionManager.SubscriptionManager();
            let subscription : T.SubscriptionInfo = {
                namespace = "event.hub.event.balance";
                filters = ["balance.update"];
                active = true;
                subscriber = _deployer;
                messagesReceived = 0;
                messagesRequested = 0;
                messagesConfirmed = 0;
            };
            let create_subscription = await subManager.icrc72_register_single_subscription(subscription);
            if (not create_subscription) {
                Debug.print("Failed to create subscription");
            };

            // On $EVENT balance updates, add user to allowlist

            Debug.print("Initialized allowlist successfully");
        };

        private func setDeployer(deployer : Principal) : async Result.Result<Text, Text> {
            if (not _initialized) {
                _deployer := deployer;
                _initialized := true;
                return #ok("Deployer set to " # Principal.toText(deployer));
            } else {
                if (Principal.equal(deployer, _deployer)) {
                    _deployer := deployer;
                    return #ok("Deployer set to " # Principal.toText(deployer));
                };
            };
            #err("Do not allow change of deployer");
        };

        private var allowList : Set<UserPermission> = HashMap.HashMap<UserPermission, Null>(
            10,
            func(x : UserPermission, y : UserPermission) : Bool {
                return x == y; // Compare both Principal and Permission
            },
            func(x : UserPermission) : Hash.Hash {
                let principalHash = Principal.hash(x.0);
                let permissionHash = switch (x.1) {
                    case (#Admin) 1;
                    case (#Read) 2;
                    case (#Write) 3;
                };
                return principalHash ^ (Hash.hash(permissionHash) >> 1);
            },
        );

        public func initStore(store : [(Principal, T.Permission)]) {
            for ((principal, permission) in store.vals()) {
                allowList.put((principal, permission), null);
            };
        };

        // TODO Replace logic to checking $Event balance
        public func addToAllowList(user : Principal, permission : T.Permission) : async Result.Result<Bool, Text> {
            let balance = await balanceManager.getBalance(user);

            if (Principal.equal(user, _deployer) and balance > 0) {
                allowList.put((user, permission), null);
                return #ok true;
            } else if (balance > 0) {
                return #err("User balance is insufficient: " # Nat.toText(balance));
            } else {
                return #err "Not authorized";
            };
        };

        public func isUserInAllowList(user : Principal, permission : T.Permission) : async Bool {
            switch (allowList.get((user, permission))) {
                case (?_) true;
                case null {
                    let balance = await balanceManager.getBalance(user);
                    if (balance > 0) {
                        allowList.put((user, permission), null);
                        return true;
                    } else return false;
                };
            };
        };

        public func getAllowList() : async [UserPermission] {
            return Iter.toArray(allowList.keys());
        };

        public func test() : async (Bool, Bool) {
            let user1 = Principal.fromText("mls5s-5qaaa-aaaal-qi6rq-cai");
            let user2 = Principal.fromText("aaaaa-aa");
            let user3 = Principal.fromText("mmt3g-qiaaa-aaaal-qi6ra-cai");

            allowList.put((user1, #Admin), null);
            allowList.put((user2, #Read), null);
            allowList.put((user3, #Write), null);

            let isUser1Admin = await isUserInAllowList(user1, #Admin); //  true
            let isUser3Writer = await isUserInAllowList(user3, #Read); //  false
            return (isUser1Admin, isUser3Writer);
        };
    };
};
