import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Bool "mo:base/Bool";
import Types "types";

  /*
  * Transaction operations
  */

module {

    // Transaction record
    public type Transaction = {
        transactionID:Text; // Transaction ID
        userID:Principal; // User ID
        authorID:Principal; // Project author ID
        itemID:Text; // Project ID
        paymentAmount: Nat; // Payment amount
        currency:Types.Tokens; // Currency type
        creationTime:Int; // Creation time
        isActive:Bool;
    };

    // Create transaction record
    public func createTransaction(
        tradeToData:HashMap.HashMap<Text, Transaction>,transactionID:Text,
        userID:Principal,authorID:Principal,itemID:Text,
        paymentAmount: Nat,currency:Types.Tokens):(){
        switch(tradeToData.get(transactionID)) {
            case (null) {
                tradeToData.put(transactionID,{
                transactionID; // Transaction ID
                userID; // User ID
                authorID; // Author ID
                itemID; // Project ID
                paymentAmount; // Payment amount
                currency; // Currency type
                creationTime = Time.now();
                isActive = true;
            });
            };
            case (_) {};
      };
    };

    // Change transaction status
    public func setTradeIsActive(tradeToData:HashMap.HashMap<Text, Transaction>,transactionID:Text,isActive:Bool):(){
        switch (tradeToData.get(transactionID)) { 
            case (null) {}; 
            case (?t) {
                tradeToData.put(transactionID,{t with isActive;});
            }; 
        };    
    };


    // Refund record
    public type Refunds = {
        transactionID:Text; // Transaction ID
        userID:Principal; // User ID
        authorID:Principal; // Project author ID
        refundAmount:Nat; // Refund amount
        refundReason:Text; // Refund reason
        rejectRefundReason:Text; // Rejected refund reason
        refundTime:Int; // Refund time
        refund:Types.Status; // Refund status
        createTime:Int; // Creation time
        isActive:Bool;
    };

    // Create refund record
    public func createRefunds(
        refundsToData:HashMap.HashMap<Text, Refunds>,transactionID:Text,userID:Principal,authorID:Principal,
        refundAmount:Nat,refundReason:Text):(){
        switch(refundsToData.get(transactionID)) {
            case (null) {
            refundsToData.put(transactionID,{
                transactionID; // Transaction ID
                userID;
                authorID; // Project party ID
                refundAmount; // Refund amount
                refundReason; // Refund reason
                rejectRefundReason=""; // Rejected refund reason
                refundTime=0; // Refund time
                refund = #Default; // Refund status
                createTime =Time.now();
                isActive = true;
            });
            };
            case (_) {};
      };
    };


    // Update refund record status
    public func setRefundsStatus(refundsToData:HashMap.HashMap<Text, Refunds>,transactionID:Text,rejectRefundReason:Text,refund:Types.Status):(){
        switch (refundsToData.get(transactionID)) { 
            case (null) {}; 
            case (?r) {
                var refundTime = switch (refund) {
                    case (#Succes) Time.now(); 
                    case (#Failed) Time.now();
                    case (#Default) 0; 
                };
                refundsToData.put(transactionID,{r with rejectRefundReason;refund;refundTime});
            }; 
        };    
    };
}