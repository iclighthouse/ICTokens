/**
 * Module     : ICTokensScan.mo
 * Author     : ICLighthouse Team
 * License    : GNU General Public License v3.0
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICTokens
 */
import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import DRC207 "./lib/DRC207";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Trie "mo:base/Trie";
import Tools "./lib/Tools";

shared(installMsg) actor class ICTokensScan() = this {

    private stable var owner: Principal = installMsg.caller;
    private stable var tokenList: [(symbol: Text, canisterId: Principal)] = []; 
    private stable var swapList: [(symbol: Text, canisterId: Principal)] = [];
    private stable var tagList: Trie.Trie<Text, [Text]> = Trie.empty(); 

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
        tokenList := Tools.arrayAppend(tokenList, _list);
        return true;
    };
    public shared(msg) func removeTokenList(_token: Principal) : async Bool{
        assert(_onlyOwner(msg.caller));
        tokenList := Array.filter(tokenList, func (item: (Text, Principal)): Bool{ item.1 != _token });
        return true;
    };
    /// set SwapList
    public shared(msg) func setSwapList(_list: [(Text, Principal)]) : async Bool{
        assert(_onlyOwner(msg.caller));
        swapList := Tools.arrayAppend(swapList, _list);
        return true;
    };
    public shared(msg) func removeSwapList(_swap: Principal) : async Bool{
        assert(_onlyOwner(msg.caller));
        swapList := Array.filter(swapList, func (item: (Text, Principal)): Bool{ item.1 != _swap });
        return true;
    };
    
    /// get TokenList
    public query func getTokenList() : async [(Text, Principal)]{
        return tokenList;
    };
    /// get SwapList
    public query func getSwapList() : async [(Text, Principal)]{
        return swapList;
    };
    /// set tag
    public shared(msg) func setTag(_account: Text, _tag: Text) : async Bool{  
        assert(_onlyOwner(msg.caller));
        switch(Trie.get(tagList, keyt(_account), Text.equal)){
            case(?(tags)){ tagList := Trie.put(tagList, keyt(_account), Text.equal, Tools.arrayAppend(tags, [_tag])).0; };
            case(_){ tagList := Trie.put(tagList, keyt(_account), Text.equal, [_tag]).0; };
        };
        return true;
    };
    public shared(msg) func removeTag(_account: Text, _tag: Text) : async Bool{  
        assert(_onlyOwner(msg.caller));
        switch(Trie.get(tagList, keyt(_account), Text.equal)){
            case(?(tags)){ tagList := Trie.put(tagList, keyt(_account), Text.equal, Array.filter(tags, func (item:Text):Bool{ item != _tag })).0; };
            case(_){ };
        };
        return true;
    };
    /// get tag
    public query func getTag(_account: Text) : async [Text]{  
        switch(Trie.get(tagList, keyt(_account), Text.equal)){
            case(?(tags)){ return tags;};
            case(_){ return []; };
        };
    };

    /// cycles receive
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };
    /// canister memory
    public query func getMemory() : async (Nat,Nat,Nat){
        return (Prim.rts_memory_size(), Prim.rts_heap_size(), Prim.rts_total_allocation());
    };

    // DRC207 ICMonitor
    /// DRC207 support
    public func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = true;
            monitorable_by_blackhole = { allowed = true; canister_id = ?Principal.fromText("7hdtw-jqaaa-aaaak-aaccq-cai"); };
            cycles_receivable = true;
            timer = { enable = false; interval_seconds = null; }; 
        };
    };
    /// canister_status
    public func canister_status() : async DRC207.canister_status {
        let ic : DRC207.IC = actor("aaaaa-aa");
        await ic.canister_status({ canister_id = Principal.fromActor(this) });
    };
    /// receive cycles
    // public func wallet_receive(): async (){
    //     let amout = Cycles.available();
    //     let accepted = Cycles.accept(amout);
    // };
    /// timer tick
    // public func timer_tick(): async (){
    //     //
    // };

};
