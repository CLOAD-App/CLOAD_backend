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

shared ({caller = owner}) actor class Canister() = this {
  
  let ownerAdmin :Principal = Principal.fromText("");
  let center :Principal = Principal.fromText("yffxi-vqaaa-aaaak-qcrnq-cai");

  // Cycles record
  private stable var cyclesToData_s: [(Principal, Types.CyclesRecord)] = [];
  private let cyclesToData = HashMap.fromIter<Principal, Types.CyclesRecord>(cyclesToData_s.vals(), 0, Principal.equal, Principal.hash);

  system func preupgrade() {
    cyclesToData_s := Iter.toArray(cyclesToData.entries());
  };

  system func postupgrade() {
    cyclesToData_s := [];
  };

  /*
  * Cycles Record Related
  */
  
  // Add or update Cycles record
  public shared({ caller }) func addCyclesRecord({ userID: Principal; amount: Int; operation: { #Add; #Sub }; memo: Text; balance: Int }) : async () {
    assert(Principal.equal(caller, center)); // Core Canister call
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
        // Existing record, append new change
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

  // Get user Cycles record list
  public query({ caller }) func getUserCyclesRecordList({ page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Types.CyclesRecordEntry];
    dataPage: Nat;
  } {
    // Retrieve the user's Cycles records
    switch (cyclesToData.get(caller)) {
      case (null) {
        // No records, return empty
        {
          listSize = 0;
          dataList = [];
          dataPage = page;
        };
      };
      case (?r) {
        // Sort by time in descending order (newest first)
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
        // Paginate
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
  * Cycles Control Related
  */

  public query func getCycleBalance() : async Nat {
    Cycles.balance();
  };

  // Check the cycles balance of a specified canister and top up if below threshold
  public shared({caller}) func monitorAndTopUp({canisterId: Principal; threshold: Nat; topUpAmount: Nat}) : async { 
    status: Text; 
    transferred: Nat; 
    refunded: Nat 
  } {
    assert(Principal.equal(caller, center)); 

    // Get the management interface of the target canister
    let targetCanister = actor(Principal.toText(canisterId)) : actor {
      getCycleBalance : shared () -> async Nat;
      wallet_receive : shared () -> async { accepted: Nat };
    };
    
    // Check the cycles balance of the target canister
    let targetBalance = await targetCanister.getCycleBalance();
    
    // If the balance is below the threshold, top up cycles
    if (targetBalance < threshold) {
      
      // Add cycles to the next call
      Cycles.add<system>(topUpAmount);
      
      // Call the target canister's receive function
      let result = await targetCanister.wallet_receive();
      
      // Get the amount of refunded cycles
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

  // Check and top up the balance of multiple canisters
  public shared({caller}) func checkAndTopUpAllCanisters({list:[Principal]}) : async [(Principal, Nat, Nat)] {
    assert(Principal.equal(caller, center)); 
    let results = Buffer.Buffer<(Principal, Nat, Nat)>(0); 
    for (cid in list.vals()) {
      try {
        // Get the management interface of the target canister
        let targetCanister = actor(Principal.toText(cid)) : actor {
          getCycleBalance : shared () -> async Nat;
          wallet_receive : shared () -> async { accepted: Nat };
        };
        // Add cycles to the next call
        Cycles.add<system>(Types.cycles1T);

        // Call the target canister's receive function
        let result = await targetCanister.wallet_receive();
      
        // Get the amount of refunded cycles
        let refundedAmount = Cycles.refunded();
        results.add((cid, result.accepted, refundedAmount));
      } catch (_) {
        // If a canister query fails, do not let the entire loop fail, record the error
        results.add((cid, 0, 0));
      };
    };

    return Buffer.toArray(results);
  };

}