/**
 * Module     : TokenFactory.mo
 * Author     : ICLighthouse Team
 * License    : GNU General Public License v3.0
 * Stability  : Experimental
 * Github     : https://github.com/iclighthouse/ICTokens
 */
import Prim "mo:⛔";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import CyclesWallet "./sys/CyclesWallet";
import DRC20 "DRC20";
import ICL "./lib/ICL";
import Deque "mo:base/Deque";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Tools "./lib/Tools";
import Types "./lib/DRC20";
import IC "./sys/IC";
import DRC207 "./lib/DRC207";

shared(installMsg) actor class TokenFactory() = this {

    type Token = {
        name: Text;
        symbol: Text;
        decimals: Nat8;
        moduleHash: ?[Nat8];
        note: Text;
        //canisterId: Principal;
        //score: Nat;
    };
    type TokenItem = (tokenCanisterId: Principal, tokenInfo: Token, score: Nat, star: Nat, sortTime: Time.Time);
    type TokenStatus = {
        status : { #stopped; #stopping; #running };
        memory_size : Nat;
        cycles : Nat;
        settings : {
            freezing_threshold : Nat;
            controllers : [Principal];
            memory_allocation : Nat;
            compute_allocation : Nat;
        };
        module_hash : ?[Nat8];
    };
    type CallbackLog = (Principal, Time.Time, Types.TxnRecord);

    private var blackhole_: Text = "7hdtw-jqaaa-aaaak-aaccq-cai";
    private stable var SYSTOKEN: ICL.Self = actor("5573k-xaaaa-aaaak-aacnq-cai");
    private stable var SYSTOKEN_EXP: Nat = 100000000; //decimals=8
    private stable var ic: IC.Self = actor("aaaaa-aa");
    private stable var owner: Principal = installMsg.caller;
    private stable var tokenList: [TokenItem] = []; // (canisterId, Token, score, star)
    private var tokens = HashMap.HashMap<Principal, [Principal]>(16, Principal.equal, Principal.hash);
    private var starTokens = HashMap.HashMap<Types.AccountId, [Principal]>(16, Blob.equal, Blob.hash);
    private var tokenOwner = HashMap.HashMap<Principal, Principal>(16, Principal.equal, Principal.hash);
    private stable var subscribedTokens: [Principal] = [];
    private stable var lastCallbacks = Deque.empty<CallbackLog>();
    //upgrade
    private stable var tokensEntries : [(Principal, [Principal])] = [];
    private stable var starTokensEntries : [(Types.AccountId, [Principal])] = [];
    private stable var tokenOwnerEntries : [(Principal, Principal)] = [];

    private func _onlyOwner(_caller: Principal) : Bool {
        return _caller == owner;
    };
    private func _onlyTokenOwner(_caller: Principal, _token: Principal) : Bool {
        switch(tokenOwner.get(_token)){
            case(?(owner_)){
                return _caller == owner_;
            };
            case(_){ return false; };
        };
    };
    private func _onlySubscribedToken(_token: Principal) : Bool {
        switch(Array.find(subscribedTokens, func (p:Principal):Bool { Principal.equal(p, _token) })){
            case(?(token)){ return true; };
            case(_){ return false; };
        };
    };
    private func _chargeFee(_from: Principal, _fee: Nat): async Bool {
        let res = await SYSTOKEN.drc20_transferFrom(Principal.toText(_from), Principal.toText(owner), 
        _fee, null, null, ?Blob.fromArray([1:Nat8]));
        switch(res){
            case(#ok(txid)){ return true; };
            case(_){ return false; };
        };
    };
    private func _feeLock(_from: Principal, _fee: Nat): async ?Types.Txid {
        let res = await SYSTOKEN.drc20_lockTransferFrom(Principal.toText(_from), Principal.toText(owner), 
        _fee, 60, null, null, null, ?Blob.fromArray([2:Nat8]));
        switch(res){
            case(#ok(txid)){ return ?txid; };
            case(_){ return null; };
        };
    };
    private func _feeExcute(_txid: Types.Txid): async Bool {
        let res = await SYSTOKEN.drc20_executeTransfer(_txid, #sendAll, null, null, null, null);
        switch(res){
            case(#ok(txid)){ return true; };
            case(_){ return false; };
        };
    };
    private func _feeFallback(_txid: Types.Txid): async Bool {
        let res = await SYSTOKEN.drc20_executeTransfer(_txid, #fallback, null, null, null, null);
        switch(res){
            case(#ok(txid)){ return true; };
            case(_){ return false; };
        };
    };
    private func _putTokens(_user: Principal, _token: Principal) : (){
        switch(tokens.get(_user)){
            case(?(arr)){
                switch(Array.find(arr, func (p:Principal):Bool{ if (Principal.equal(p, _token)) true else false; })){
                    case(?(v)){};
                    case(_){
                        var tokenArr = Tools.arrayAppend(arr, [_token]);
                        tokens.put(_user, tokenArr);
                    };
                };
            };
            case(_){
                tokens.put(_user, [_token]);
            };
        };
    };
    private func _putStarTokens(_user: Types.AccountId, _token: Principal) : (){
        //let user = Tools.principalToAccountBlob(_user);
        switch(starTokens.get(_user)){
            case(?(arr)){
                switch(Array.find(arr, func (p:Principal):Bool{ if (Principal.equal(p, _token)) true else false; })){
                    case(?(v)){};
                    case(_){
                        var tokenArr = Tools.arrayAppend(arr, [_token]);
                        starTokens.put(_user, tokenArr);
                    };
                };
            };
            case(_){
                starTokens.put(_user, [_token]);
            };
        };
    };

    private func _tokenCompare(x:TokenItem, y:TokenItem) : Order.Order{
        return Nat.compare(5000 - Nat.min(x.2 * 20 + x.3, 5000), 5000 - Nat.min(y.2 * 20 + y.3, 5000));
    };
    private func _getTokenInList(_token: Principal) : ?TokenItem{
        switch(Array.find(tokenList, func (item:TokenItem):Bool{ Principal.equal(item.0, _token) })){
            case(?(item)){ return ?item; };
            case(_){ return null; }
        };
    };
    private func _deleteTokenInList(_token: Principal) : (){
        tokenList := Array.filter(tokenList, func (item:TokenItem):Bool{ not(Principal.equal(item.0, _token)) });
    };
    private func _deleteToken(_user: Principal, _token: Principal) : (){
        switch(tokens.get(_user)){
            case(?(arr)){
                var tokenArr = Array.filter(arr, func (p:Principal):Bool{ not(Principal.equal(p, _token)) });
                if (tokenArr.size() == 0){
                    tokens.delete(_user);
                } else {
                    tokens.put(_user, tokenArr);
                };
            };
            case(_){};
        };
        tokenOwner.delete(_token);
    };
    private func _putSubscribedToken(_token: Principal) : (){
        _deleteSubscribedToken(_token);
        subscribedTokens := Tools.arrayAppend(subscribedTokens, [_token]);
    };
    private func _deleteSubscribedToken(_token: Principal) : (){
        subscribedTokens := Array.filter(subscribedTokens, func (p:Principal):Bool { not(Principal.equal(p, _token)) });
    };
    private func _deleteStarToken(_user: Principal, _token: Principal) : (){
        let user = Tools.principalToAccountBlob(_user, null);
        switch(starTokens.get(user)){
            case(?(arr)){
                var tokenArr = Array.filter(arr, func (p:Principal):Bool{ if (Principal.equal(p, _token)) false else true; });
                if (tokenArr.size() == 0){
                    starTokens.delete(user);
                } else {
                    starTokens.put(user, tokenArr);
                };
                if (tokenArr.size() < arr.size()){
                    switch(_getTokenInList(_token)){
                        case(?(item)){
                            tokenList := Array.map(tokenList, func (item:TokenItem):TokenItem{ 
                                if (Principal.equal(item.0, _token)){
                                    var star = item.3;
                                    if (star > 0){  star -= 1; };
                                    return (item.0, item.1, item.2, star, Time.now());
                                } else {
                                    return item;
                                };
                            });
                            if (Time.now() - item.4 > 8*3600*1000000000) { tokenList := Array.sort(tokenList, _tokenCompare); };
                        };
                        case(_){};
                    };
                };
            };
            case(_){};
        };
    };
    // get lastCallbacks
    private func _getLastCallbacks(_caller: ?Principal, _txn: ?Types.TxnRecord) : [CallbackLog]{
        var l = List.append(lastCallbacks.0, List.reverse(lastCallbacks.1));
        switch(_caller){
            case(?(caller)){
                switch(_txn){
                    case(?(txn)){
                        return Array.filter(List.toArray(l), func (item:CallbackLog):Bool{ Principal.equal(item.0, caller) and Blob.equal(item.2.txid, txn.txid) });
                    };
                    case(_){
                        return Array.filter(List.toArray(l), func (item:CallbackLog):Bool{ Principal.equal(item.0, caller) });
                    };
                };
            };
            case(_){
                return List.toArray(l);
            };
        };
    };
    // in lastCallbacks
    private func _inLastCallbacks(_caller: Principal, _txn: Types.TxnRecord) : Bool{
        let logs = _getLastCallbacks(?_caller, ?_txn);
        return logs.size() > 0;
    };
    //star it
    private func _starCallback(_data: [Nat8], _txn: Types.TxnRecord): (){
        let _tokenTextBlob: Blob = Blob.fromArray(_data);
        let _token = Principal.fromText(Option.get(Text.decodeUtf8(_tokenTextBlob),""));
        let txnFrom = _txn.transaction.from;
        switch(_getTokenInList(_token)){
            case(?(item)){
                tokenList := Array.map(tokenList, func (item:TokenItem):TokenItem{ 
                    if (Principal.equal(item.0, _token)){
                        _putStarTokens(txnFrom, _token);
                        return (item.0, item.1, item.2, item.3+1, Time.now());
                    } else {
                        return item;
                    };
                });
                if (Time.now() - item.4 > 8*3600*1000000000) { tokenList := Array.sort(tokenList, _tokenCompare); };
            };
            case(_){};
        };
    };
    public query func getStarTokens(_user: Principal) : async ?[Principal]{
        let user = Tools.principalToAccountBlob(_user, null);
        return starTokens.get(user);
    };
    public shared(msg) func cancelStar(_token: Principal) : async Bool{
        _deleteStarToken(msg.caller, _token);
        return true;
    };

    // change owner: _onlyOwner
    public shared(msg) func changeOwner(_newOwner: Principal) : async Bool{
        assert(_onlyOwner(msg.caller));
        owner := _newOwner;
        return true;
    };
    // Withdraw ICL
    public shared(msg) func ICLWithdraw(_to: Types.Address, _amount: Nat): async Types.TxnResult{
        assert(_onlyOwner(msg.caller));
        return await SYSTOKEN.drc20_transfer(_to, _amount, null, null, null);
    };
    public shared(msg) func ICLBurn(_amount: Nat): async Types.TxnResult{
        assert(_onlyOwner(msg.caller));
        return await SYSTOKEN.ictokens_burn(_amount, null, null, null);
    };
    
    /*
    record { totalSupply=1000000000000; decimals=8; gas=variant{token=10}; name=opt "ICLTokenTest"; symbol=opt "ICLTest"; metadata=null; founder=opt "ygqab-f3o5m-y547q-zyhwr-nwysd-3yayp-idsfg-6jv4w-g7y5n-bqjag-zae";}  
    */
    public shared(msg) func create(initArgs: Types.InitArgs) : async ?Principal {
        //assert(await _chargeFee(msg.caller, 100*SYSTOKEN_EXP));
        var feeTxid: ?Types.Txid = null;
        switch (await _feeLock(msg.caller, 100*SYSTOKEN_EXP)){
            case(?(txid)){ feeTxid := ?txid; };
            case(_){assert(false);};
        };
        try{
            Cycles.add(200000000000);
            let token = await DRC20.DRC20(initArgs);
            let tokenPrincipal = Principal.fromActor(token);
            let status = await ic.canister_status({ canister_id = tokenPrincipal; });
            tokenList := Tools.arrayAppend(tokenList, [(tokenPrincipal, {
                name = Option.get(initArgs.name,"");
                symbol = Option.get(initArgs.symbol,"");
                decimals = initArgs.decimals;
                moduleHash = status.module_hash;
                note = "";
            }, 50, 0, Time.now())]);
            tokenList := Array.sort(tokenList, _tokenCompare);
            _putTokens(msg.caller, tokenPrincipal);
            tokenOwner.put(tokenPrincipal, msg.caller);
            let res = await ic.update_settings({
                canister_id = tokenPrincipal; 
                settings={ 
                    compute_allocation = null;
                    controllers = ?[tokenPrincipal, Principal.fromText(blackhole_), msg.caller]; 
                    freezing_threshold = null;
                    memory_allocation = null;
                };
            });
            switch (feeTxid){
                case(?(txid)){ assert(await _feeExcute(txid)); };
                case(_){};
            };
            return ?tokenPrincipal;
        } catch(e){
            switch (feeTxid){
                case(?(txid)){ assert(await _feeFallback(txid)); };
                case(_){};
            };
        };
        return null;
    };
    //manage token in list: _onlyOwner
    public shared(msg) func updateTokenInList(_token: Principal, _info: Token, _score: Nat): async Bool{
        assert(_onlyOwner(msg.caller));
        switch(_getTokenInList(_token)){
            case(?(item)){
                let star = item.3;
                tokenList := Array.map(tokenList, func (item:TokenItem):TokenItem{ 
                    if (Principal.equal(item.0, _token)){
                        return (_token, _info, _score, star, Time.now());
                    } else {
                        return item;
                    };
                });
                tokenList := Array.sort(tokenList, _tokenCompare);
                return true;
            };
            case(_){ 
                tokenList := Tools.arrayAppend(tokenList, [(_token, _info, _score, 0, Time.now())]);
                tokenList := Array.sort(tokenList, _tokenCompare);
                return true;
             };
        };
        
    };
    // delete token in list: _onlyOwner
    public shared(msg) func deleteTokenInList(_token: Principal): async Bool{
        assert(_onlyOwner(msg.caller));
        _deleteTokenInList(_token);
        return true;
    };

    //token's Callback
    public shared(msg) func tokenCallback(txn: Types.TxnRecord) : async (){
        assert(_onlySubscribedToken(msg.caller));
        if (_inLastCallbacks(msg.caller, txn) or Time.now() > txn.timestamp + 8*3600*1000000000){
            return ();
        };
        lastCallbacks := Deque.pushFront(lastCallbacks, (msg.caller, Time.now(), txn));
        var size = List.size(lastCallbacks.0) + List.size(lastCallbacks.1);
        while (size > 2000){
            size -= 1;
            switch (Deque.popBack(lastCallbacks)){
                case(?(q, v)){
                    lastCallbacks := q;
                };
                case(_){};
            };
        };
        //StarIt   4bytes-operation[0:Nat8,0,0,1] + Text.encodeUtf8(Principal.toText(tokenPrincipal))
        let txnFrom = txn.transaction.from;
        let txnTo = txn.transaction.to;
        let txnValue = txn.transaction.value;
        let txnData = txn.transaction.data;
        let data: [Nat8] = Blob.toArray(Option.get(txn.transaction.data, Blob.fromArray([])));
        if (data.size() > 4){
            let operation: [Nat8] = Tools.slice<Nat8>(data, 0, ?3);
            if (Array.equal<Nat8>(operation, [0:Nat8,0,0,1], Nat8.equal) and txnValue >= 1*SYSTOKEN_EXP and 
            txnTo == Tools.principalToAccountBlob(Principal.fromActor(this), null)){
                let _data: [Nat8] = Tools.slice<Nat8>(data, 4, null);
                try{
                    _starCallback(_data, txn);
                } catch(e){};
            };
        };
    };
    //subscribe: _onlyOwner
    public shared(msg) func subscribe(_token: Principal): async Bool{
        assert(_onlyOwner(msg.caller));
        let token:DRC20.DRC20 = actor(Principal.toText(_token));
        let msgTypes: [Types.MsgType] = [#onTransfer,#onLock,#onExecute,#onApprove];
        let res = await token.drc20_subscribe(tokenCallback, msgTypes, null);
        if (res) { _putSubscribedToken(_token) };
        return res;
    };
    public shared(msg) func unsubscribe(_token: Principal): async Bool{
        assert(_onlyOwner(msg.caller));
        let token:DRC20.DRC20 = actor(Principal.toText(_token));
        let msgTypes: [Types.MsgType] = [];
        let res = await token.drc20_subscribe(tokenCallback, msgTypes, null);
        if (res) { _deleteSubscribedToken(_token) };
        return res;
    };
    public query func getCallbackLogs() : async [CallbackLog]{
        return Tools.slice(_getLastCallbacks(null, null), 0, ?50);
    };
    //modify controller: _onlyTokenOwner
    public shared(msg) func modifyControllers(_token: Principal, _controllers: [Principal]): async Bool{
        assert(_onlyTokenOwner(msg.caller, _token));
        let res = await ic.update_settings({
            canister_id = _token; 
            settings={ 
                compute_allocation = null;
                controllers = ?_controllers; 
                freezing_threshold = null;
                memory_allocation = null;
            };
        });
        return true;
    };
    //modify controller: _onlyTokenOwner
    public shared(msg) func modifyOwner(_token: Principal, _newOwner: Principal): async Bool{
        assert(_onlyTokenOwner(msg.caller, _token));
        let token:DRC20.DRC20 = actor(Principal.toText(_token));
        return await token.ictokens_changeOwner(_newOwner);
    };
    // delete token by user
    public shared(msg) func deleteToken(_token: Principal, _delFromList: Bool): async Bool{
        assert(_onlyTokenOwner(msg.caller, _token));
        _deleteToken(msg.caller, _token);
        if (_delFromList){
            _deleteTokenInList(_token);
        };
        return true;
    };
    // get user's tokens
    public query func getTokens(_user: Principal) : async [Principal]{
        switch(tokens.get(_user)){
            case(?(arr)){
                return arr;
            };
            case(_){return []; };
        };
    };
    
    // get tokens' list (_page is from 0)
    public query func getTokenList(_size: Nat, _page: Nat) : async [TokenItem]{
        assert(_size > 0);
        let length = tokenList.size();
        if (length == 0){ return []; };
        let from = _size * _page;
        var to = Nat.sub(_size * (_page+1), 1);
        if (to >= length) { to := Nat.sub(length,1); };
        var res: [TokenItem] = [];
        if (from <= to){
            for (i in Iter.range(from, to)){
                res := Tools.arrayAppend(res, [tokenList[i]]);
            };
        };
        return res;
    };
    // lock transfer test
    public shared(msg) func lockTransferTest(_token: Principal, _to: Types.Address, _value: Nat, _exec: Types.ExecuteType): 
    async ?Types.Txid{
        let token:DRC20.DRC20 = actor(Principal.toText(_token));
        var txid: ?Types.Txid = null;
        let res1 = await token.drc20_lockTransfer(_to, _value, 60:Nat32, null, null, null, ?Blob.fromArray([8:Nat8]));
        switch(res1){
            case(#ok(txid_)){ 
                txid := ?txid_;
                //do something
            };
            case(#err(e)){};
        };
        switch(txid){
            case(?(v)){
                let res2 = await token.drc20_executeTransfer(v, _exec, null, null, null, null);
            };
            case(_){};
        };
        return txid;
    };
    public shared(msg) func lockTransferFromTest(_token: Principal, _from: Types.Address, _to: Types.Address, 
    _value: Nat, _exec: Types.ExecuteType): async ?Types.Txid{
        let token:DRC20.DRC20 = actor(Principal.toText(_token));
        var txid: ?Types.Txid = null;
        let res1 = await token.drc20_lockTransferFrom(_from, _to, _value, 60:Nat32, null, null, null, ?Blob.fromArray([8:Nat8]));
        switch(res1){
            case(#ok(txid_)){ 
                txid := ?txid_;
                //do something
            };
            case(#err(e)){};
        };
        switch(txid){
            case(?(v)){
                let res2 = await token.drc20_executeTransfer(v, _exec, null, null, null, null);
            };
            case(_){};
        };
        return txid;
    };
    // token canister status (Only supports token's controller is Owner)
    public shared(msg) func tokenStatus(_token: Principal): async TokenStatus{
        return await ic.canister_status({ canister_id = _token; });
    };
    //cycles withdraw: _onlyOwner
    public shared(msg) func cyclesWithdraw(_wallet: Principal, _amount: Nat): async (){
        assert(_onlyOwner(msg.caller));
        let cyclesWallet: CyclesWallet.Self = actor(Principal.toText(_wallet));
        let balance = Cycles.balance();
        var value: Nat = _amount;
        if (balance <= _amount) {
            value := balance;
        };
        Cycles.add(value);
        await cyclesWallet.wallet_receive();
        //Cycles.refunded();
    };
    //canister memory
    public query func getMemory() : async (Nat,Nat,Nat){
        return (Prim.rts_memory_size(), Prim.rts_heap_size(), Prim.rts_total_allocation());
    };

    // DRC207 ICMonitor
    /// DRC207 support
    public func drc207() : async DRC207.DRC207Support{
        return {
            monitorable_by_self = true;
            monitorable_by_blackhole = { allowed = true; canister_id = ?Principal.fromText(blackhole_); };
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
    public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };
    /// timer tick
    // public func timer_tick(): async (){
    //     //
    // };

    /*
    * upgrade functions
    */
    system func preupgrade() {
        tokensEntries := Iter.toArray(tokens.entries());
        starTokensEntries := Iter.toArray(starTokens.entries());
        tokenOwnerEntries := Iter.toArray(tokenOwner.entries());
    };

    system func postupgrade() {
        tokens := HashMap.fromIter<Principal, [Principal]>(tokensEntries.vals(), 1, Principal.equal, Principal.hash);
        tokensEntries := [];
        starTokens := HashMap.fromIter<Types.AccountId, [Principal]>(starTokensEntries.vals(), 1, Blob.equal, Blob.hash);
        starTokensEntries := [];
        tokenOwner := HashMap.fromIter<Principal, Principal>(tokenOwnerEntries.vals(), 1, Principal.equal, Principal.hash);
        tokenOwnerEntries := [];
    };
};
