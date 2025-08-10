import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Prim "mo:⛔";
import Cycles "mo:base/ExperimentalCycles";

import Types "types";
import User "user";
import Item "item";
import Trade "trade";
import Posts "posts";

shared ({caller = owner}) actor class Canister() = this {
  let ownerAdmin: Principal = Principal.fromText("");
  let center: Principal = Principal.fromText("yffxi-vqaaa-aaaak-qcrnq-cai");
  let nftCanister: Principal = Principal.fromText("24t7b-laaaa-aaaak-quf6q-cai");
  let contentCanister: Principal = Principal.fromText("lyr3s-lqaaa-aaaak-qugvq-cai");

  system func preupgrade() {
    userToSave_s := Iter.toArray(userToSave.entries());
    followToSave_s := Iter.toArray(followToSave.entries());
    itemToSave_s := Iter.toArray(itemToSave.entries());
    storeToSave_s := Iter.toArray(storeToSave.entries());
    favoritesToSave_s := Iter.toArray(favoritesToSave.entries());
    ratingToSave_s := Iter.toArray(ratingToSave.entries());
    tradeToSave_s := Iter.toArray(tradeToSave.entries());
    refundsToSave_s := Iter.toArray(refundsToSave.entries());
    featureToSave_s := Iter.toArray(featureToSave.entries());
    postsToSave_s := Iter.toArray(postsToSave.entries());
    nftToSave_s := Iter.toArray(nftToSave.entries());
  };

  system func postupgrade() {
    userToSave_s := [];
    followToSave_s := [];
    itemToSave_s := [];
    storeToSave_s := [];
    favoritesToSave_s := [];
    ratingToSave_s := [];
    tradeToSave_s := [];
    refundsToSave_s := [];
    featureToSave_s := [];
    postsToSave_s := [];
    nftToSave_s := [];
  };
    
  public query func getSize() : async Nat {
      Prim.rts_memory_size();
  };

  public query func getCycleBalance() : async Nat {
      Cycles.balance();
  };
  
  // Function to receive cycles
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

  /*
  * User Information
  */

  // User information archive
  private stable var userToSave_s: [(Text, [(Principal, User.User)])] = [];
  private let userToSave = HashMap.fromIter<Text, [(Principal, User.User)]>(userToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveUserToSave({date: Text; dataList: [(Principal, User.User)]}): async () {
    if (Principal.equal(caller, center)) {
        // Check if there is an archive for the given date
        switch (userToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                userToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Principal, User.User>(u.vals(), 0, Principal.equal, Principal.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                userToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getUser({date: Text}): async [(Principal, User.User)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (userToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * Follow Information
  */

  // User follow information archive
  private stable var followToSave_s: [(Text, [(Principal, User.UserFollow)])] = [];
  private let followToSave = HashMap.fromIter<Text, [(Principal, User.UserFollow)]>(followToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFollowToSave({date: Text; dataList: [(Principal, User.UserFollow)]}): async () {
    if (Principal.equal(caller, center)) {
        // Check if there is an archive for the given date
        switch (followToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                followToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Principal, User.UserFollow>(u.vals(), 0, Principal.equal, Principal.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                followToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFollow({date: Text}): async [(Principal, User.UserFollow)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (followToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * Item Information
  */

  // Item information
  private stable var itemToSave_s: [(Text, [(Text, Item.Items)])] = [];
  private let itemToSave = HashMap.fromIter<Text, [(Text, Item.Items)]>(itemToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveItemToSave({date:Text;dataList:[(Text, Item.Items)]}):async () {
   if (Principal.equal(caller, center)) {
        // Check if there is an archive for the given date
        switch (itemToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                itemToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Item.Items>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                itemToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getItem({date:Text}): async [(Text, Item.Items)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (itemToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * File Index Information
  */

  // File index storage
  private stable var storeToSave_s: [(Text, [(Text, Item.Store)])] = [];
  private let storeToSave = HashMap.fromIter<Text, [(Text, Item.Store)]>(storeToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveStoreToSave({date:Text;dataList:[(Text, Item.Store)]}):async () {
   if (Principal.equal(caller, center)) {
        // Check if there is an archive for the given date
        switch (storeToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                storeToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Types.FileStorage>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                storeToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getStore({date:Text}): async [(Text, Types.FileStorage)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (storeToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * Item Favorites Information
  */

  // User item favorites information
  private stable var favoritesToSave_s: [(Text, [(Principal, Types.Favorites)])] = [];
  private let favoritesToSave = HashMap.fromIter<Text, [(Principal, Types.Favorites)]>(favoritesToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFavoritesToSave({date: Text; dataList: [(Principal, Types.Favorites)]}): async () {
    if (Principal.equal(caller, contentCanister)) {
        // Check if there is an archive for the given date
        switch (favoritesToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                favoritesToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Principal, Types.Favorites>(u.vals(), 0, Principal.equal, Principal.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                favoritesToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFavorites({date: Text}): async [(Principal, Types.Favorites)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (favoritesToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * User Rating Information
  */

  // User rating comments
  private stable var ratingToSave_s: [(Text, [(Text, Types.Rating)])] = [];
  private let ratingToSave = HashMap.fromIter<Text, [(Text, Types.Rating)]>(ratingToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveRatingToSave({date: Text; dataList: [(Text, Types.Rating)]}): async () {
    if (Principal.equal(caller, contentCanister)) {
        // Check if there is an archive for the given date
        switch (ratingToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                ratingToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Types.Rating>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                ratingToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getRating({date: Text}): async [(Text, Types.Rating)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (ratingToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * User Transaction Information
  */

  // User transaction information
  private stable var tradeToSave_s: [(Text, [(Text, Trade.Transaction)])] = [];
  private let tradeToSave = HashMap.fromIter<Text, [(Text, Trade.Transaction)]>(tradeToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveTradeToSave({date: Text; dataList: [(Text, Trade.Transaction)]}): async () {
    if (Principal.equal(caller, center)) {
        // Check if there is an archive for the given date
        switch (tradeToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                tradeToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Trade.Transaction>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                tradeToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getTrade({date: Text}): async [(Text, Trade.Transaction)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (tradeToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * User Refund Information
  */

  // User refund information
  private stable var refundsToSave_s: [(Text, [(Text, Trade.Refunds)])] = [];
  private let refundsToSave = HashMap.fromIter<Text, [(Text, Trade.Refunds)]>(refundsToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFundsToSave({date: Text; dataList: [(Text, Trade.Refunds)]}): async () {
    if (Principal.equal(caller, center)) {
        // Check if there is an archive for the given date
        switch (refundsToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                refundsToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Trade.Refunds>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                refundsToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFunds({date: Text}): async [(Text, Trade.Refunds)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (refundsToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * Feature Storage Information
  */

  // Feature storage information
  private stable var featureToSave_s: [(Text, [(Text, Types.Feature)])] = [];
  private let featureToSave = HashMap.fromIter<Text, [(Text, Types.Feature)]>(featureToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFeatureToSave({date: Text; dataList: [(Text, Types.Feature)]}): async () {
    if (Principal.equal(caller, contentCanister)) {
        // Check if there is an archive for the given date
        switch (featureToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                featureToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Types.Feature>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                featureToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFeature({date: Text}): async [(Text, Types.Feature)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (featureToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * Post Information
  */

  // Post information
  private stable var postsToSave_s: [(Text, [(Text, Posts.Posts)])] = [];
  private let postsToSave = HashMap.fromIter<Text, [(Text, Posts.Posts)]>(postsToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func savePostsToSave({date: Text; dataList: [(Text, Posts.Posts)]}): async () {
    if (Principal.equal(caller, contentCanister)) {
        // Check if there is an archive for the given date
        switch (postsToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                postsToSave.put(date, dataList);
            };
            case (?u) {
                // If an archive exists, create a new HashMap and reassign
                let data = HashMap.fromIter<Text, Posts.Posts>(u.vals(), 0, Text.equal, Text.hash);
                for (user in dataList.vals()) {
                    data.put(user);
                };
                postsToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getPosts({date: Text}): async [(Text, Posts.Posts)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (postsToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };
  
  // NFT information
  private stable var nftToSave_s: [(Text, [Types.NFT])] = [];
  private let nftToSave = HashMap.fromIter<Text, [Types.NFT]>(nftToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveNftToSave({date: Text; dataList: [Types.NFT]}): async () {   
    if (Principal.equal(caller, nftCanister)) {
        // Check if there is an archive for the given date
        switch (nftToSave.get(date)) {
            case null {
                // If no archive exists, create a new one
                nftToSave.put(date, dataList);
            };
            case (_) {
                // If an archive exists, reassign
                nftToSave.put(date, dataList);
            };
        }
    };
  };

  // Example: Restore synchronized data Canister
  public type SyncCanister = actor {
      syncData: shared ({dataList: [(Principal, User.User)]}) -> async ();
  };
  let SyncCanister: SyncCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  // Example: Restore user archive for the given date (if the list size is not greater than 2MB)
  public shared({ caller }) func recoverToSave({date: Text}): async () {
     assert (Principal.equal(caller, ownerAdmin));
    // Check if there is an archive for the given date
    switch (userToSave.get(date)) {
        case null {};
        case (?data) {
            await SyncCanister.syncData({dataList=data});
        };
    }
  };
};
