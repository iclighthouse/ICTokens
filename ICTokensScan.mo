/**
 * Module     : ICTokensScan.mo
 * Author     : ICLighthouse Team
 * License    : GNU General Public License v3.0
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICTokens
 */
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Monitee "./lib/Monitee";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

shared(installMsg) actor class ICTokensScan() = this {

    private stable var owner: Principal = installMsg.caller;
    private stable var tokenList: [(symbol: Text, canisterId: Principal)] = []; 
    private stable var tagList: Trie.Trie<Text, Text> = Trie.empty(); 

    private func _onlyOwner(_caller: Principal) : Bool {
        return _caller == owner;
    };
    private func keyt(t: Text) : Trie.Key<Text> { return { key = t; hash = Text.hash(t) }; };
    
    /// get owner
    public query func getOwner() : async Principal{
        return owner;
    };
    /// change owner: _onlyOwner
    public shared(msg) func changeOwner(_newOwner: Principal) : async Bool{
        assert(_onlyOwner(msg.caller));
        owner := _newOwner;
        return true;
    };
    /// set TokenList
    public shared(msg) func setTokenList(_list: [(Text, Principal)]) : async Bool{
        assert(_onlyOwner(msg.caller));
        tokenList := _list;
        return true;
    };
    
    /// get TokenList
    public query func getTokenList() : async [(Text, Principal)]{
        return tokenList;
    };
    /// get tag
    public query func getTag(_account: Text) : async ?Text{  
        switch(Trie.get(tagList, keyt(_account), Text.equal)){
            case(?(tag)){ return ?tag;};
            case(_){ return null; };
        };
    };
    
    /// query canister status: Add itself as a controller, canister_id = Principal.fromActor(<your actor name>)
    public func canister_status() : async Monitee.canister_status {
        let ic : Monitee.IC = actor("aaaaa-aa");
        await ic.canister_status({ canister_id = Principal.fromActor(this) });
    };

    /// cycles receive
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };
    /// canister memory
    public query func getMemory() : async (Nat,Nat,Nat,Nat32){
        return (Prim.rts_memory_size(), Prim.rts_heap_size(), Prim.rts_total_allocation(),Prim.stableMemorySize());
    };

};
