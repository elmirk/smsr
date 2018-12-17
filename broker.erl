%%%-------------------------------------------------------------------
%%% @author root <root@ubuntu>
%%% @copyright (C) 2018, root
%%% @doc
%%%
%%% @end
%%% Created : 26 Nov 2018 by root <root@ubuntu>
%%%-------------------------------------------------------------------
-module(broker).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).

-ifdef(prod).
-define(c_node, 'c1@ubuntu').
-else.
-define(c_node, 'c1@elmir-N56VZ').
-endif.

-record(state, {o_dialogs}).

-include("gctload.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
		      {error, Error :: {already_started, pid()}} |
		      {error, Error :: term()} |
		      ignore.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server,
%% Prepare didpid ETS table.
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
			      {ok, State :: term(), Timeout :: timeout()} |
			      {ok, State :: term(), hibernate} |
			      {stop, Reason :: term()} |
			      ignore.
init([]) ->
    process_flag(trap_exit, true),
    SeqList = lists:seq(0, 10),
    Q = queue:from_list(SeqList),
    Result = ets:new(didpid, [set, named_table]),
    ets:new(piddid, [set, named_table]),
    put(sid, 0),
    State = #state{o_dialogs = Q},
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
handle_call(get_sid, _From, State) ->
    Sid = get(sid),
    NewSid = Sid + 1,
    put(sid, NewSid),
    {reply, Sid, State};

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
%% receive mapdt_open_rsp from smsrouter_worker
handle_cast({Worker, MsgType = ?map_msg_dlg_req, PrimitiveType = ?mapdt_open_req, Data}, State)->
    io:format("map msg dlg req + mapdt open request ~n"),
%%    ODlgID = 
    {{value, ODlgId}, NewQueue} = queue:out(State#state.o_dialogs),
    NewState = State#state{o_dialogs=NewQueue},
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    ets:insert(didpid, {ODlgId, Worker}),
    ets:insert(piddid, {Worker, ODlgId}),
    io:format("didpid = ~p~n",[ets:tab2list(didpid)]),
    io:format("piddid = ~p~n",[ets:tab2list(piddid)]),
    {noreply, NewState};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_snd_rtism_req, Data}, State)->
    %%io:format("send back to c node ~n"),
%% TODO!! what about DlgId here!!!!
    [{_, ODlgId}] = ets:lookup(piddid, Worker),
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
%% maybe this is not good idea, but we send delimit automaticaly from broker
%% alternatives - send delimit from dyn worker or send delimit in C code ?
    Data2 = list_to_binary([5, 0]),
    {any, ?c_node} ! {?map_msg_dlg_req, ?mapdt_delimiter_req, ODlgId, Data2},
    {noreply, State};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_snd_rtism_rsp, Data}, State)->
    %%io:format("send back to c node ~n"),
%% TODO!! what about DlgId here!!!!
    [{_, ODlgId}] = ets:lookup(piddid, Worker),
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    {noreply, State};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType =?mapst_snd_rtism_rsp, DlgId, Data}, State)->
    {any, ?c_node} ! {MsgType, PrimitiveType, DlgId, Data},
    {noreply, State};

handle_cast({Worker, MsgType, PrimitiveType, DlgId, Data}, State)->
    io:format("send back MAP MT FORWARD SM ACK to c node ~n"),
    {any, ?c_node} ! {MsgType, PrimitiveType, DlgId, Data},
    {noreply, State};
handle_cast(_Request, State) ->
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
%% handle messages from map_user.c
handle_info({dlg_ind_open, DlgId, Data}, State) ->
%%we should start dynamic worker for each OPEN_DLG_IND from C node
    {ok, Pid} = smsrouter_worker:start_link(DlgId),
    ets:insert(didpid, {DlgId, Pid}),
    io:format("worker with pid started = ~p~n",[Pid]),
    gen_server:cast(Pid, {dlg_ind_open, Data}),
    {noreply, State};

handle_info({srv_ind, DlgId, Data}, State) ->
    io:format("srv ind received in broker with DlgId = ~p~n",[DlgId]),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {srv_ind, Data}),
    {noreply, State};

handle_info({delimit_ind, DlgId, Data}, State) ->
    io:format("Receive delimit ind in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {delimit_ind, Data}),
    {noreply, State};

handle_info({mapdt_close_ind, DlgId, Data}, State) ->
    io:format("Receive mapdt_close_ind in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    io:format("mapdt close ind in broker received: Pid = ~p, DlgId = ~p ~n",[Pid, DlgId]),
    gen_server:cast(Pid, {mapdt_close_ind, Data}),
    {noreply, State};




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
