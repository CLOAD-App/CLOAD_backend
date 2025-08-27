import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Cycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Order "mo:base/Order";

import Types "types";

shared ({caller = owner}) persistent actor class Canister() = this {
  
  transient let center :Principal = Principal.fromText("yffxi-vqaaa-aaaak-qcrnq-cai");

  // Cycles records
  private var cyclesToData_s: [(Principal, Types.CyclesRecord)] = [];
  private transient let cyclesToData = HashMap.fromIter<Principal, Types.CyclesRecord>(cyclesToData_s.vals(), 0, Principal.equal, Principal.hash);


  system func preupgrade() {
    cyclesToData_s := Iter.toArray(cyclesToData.entries());
  };

  system func postupgrade() {
    cyclesToData_s := [];
  };



  /*
  * Cycles record operations
  */
  
  // Add or update cycles record
  public shared({ caller }) func addCyclesRecord({ userID: Principal; amount: Int; operation: { #Add; #Sub }; memo: Text; balance: Int }) : async () {
    assert(Principal.equal(caller, center)); // Called by core canister
    let now = Time.now();

    switch (cyclesToData.get(userID)) {
      case (null) {
        // No record, create new
        let newRecord : Types.CyclesRecord = {
          userID;
          records = [{
            amount;
            operation;
            memo;
            balance;
            time = now;
          }];
        };
        cyclesToData.put(userID, newRecord);
      };
      case (?existingRecord) {
        // Existing record, append new entry
        let lastBalance = switch (existingRecord.records.size()) {
          case (0) { 0 };
          case (_) { existingRecord.records[existingRecord.records.size() - 1].balance };
        };

        let newBalance = switch (operation) {
          case (#Add) { lastBalance + amount };
          case (#Sub) { lastBalance - amount };
        };

        let updatedRecords = Array.append<Types.CyclesRecordEntry>(
          existingRecord.records,
          [{
            amount = amount;
            operation = operation;
            memo = memo;
            balance = newBalance;
            time = now;
          }]
        );

        cyclesToData.put(userID, {
          userID = userID;
          records = updatedRecords;
        });
      };
    };
  };


  // Get user cycles record list
  public query({ caller }) func getUserCyclesRecordList({ page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Types.CyclesRecordEntry];
    dataPage: Nat;
  } {
    // Retrieve cycles records for the user
    switch (cyclesToData.get(caller)) {
      case (null) {
        // No record, return empty
        {
          listSize = 0;
          dataList = [];
          dataPage = page;
        };
      };
      case (?r) {
        // Sort by time descending (latest first)
        let sortedRecords = Array.sort<Types.CyclesRecordEntry>(
          r.records,
          func (a: Types.CyclesRecordEntry, b: Types.CyclesRecordEntry) : Order.Order {
            if (a.time < b.time) {
              return #greater;
            } else if (a.time > b.time) {
              return #less;
            } else {
              return #equal;
            }
          }
        );
        // Pagination
        let (pagedItems, total) = Types.paginate<Types.CyclesRecordEntry>(sortedRecords, page, pageSize);
        {
          listSize = total;
          dataList = pagedItems;
          dataPage = page;
        };
      };
    };
  };

  /*
  * Cycles control
  */

  public query func getCycleBalance() : async Nat {
    Cycles.balance();
  };


  // Check canister cycles balance and top up if below threshold
  public shared({caller}) func monitorAndTopUp({canisterId: Principal; threshold: Nat; topUpAmount: Nat}) : async { 
    status: Text; 
    transferred: Nat; 
    refunded: Nat 
  } {
    assert(Principal.equal(caller, center)); 

    // Get target canister management interface
    let targetCanister = actor(Principal.toText(canisterId)) : actor {
      getCycleBalance : shared () -> async Nat;
      wallet_receive : shared () -> async { accepted: Nat };
    };
    
    // Check target canister's cycles balance
    let targetBalance = await targetCanister.getCycleBalance();
    
    // Top up cycles if balance below threshold
    if (targetBalance < threshold) {
      
      // Add cycles to next call
      Cycles.add<system>(topUpAmount);
      
      // Call target canister's receive function
      let result = await targetCanister.wallet_receive();
      
      // Get amount of cycles refunded
      let refundedAmount = Cycles.refunded();
      
      return {
        status = "add cycles";
        transferred = result.accepted;
        refunded = refundedAmount;
      };
    } else {
      return {
        status = "cycles sufficient";
        transferred = 0;
        refunded = 0;
      };
    }
  };

  // Check and top up multiple canister balances
  public shared({caller}) func checkAndTopUpAllCanisters({list:[Principal]}) : async [(Principal, Nat, Nat)] {
    assert(Principal.equal(caller, center)); 
    let results = Buffer.Buffer<(Principal, Nat, Nat)>(0); 
    for (cid in list.vals()) {
      try {
        // Get target canister management interface
        let targetCanister = actor(Principal.toText(cid)) : actor {
          getCycleBalance : shared () -> async Nat;
          wallet_receive : shared () -> async { accepted: Nat };
        };
        // Add cycles to next call
        Cycles.add<system>(Types.cycles1T);

        // Call target canister's receive function
        let result = await targetCanister.wallet_receive();
      
        // Get amount of cycles refunded
        let refundedAmount = Cycles.refunded();
        results.add((cid, result.accepted, refundedAmount));
      } catch (_) {
        // If a canister query fails, continue loop and record error
        results.add((cid, 0, 0));
      };
    };

    return Buffer.toArray(results);
  };


}
