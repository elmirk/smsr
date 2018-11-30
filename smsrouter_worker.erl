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

-define(mapdt_open_ind, 2).
-define(sccp_called, 1).
-define(sccp_calling, 3).
-define(ac_name, 11).

-record(state, {}).
-record(dialog, {dlg_id, sccp_calling, sccp_called, ac_name}).
-record(sccp, {sccp_calling, sccp_called, ac_name}).


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
    
