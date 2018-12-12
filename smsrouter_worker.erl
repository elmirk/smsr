%%
%%
%% dynamic worker, started when DLG_OPEN_IND received
%%


%% this should be used to construct binary to send to C node

%%my_list_to_binary(List) ->
%%    my_list_to_binary(List, <<>>).

%%my_list_to_binary([H|T], Acc) ->
%%    my_list_to_binary(T, <<Acc/binary,H>>);
%%my_list_to_binary([], Acc) ->
%%    Acc.


%%%-------------------------------------------------------------------
%%% @author root <root@ubuntu>
%%% @copyright (C) 2018, root
%%% @doc
%%%
%%% @end
%%% Created : 26 Nov 2018 by root <root@ubuntu>
%%%-------------------------------------------------------------------
-module(smsrouter_worker).

-behaviour(gen_server).

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).

%% definest should be checked before production!!
%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
-define(mapdt_open_ind, 2).
%%-define(mapdt_open_rsp, 16#81).
%%-define(mapdt_open_req, 16#01).
%%-define(mappn_result, 9).

-define(sccp_called, 1).
-define(sccp_calling, 3).
-define(ac_name, 11).
-define(dummy_dest, [16#12, 16#06, 0, 16#11, 16#04, 16#97, 16#15, 16#60, 16#52, 16#55, 16#05]).
-define(smsr_sccp_gt, [16#12, 16#08, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#20, 16#09]).
%% -define(mappn_applic_context, 16#0b).

-record(state, {}).
-record(dialog, {dlg_id, sccp_calling, sccp_called, ac_name}).
-record(sccp, {sccp_calling, sccp_called, ac_name}).

-include("dyn_defs.hrl").
-include("gctload.hrl").
%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(term()) -> {ok, Pid :: pid()} |
		      {error, Error :: {already_started, pid()}} |
		      {error, Error :: term()} |
		      ignore.
start_link(DlgId) ->
%% we should start dynamic worker without registered name
%%    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).
gen_server:start_link(?MODULE, DlgId, []).
%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
			      {ok, State :: term(), Timeout :: timeout()} |
			      {ok, State :: term(), hibernate} |
			      {stop, Reason :: term()} |
			      ignore.
%% this is from skeleton init([]) ->
init(DlgId)->
    process_flag(trap_exit, true),
    State = #dialog{dlg_id = DlgId},
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
			 {reply, Reply :: term(), NewState :: term()} |
			 {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
			 {reply, Reply :: term(), NewState :: term(), hibernate} |
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
			 {stop, Reason :: term(), NewState :: term()}.
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: term(), NewState :: term()}.
handle_cast({dlg_ind_open, Request}, State) ->
    io:format("received data in smsr worker ~p~n",[Request]),
    io:format("i have state already ~p~n", [State]),
    parse_data(binary:bin_to_list(Request)),
    io:format("sccp_calling from PD = ~p~n",[get(sccp_calling)]),
    io:format("sccp_called from PD = ~p~n",[get(sccp_called)]),
    io:format("ac name = ~p~n", [get(ac_name)]),

%% suppose we analyxe dlg_ind_open messages and SMSR allow to establish dialogue
%% Now let's send DLG_OPEN_RSP bask to C node!

%% {mapdt_open_rsp, DlgId, BinaryData}
%% should construct payload like this
%%  p810501000b0906070400000100140300
    Payload = create_map_open_rsp_payload(),
    gen_server:cast(broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, 64700, list_to_binary(Payload)}),

    {noreply, State};

handle_cast({srv_ind, Request}, State) ->
    io:format("srv_ind received ~n"),
    ok = parse_srv_data(binary:bin_to_list(Request)),
   io:format("invoke_id from PD = ~p~n",[get(invoke_id)]),
    io:format("msisdn from PD = ~p~n",[get(msisdn)]),
    io:format("sm rp pri name = ~p~n", [get(sm_rp_pri)]),
    io:format("sc addr = ~p~n", [get(sc_addr)]),
    {noreply, State};
handle_cast({delimit_ind, Request}, State) ->

%% TODO - we receive delimit and we should analyze what kind of component we recevied bevoe in SRV_IND
%% component should be saved in State like component list
%% Payload here should be like
%% p010b09060704000001001403010b1206001104970566152000030b120800110497056615200900
%% also we should choos dlg id for outgoing dlgs
    Payload = create_map_open_req_payload(),
    gen_server:cast(broker, {order, ?map_msg_dlg_req, ?mapdt_open_req, 64700, list_to_binary(Payload)}),
%% payload here
%% 
    Payload2 = map_srv_req_primitive(snd_rtism_req),
    gen_server:cast(broker, {order, ?map_msg_srv_req, ?mapst_snd_rtism_req, 64700, list_to_binary(Payload2)}),

    {noreply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: normal | term(), NewState :: term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
		State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
		  State :: term(),
		  Extra :: term()) -> {ok, NewState :: term()} |
				      {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
		    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================
%% parse binary data received from C node
%% this is for received mapdt_dlg_ind received from C node
parse_data([])->
    ok;
parse_data([?mapdt_open_ind | T])->
    parse_data(T);
parse_data([?sccp_called | T]) ->
    io:format("sccp called ~n"),
    Rest = parse_sccp(sccp_called, T),
    parse_data(Rest);
parse_data([?sccp_calling | T]) ->
    io:format("sccp calling ~n"),
    Rest = parse_sccp(sccp_calling, T),
    parse_data(Rest);
parse_data([?ac_name | T]) ->
    parse_ac(T).

parse_sccp(CallingOrCalled, Data = [H | T]) ->
    SccpAddr = lists:sublist(Data, 1, H + 1),
    put(CallingOrCalled, SccpAddr),
    io:format("sccp addr = ~p~n", [SccpAddr]),
    %%io:format("T = ~p~n", [T]),
    Rest = Data -- SccpAddr,
    %%io:format("rest = ~p~n", [Rest]),
    Rest.

parse_ac(Data = [H|T])->
    AcData = lists:sublist(Data, 1, H+1),
    put(ac_name, AcData),
    io:format("ac data = ~p~n", [AcData]).
    

%% pptr[0] = MAPDT_OPEN_RSP;
%%    pptr[1] = MAPPN_result;
%%    pptr[2] = 0x01;
%%    pptr[3] = result;
 %%   pptr[4] = MAPPN_applic_context;
%%    pptr[5] = (u8)dlg_info->ac_len;
%%    memcpy((void*)(pptr+6), (void*)dlg_info->app_context, dlg_info->ac_len);
%%    pptr[6+dlg_info->ac_len] = 0x00;


create_map_open_rsp_payload()->
    create_map_open_rsp_payload([?mapdt_open_rsp], mappn_result).
create_map_open_rsp_payload(List, mappn_result) ->
    Result = [?mappn_result, 1, 0],
    List2 = List ++ Result,
    create_map_open_rsp_payload(List2, mappn_applic_context);
create_map_open_rsp_payload(List, mappn_applic_context) ->
    ACname = [?mappn_applic_context] ++ get(ac_name),
    List2 = List ++ ACname,
    create_map_open_rsp_payload(List2, terminator);
create_map_open_rsp_payload(List, terminator) ->
    List ++ [0].

%% create payload for MAP_OPEN_REQ
%% we should construct DLG_REQ message with MAPDT_OPEN_REQ
%%* mapMsg_dlg_req tc7e2 i0001 f2e d15 s00 p010b09060704000001001403 010b1206001104970566152000030b120800110497056615200900 map open req

%% 01 - mapdt_open_req
%% 0b 09 060704000001001403 ac context
%% 010b 1206001104970566152000 destination address
%% 030b 1208001104970566152009 originating address
%% 00                         terminator

create_map_open_req_payload()->
    create_map_open_req_payload([?mapdt_open_req], mappn_applic_context).
create_map_open_req_payload(List, mappn_applic_context) ->
    List2 = List ++ [?mappn_applic_context] ++ get(ac_name),
    create_map_open_req_payload(List2, sccp_called);
create_map_open_req_payload(List, sccp_called) ->
    List2 = List ++ [?mappn_dest_address] ++ ?dummy_dest, 
    create_map_open_req_payload(List2, sccp_calling);
create_map_open_req_payload(List, sccp_calling) ->
    List2 = List ++ [?mappn_orig_address] ++ ?smsr_sccp_gt,
    List2 ++ [0].


%% parsing received srv_ind data from C node
parse_srv_data([?mapst_snd_rtism_ind | T]) ->
    parse_srv_data(T);
parse_srv_data([?mappn_invoke_id | [Length | T]]) ->
    InvokeId = lists:sublist(T, 1, Length ),
    put(invoke_id, InvokeId),
    Out = lists:nthtail(Length, T),
    parse_srv_data(Out);
parse_srv_data([?mappn_msisdn | [Length | T]]) ->
    Msisdn = lists:sublist(T, 1, Length ),
    put(msisdn, Msisdn),
    Out = lists:nthtail(Length, T),
    parse_srv_data(Out);
parse_srv_data([?mappn_sm_rp_pri | [Length | T]]) ->
    Smrppri = lists:sublist(T, 1, Length ),
    put(sm_rp_pri, Smrppri),
    Out = lists:nthtail(Length, T),
    parse_srv_data(Out);
parse_srv_data([?mappn_sc_addr | [Length | T]]) ->
    Smscaddr = lists:sublist(T, 1, Length ),
    put(sc_addr, Smscaddr),
    Out = lists:nthtail(Length, T),
    parse_srv_data(Out);
parse_srv_data([0])->
    ok.

-spec map_srv_req_primitive( atom() ) -> binary().
map_srv_req_primitive(snd_rtism_req)->
    [1, 2 ,3].
    



    
