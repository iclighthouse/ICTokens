module {
  public type AccountId = Blob;
  public type Address = Text;
  public type Allowance = { remaining : Nat; spender : AccountId };
  public type Callback = shared TxnRecord -> async ();
  public type Config = {
    maxPublicationTries : ?Nat;
    enBlacklist : ?Bool;
    maxStorageTries : ?Nat;
    storageCanister : ?Text;
    miningCanister : ?Text;
    maxCacheNumberPer : ?Nat;
    maxCacheTime : ?Int;
    feeTo : ?Address;
  };
  public type ExecuteType = { #sendAll; #send : Nat; #fallback };
  public type Gas = { #token : Nat; #cycles : Nat; #noFee };
  public type Metadata = { content : Text; name : Text };
  public type MsgType = { #onApprove; #onExecute; #onTransfer; #onLock };
  public type Operation = {
    #approve : { allowance : Nat };
    #lockTransfer : { locked : Nat; expiration : Time; decider : AccountId };
    #transfer : { action : { #burn; #mint; #send } };
    #executeTransfer : { fallback : Nat; lockedTxid : Txid };
  };
  public type Subscription = { callback : Callback; msgTypes : [MsgType] };
  public type Time = Int;
  public type Transaction = {
    to : AccountId;
    value : Nat;
    data : ?Blob;
    from : AccountId;
    operation : Operation;
  };
  public type Txid = Blob;
  public type TxnQueryRequest = {
    #txnCount : { owner : Address };
    #lockedTxns : { owner : Address };
    #lastTxids : { owner : Address };
    #lastTxidsGlobal;
    #getTxn : { txid : Txid };
    #txnCountGlobal;
  };
  public type TxnQueryResponse = {
    #txnCount : Nat;
    #lockedTxns : { txns : [TxnRecord]; lockedBalance : Nat };
    #lastTxids : [Txid];
    #lastTxidsGlobal : [Txid];
    #getTxn : ?TxnRecord;
    #txnCountGlobal : Nat;
  };
  public type TxnRecord = {
    gas : Gas;
    transaction : Transaction;
    txid : Txid;
    nonce : Nat;
    timestamp : Time;
    caller : Principal;
    index : Nat;
  };
  public type TxnResult = {
    #ok : Txid;
    #err : {
      code : {
        #InsufficientGas;
        #InsufficientAllowance;
        #UndefinedError;
        #InsufficientBalance;
        #LockedTransferExpired;
      };
      message : Text;
    };
  };
  public type Self = actor {
    allowance : shared query (Address, Address) -> async Nat;
    approvals : shared query Address -> async [Allowance];
    approve : shared (Address, Nat, ?[Nat8]) -> async TxnResult;
    balanceOf : shared query Address -> async Nat;
    burn : shared (Nat, ?[Nat8], ?Blob) -> async TxnResult;
    changeOwner : shared Principal -> async Bool;
    config : shared Config -> async Bool;
    cyclesBalanceOf : shared query Address -> async Nat;
    cyclesReceive : shared ?Address -> async Nat;
    cyclesWithdraw : shared (Principal, Nat, ?[Nat8]) -> async ();
    decimals : shared query () -> async Nat8;
    executeTransfer : shared (Txid, ExecuteType, ?Address, ?[Nat8]) -> async TxnResult;
    gas : shared query () -> async Gas;
    getMemory : shared query () -> async (Nat, Nat, Nat, Nat32);
    isInBlacklist : shared query Address -> async Bool;
    lockTransfer : shared (
        Address,
        Nat,
        Nat32,
        ?Address,
        ?[Nat8],
        ?Blob,
      ) -> async TxnResult;
    lockTransferFrom : shared (
        Address,
        Address,
        Nat,
        Nat32,
        ?Address,
        ?[Nat8],
        ?Blob,
      ) -> async TxnResult;
    metadata : shared query () -> async [Metadata];
    mint : shared (Address, Nat, ?Blob) -> async TxnResult;
    name : shared query () -> async Text;
    setBlacklist : shared (Address, Bool) -> async Bool;
    setGas : shared Gas -> async Bool;
    setMetadata : shared [Metadata] -> async Bool;
    setPause : shared Bool -> async Bool;
    standard : shared query () -> async Text;
    subscribe : shared (Callback, [MsgType], ?[Nat8]) -> async Bool;
    subscribed : shared query Address -> async ?Subscription;
    symbol : shared query () -> async Text;
    top100 : shared query () -> async [(Address, Nat)];
    totalSupply : shared query () -> async Nat;
    transfer : shared (Address, Nat, ?[Nat8], ?Blob) -> async TxnResult;
    transferFrom : shared (
        Address,
        Address,
        Nat, 
        ?[Nat8],
        ?Blob,
      ) -> async TxnResult;
    txnQuery : shared query TxnQueryRequest -> async TxnQueryResponse;
  }
}