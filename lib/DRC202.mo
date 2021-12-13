/**
 * Module     : DRC202.mo
 * CanisterId : oearr-eyaaa-aaaak-aabja-cai
 */
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Binary "Binary";
import SHA224 "SHA224";

module {
  public type AccountId = Blob;
  public type Time = Time.Time;
  public type Txid = Blob;
  public type Gas = { #token : Nat; #cycles : Nat; #noFee };
  public type Operation = {
    #approve : { allowance : Nat };
    #lockTransfer : { locked : Nat; expiration : Time; decider : AccountId };
    #transfer : { action : { #burn; #mint; #send } };
    #executeTransfer : { fallback : Nat; lockedTxid : Txid };
  };
  public type Transaction = {
    to : AccountId;
    value : Nat;
    data : ?Blob;
    from : AccountId;
    operation : Operation;
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
  public type Self = actor {
    version: shared query () -> async Nat8;
    fee : shared query () -> async (cycles: Nat); //cycles
    store : shared (_txn: TxnRecord) -> async (); 
    storeBytes: shared (_txid: Txid, _data: [Nat8]) -> async (); 
    bucket : shared query (_token: Principal, _txid: Txid, _step: Nat, _version: ?Nat8) -> async (bucket: ?Principal, isEnd: Bool);
    //txn : shared query (_token: Principal, _txid: Txid) -> async (txn: ?TxnRecord);
  };
  public func generateTxid(_canister: Principal, _caller: Principal, _nonce: Nat): Txid{
    let canister: [Nat8] = Blob.toArray(Principal.toBlob(_canister));
    let caller: [Nat8] = Blob.toArray(Principal.toBlob(_caller));
    let nonce: [Nat8] = Binary.BigEndian.fromNat32(Nat32.fromNat(_nonce));
    let txInfo = Array.append(Array.append(canister, caller), nonce);
    let h224: [Nat8] = SHA224.sha224(txInfo);
    return Blob.fromArray(Array.append(nonce, h224));
  };
}
