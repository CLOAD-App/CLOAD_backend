import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import Cycles "mo:base/ExperimentalCycles";

import Types "types";

shared ({caller = owner}) persistent actor class Canister() = this {
  let ownerAdmin :Principal = Principal.fromText("cfklm-6bmf5-bovci-hk76c-rue3p-axnze-w2tjc-vpfdk-wppgd-xj2yv-2qe");

  // User points
  public type Integral = {
    userID: Principal; // User ID
    addIntegral:Int; // Points change
    integralType:{
      #Appeal; // Participate in appeal
      #Invite;  // Invite new users
      #Activity; // Activity
    };  // Points type
    associatedID:Text; // Associated ID
    creationTime:Int; // Creation time
    isActive:Bool;
  };

    // Redeem code type
  public type Code_Type = {
    #Cycles5T; // 5T Cycles
  };
  // Redeem code info
  public type RedeemCode = {
    redeemCode:Text; // Redeem code
    userID:Principal; // User ID
    types:Code_Type; // Redeem code type
    isActive:Bool;// Not yet claimed
    creationTime:Int; // Claim time
  };

  // Points data
  private var integralToData_s: [Integral] = [];
  private transient let integralToData: Buffer.Buffer<Integral> = Types.fromArray(integralToData_s);
  // Redeem code data
  private var redeemCodeToData_s: [(Text, RedeemCode)] = [];
  private transient let redeemCodeToData = HashMap.fromIter<Text, RedeemCode>(redeemCodeToData_s.vals(), 0, Text.equal, Text.hash);

  system func preupgrade() {
    integralToData_s := Buffer.toArray(integralToData);
    redeemCodeToData_s := Iter.toArray(redeemCodeToData.entries());
  };

  system func postupgrade() {
    integralToData_s := [];
    redeemCodeToData_s := [];
  };


  public type CenterCanister = actor {
      addCyclesRedeemCode : shared ({userID:Principal}) -> async (Bool);
  };
  let center:CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

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
  * Points related
  */
  

  // Get number of point records
  public query func getIntegralToDataSize(): async Nat {
    let list = Buffer.toArray(integralToData);
    return list.size()
  };

  /*
  * Redeem code related
  */

  // Add redeem code
  public shared({ caller }) func addRedeemCode({codeList:[Text];types:Code_Type}): async () {
    assert(Principal.equal(caller,ownerAdmin));
    // Check if redeem code already exists
      for(code in codeList.vals()){
          redeemCodeToData.put(code,{
          redeemCode=code; // Redeem code
          userID=Principal.fromActor(this);// User ID
          types;// Associated type
          isActive=true;// Not yet claimed
          creationTime=0; // Creation time
        });
      }
  };
  
  // Get redeem code details
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

  // Claim redeem code
  public shared({ caller }) func claimRedeemCode({code:Text}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
    switch (redeemCodeToData.get(code)) {
      case (null) {
        #err("Redemption code not found!")
      };
      case (?r) {
        if(r.isActive){
          if(r.types== #Cycles5T){
              // Temporarily mark as used to prevent double spending
              redeemCodeToData.put(code, {
                r with
                isActive = false;
                userID = caller;       
                creationTime = Time.now(); 
              });

              let ok = await center.addCyclesRedeemCode({ userID = caller });
              if (ok) {
                // Success: keep isActive=false to mark inactive
                return #ok("Redemption successful : 5T Cycles");
              } else {
                // Failure: rollback
                redeemCodeToData.put(code, {
                  r with
                  isActive = true;
                  userID = Principal.fromActor(this);
                  // pending=false
                });
                return #err("Redemption failed, please try again later");
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

  // Get available redeem codes
  public query({ caller }) func getRedeemCodeAll():async [RedeemCode] {
    assert(Principal.equal(caller,ownerAdmin));
    var list = Buffer.Buffer<RedeemCode>(0);
    for((id,code) in Iter.toArray(redeemCodeToData.entries()).vals()){
      if(code.isActive){
          list.add(code);
      }
    };
   Buffer.toArray(list);
  };
}
