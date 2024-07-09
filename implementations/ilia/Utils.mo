import Blob "mo:base/Blob";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import T "./ICRC72Types";

module {
    public func getValueFromValue(key : Text, value : ?[(Text, T.Value)]) : ?T.Value {
        switch (value) {
            case (null) { null };
            case (?entries) {
                for ((k, value) in entries.vals()) {
                    if (k == key) {
                        return ?value;
                    };
                };
                null;
            };
        };
    };

    public func getNat8ValueFromValue(value : ?T.Value) : Nat8 {
        switch (value) {
            case (null) { 0 };
            case (?v) {
                switch (v) {
                    case (#Nat8(n)) {
                        return n;
                    };
                    case (#Nat(n)) {
                        return Nat8.fromNat(n);
                    };
                    case (#Blob(b)) { Blob.toArray(b)[0] };
                    case (#Bool(_)) { 0 };
                    case (#Int(n)) { Nat8.fromIntWrap(n) };
                    case (#Text(t)) {
                        Nat8.fromNat(Option.get<Nat>(Nat.fromText(t), 0));
                    };
                    case (#Map(map)) {
                        if (map.size() > 0) {
                            getNat8ValueFromValue(?map.get(0).1);
                        } else 0;
                    };
                    case (#Array(arr)) {
                        if (arr.size() > 0) {
                            getNat8ValueFromValue(?arr[0]);
                        } else 0;
                    };
                };

            };
        };
    };

    public func getTextValueFromValue(value : ?T.Value) : Text {
        switch (value) {
            case (null) { "" };
            case (?v) {
                switch (v) {
                    case (#Nat(_)) { "" };
                    case (#Nat8(_)) { "" };
                    case (#Blob(_)) { "" };
                    case (#Bool(_)) { "" };
                    case (#Int(_)) { "" };
                    case (#Map(map)) {
                        var result : Text = "";
                        for ((k, v) in map.vals()) {
                            result := result # " " # k # ":" #getTextValueFromValue(?v);
                        };
                        result;
                    };
                    case (#Array(arr)) {
                        var result : Text = "";
                        for (value in arr.vals()) {
                            result := result # " " # getTextValueFromValue(?value);
                        };
                        result;
                    };
                    case (#Text(t)) { t };
                };

            };
        };
    };

    // convert timestamp from Int to date

    public func timestampToDate() : Text {
        let start2024 = Time.now() - 1_704_067_200_000_000_000;
        let seconds = start2024 / 1_000_000_000;
        let minutes = Int.div(seconds, 60);
        let hours = Int.div(minutes, 60);
        let days = Int.div(hours, 24);

        let secondsInMinute = seconds % 60;
        let minutesInHour = minutes % 60;
        let hoursInDay = hours % 24;

        let years = Int.div(days, 365);
        let year = years + 2024;
        var remainingDays = days - (years * 365);

        let monthDays = if (isLeapYear(year)) {
            [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        } else { [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] };
        var month = 1;
        label l for (i in monthDays.vals()) {
            if (remainingDays < i) break l;
            remainingDays -= i;
            month += 1;
        };

        let day = remainingDays + 1;

        return Int.toText(year) # "-" # Int.toText(month) # "-"
        # Int.toText(day) # " " # Int.toText(hoursInDay) # ":"
        # Int.toText(minutesInHour) # ":" # Int.toText(secondsInMinute);
    };

    public func pushIntoArray<X>(elem : X, array : [X]) : [X] {
        let buffer = Buffer.fromArray<X>(array);
        buffer.add(elem);
        return Buffer.toArray(buffer);
    };

    public func appendArray<X>(array1 : [X], array2 : [X]) : [X] {
        let buffer1 = Buffer.fromArray<X>(array1);
        let buffer2 = Buffer.fromArray<X>(array2);
        buffer1.append(buffer2);
        Buffer.toArray(buffer1);
    };

    public func removeFromArray<X>(elem : X, array : [X], x_equal : (X, X) -> Bool) : [X] {
        let index = Array.indexOf<X>(elem, array, x_equal);
        switch (index) {
            case null return array;
            case (?i) {
                let buffer = Buffer.fromArray<X>(array);
                ignore buffer.remove(i);
                return Buffer.toArray(buffer);
            };
        };
    };

    // For <SFFNNNGGG> cifer
    public func convertCiferToDottedFormat(cifer : Text) : Text {
        let chars = Text.toArray(cifer);
        let s = Text.fromChar(chars[0]);
        let ff = Text.fromChar(chars[1]) # Text.fromChar(chars[2]);
        let nnn = Text.fromChar(chars[3]) # Text.fromChar(chars[4]) # Text.fromChar(chars[5]);
        let ggg = Text.fromChar(chars[6]) # Text.fromChar(chars[7]) # Text.fromChar(chars[8]);
        return Text.join(".", [s, ff, nnn, ggg].vals());
    };
    // convert Event topics to Ethereum event topics
    // public func convertEventTopicsToEthereumTopics(eventTopics : [T.EventFilter]) : [Blob] {
    //     let topics = Buffer.Buffer<Blob>(eventTopics.size());
    //     for (i in eventTopics.vals()) {
    //         topics.add(i.value);
    //     };
    //     return Buffer.toArray(topics);
    // };

    public func convertEventMetadataToBlob(metadata : [(Text, T.Value)]) : Blob {
        let buffer = Buffer.Buffer<Blob>(metadata.size());
        for (i in metadata.vals()) {
            let key = Text.encodeUtf8(i.0);
            let value = blobFromValue(i.1);
            buffer.add(key);
            buffer.add(value);
        };
        return bufferToBlob(buffer);
    };

    func blobFromValue(value : T.Value) : Blob {
        switch (value) {
            case (#Nat(n)) {
                Blob.fromArray([Nat8.fromNat(n)]);
            };
            case (#Nat8(n)) {
                Blob.fromArray([n]);
            };
            case (#Int(n)) {
                Blob.fromArray([Nat8.fromIntWrap(n)]);
            };
            case (#Text(t)) {
                Text.encodeUtf8(t);
            };
            case (#Bool(b)) {
                Blob.fromArray([if b Nat8.fromNat(1) else Nat8.fromNat(0)]);
            };
            case (#Blob(b)) {
                b;
            };
            case (#Array(a)) {
                let buffer = Buffer.Buffer<Blob>(0);
                for (i in a.vals()) {
                    let subBlob = blobFromValue(i);
                    buffer.add(subBlob);
                };
                bufferToBlob(buffer);
            };
            case (#Map(m)) {
                let buffer = Buffer.Buffer<Blob>(0);
                for ((key, value) in m.vals()) {
                    let keyBlob = Text.encodeUtf8(key);
                    let valueBlob = blobFromValue(value);
                    buffer.add(keyBlob);
                    buffer.add(valueBlob);
                };
                bufferToBlob(buffer);
            };
        };
    };

    func bufferToBlob(buffer : Buffer.Buffer<Blob>) : Blob {
        let blobArray = Buffer.toArray(buffer);
        let blob = Array.foldLeft<Blob, Blob>(
            blobArray,
            Blob.fromArray([]),
            func(acc, b) {
                let accArray = Blob.toArray(acc);
                let bArray = Blob.toArray(b);
                let newArray = appendArray(accArray, bArray);
                Blob.fromArray(newArray);
            },
        );
        blob;
    };

    // fix timestamp to date
    public func timestamp2024ToDate(timestamp : Int) : Text {
        if (timestamp < 1_704_067_200_000_000_000) {
            return "Invalid timestamp";
        };
        let start2024 = timestamp - 1_704_067_200_000_000_000;
        let seconds = start2024 / 1_000_000_000;
        let minutes = Int.div(seconds, 60);
        let hours = Int.div(minutes, 60);
        let days = Int.div(hours, 24);

        let secondsInMinute = seconds % 60;
        let minutesInHour = minutes % 60;
        let hoursInDay = hours % 24;

        let years = Int.div(days, 365);
        let year = years + 2024;
        var remainingDays = days - (years * 365);

        let monthDays = if (isLeapYear(year)) {
            [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        } else { [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] };
        var month = 1;
        label l for (i in monthDays.vals()) {
            if (remainingDays < i) break l;
            remainingDays -= i;
            month += 1;
        };

        let day = remainingDays + 1;

        return Int.toText(year) # "-" # Int.toText(month) # "-"
        # Int.toText(day) # " " # Int.toText(hoursInDay) # ":"
        # Int.toText(minutesInHour) # ":" # Int.toText(secondsInMinute);
    };

    private func isLeapYear(year : Int) : Bool {
        return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
    };
    // private func nat32ToBytes(x : Nat32) : [Nat8] {
    //     [
    //         Nat8.fromNat(Nat32.toNat((x >> 24) & (255))),
    //         Nat8.fromNat(Nat32.toNat((x >> 16) & (255))),
    //         Nat8.fromNat(Nat32.toNat((x >> 8) & (255))),
    //         Nat8.fromNat(Nat32.toNat((x & 255))),
    //     ];
    // };

    //       public func arrayGetAll(candy: Candy.CandyShared): Candy.CandyShared {
    //     switch (candy) {
    //       case (#Array(array)) if (array.size() > 0) return array[0];
    //       case (#Bytes(array)) if (array.size() > 0) return #Nat8(array[0]);
    //       case (#Floats(array)) if (array.size() > 0) return #Float(array[0]);
    //       case (#Ints(array)) if (array.size() > 0) return #Int(array[0]);
    //       case (#Nats(array)) if (array.size() > 0) return #Nat(array[0]);
    //       case (_) return #Option(null);
    //     };

    //     return #Option(null);
    //   };
};
