import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";

import Types "types";

shared ({caller = owner}) actor class Canister() = this {
  let ownerAdmin :Principal = Principal.fromText("");

  // User points
  public type Integral = {
    userID: Principal; // User ID
    addIntegral: Int; // Points changed
    integralType: {
      #Appeal; // Participate in appeal
      #Invite;  // Invite new user
      #Activity; // Activity
    };  // Points type
    associatedID: Text; // Associated ID
    creationTime: Int; // Creation time
    isActive: Bool;
  };

  public type Code_Type = {
    #Cycles5T; // 5T Cycles
  };

  // Redemption code information
  public type RedeemCode = {
    redeemCode: Text; // Redemption code
    userID: Principal; // User ID
    types: Code_Type; // Redemption code type
    isActive: Bool; // Whether unclaimed
    creationTime: Int; // Claim time
  };

  // Points information
  private stable var integralToData_s: [Integral] = [];
  private let integralToData: Buffer.Buffer<Integral> = Types.fromArray(integralToData_s);
  // Redemption code information
  private stable var redeemCodeToData_s: [(Text, RedeemCode)] = [];
  private let redeemCodeToData = HashMap.fromIter<Text, RedeemCode>(redeemCodeToData_s.vals(), 0, Text.equal, Text.hash);

  system func preupgrade() {
    integralToData_s := Buffer.toArray(integralToData);
    redeemCodeToData_s := Iter.toArray(redeemCodeToData.entries());
  };

  system func postupgrade() {
    integralToData_s := [];
    redeemCodeToData_s := [];
  };

  public type CenterCanister = actor {
      addCyclesRedeemCode : shared ({userID: Principal}) -> async (Bool);
  };
  let center: CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

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
  * Points Related
  */
  
  // Get the number of points information
  public query func getIntegralToDataSize(): async Nat {
    let list = Buffer.toArray(integralToData);
    return list.size()
  };

  /*
  * Redemption Code Related
  */

  let redeem_code_type: [Text] = ["Cycles5T"]; // Redemption code types
  // Add redemption code
  public shared({ caller }) func addRedeemCode({codeList:[Text];types:Code_Type}): async () {
    assert(Principal.equal(caller,ownerAdmin));
      for(code in codeList.vals()){
          redeemCodeToData.put(code,{
          redeemCode=code; 
          userID=Principal.fromActor(this);
          types;
          isActive=true;
          creationTime=0;
        });
      }
  };
  
  // Get redemption code details
  public query func getRedeemCode({code:Text}): async Result.Result<Text, Text> {
    switch (redeemCodeToData.get(code)) {
      case (null) {
        #err("Redemption code not found!")
      };
      case (?r) {
        if(r.isActive){
          #ok("Valid Code : 5T Cycles.")
        }else{
          #err("Invalid Code : The redemption code has already been used.")
        };
      };
    };
  };

  // Claim redemption code
  public shared({ caller }) func claimRedeemCode({code: Text}): async Result.Result<Text, Text> {
    switch (redeemCodeToData.get(code)) {
      case (null) {
        #err("Redemption code not found!")
      };
      case (?r) {
        if(r.isActive){
          if(r.types== #Cycles5T){
            // Request the main Canister, update status if successful
            let res = await center.addCyclesRedeemCode({ userID = caller });
            if(res){
              redeemCodeToData.put(code,{
                redeemCode=code; // Redemption code
                userID=caller; // Claiming user ID
                types=r.types; // Associated ID
                isActive=false; // Whether unclaimed
                creationTime=Time.now(); // Claim time
              });
              #ok("Redemption successful : 5T Cycles");
            }else{
              #err("Redemption failed, please try again later");
            }; 
          }else{
            #err("Redemption code not found!");
          }
        }else{
        #err("This redemption code has expired")
        }
      };
    };
  };

  // Get available redemption codes
  public query({ caller }) func getRedeemCodeAll(): async [RedeemCode] {
    assert(Principal.equal(caller, ownerAdmin));
    var list = Buffer.Buffer<RedeemCode>(0);
    for((id,code) in Iter.toArray(redeemCodeToData.entries()).vals()){
      if(code.isActive){
          list.add(code);
      }
    };
   Buffer.toArray(list);
  };
}
