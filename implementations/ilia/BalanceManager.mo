import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {
    public class BalanceManager() = Self {
        private type Balance = Nat;
        private type UserId = Principal;
        private var balances = HashMap.HashMap<UserId, Balance>(
            0,
            Principal.equal,
            Principal.hash,
        );
        type Ledger = actor {
            getBalance(UserId) : async Balance;
        };

        var balanceLedgerId = "2xdbt-dqaaa-aaaal-ajkja-cai";

        public func initBalance(userId : UserId) : async () {
            // TODO get from balance ledger
            /*
            let balanceLedger : Ledger = actor(balanceLedgerId);
            let newBalance = await balanceLedger.getBalance(userId);
            */
            let newBalance = 10;
            balances.put(userId, newBalance);
        };

        public func getBalance(userId : UserId) : async Balance {
            switch (balances.get(userId)) {
                case null {
                    await initBalance(userId);
                    return 0;
                };
                case (?balance) return balance;
            };
        };

        public func updateBalance(userId : UserId, newBalance : Balance) : async Nat {
            balances.put(userId, newBalance);
            await getBalance(userId);
            //emitBalanceUpdatedEvent(userId, newBalance);
        };

        public func setBalanceLedgerCanisterId(newBalanceLedgerId : Text) : async Bool {
            balanceLedgerId := newBalanceLedgerId;
            true;
        };

        // public func emitBalanceUpdatedEvent(userId : UserId, newBalance : Balance) {
        //     // TODO
        // };
    };
};
