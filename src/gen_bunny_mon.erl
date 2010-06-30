%% The MIT License

%% Copyright (c) David Reid <dreid@dreid.org>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
-module(gen_bunny_mon).
-author('David Reid <dreid@dreid.org').
-behaviour(gen_server).

-define(SERVER, ?MODULE).

-define(RECONNECT_DELAY, timer:seconds(1)).

-record(gen_bunny_mon,
        {
          connections=dict:new(),
          connect_fun
        }).

-record(connection,
        {
          consumer,
          info,
          connection_pid
        }).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/0, start_link/1, connect/1, get_state/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link() ->
    start_link(fun bunny_util:connect/1).

start_link(ConnectFun) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE,
                          [ConnectFun],
                          []).

connect(ConnectionInfo) ->
    gen_server:call(?SERVER, {connect, self(), ConnectionInfo}).

get_state() ->
    gen_server:call(?SERVER, get_state).
%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([ConnectFun]) ->
    {okg, #gen_bunny_mon{connect_fun=ConnectFun}}.

handle_call(get_state, _From, State) ->
    {reply, {ok, State}, State};
handle_call({connect, ConsumerPid, ConnectionInfo}, From, State) ->
    case do_connect(ConsumerPid, ConnectionInfo, State) of
          {{ok, {ConnectionPid, ChannelPid}}, State1} ->
            {reply, {ok, {ConnectionPid, ChannelPid}}, State1};
        {{connection_error, Error}, State1} ->
            error_logger:error_report(
              ["Could not connect, scheduling reconnect.",
               {error, Error}]),

            NotifyOnConnect = fun(Pids) ->
                                      gen_server:reply(From, {ok, Pids})
                              end,

            schedule_reconnect(ConsumerPid, ConnectionInfo, NotifyOnConnect),
            {noreply, State1}
    end;
handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'DOWN', ConnectionRef, process, _Object, _Info}, State) ->
    {Connection, State1} = remove_connection(ConnectionRef, State),

    ConsumerPid = Connection#connection.consumer,
    ConnectionInfo = Connection#connection.info,

    case is_process_alive(ConsumerPid) of
        true ->
            NotifyOnConnect = fun(Pids) ->
                                      ConsumerPid ! {reconnected, Pids}
                              end,

            schedule_reconnect(ConsumerPid, ConnectionInfo, NotifyOnConnect);
        false ->
            %% Don't schedule a reconnect if our ConsumerPid is down.
            error_logger:info_report(
              ["Missing consumer, not scheduling reconnect",
               {info, ConnectionInfo},
               {consumer_pid, ConsumerPid}])
    end,

    {noreply, State1};
handle_info({reconnect,
             ConsumerPid, ConnectionInfo,
             NotifyOnConnect},
            State) ->
    State2 = case do_connect(ConsumerPid, ConnectionInfo, State) of
                 {{ok, {ConnectionPid, ChannelPid}}, State1} ->
                     NotifyOnConnect({ConnectionPid, ChannelPid}),
                     State1;
                 {{connection_error, Error}, State1} ->
                     error_logger:error_report(
                       ["Could not connect, scheduling reconnect.",
                        {error, Error}]),
                     schedule_reconnect(
                       ConsumerPid, ConnectionInfo, NotifyOnConnect),
                     State1
             end,

    {noreply, State2};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
add_connection(ConsumerPid, ConnectionPid, ConnectionInfo,
               State=#gen_bunny_mon{connections=Connections}) ->
    ConnectionRef = erlang:monitor(process, ConnectionPid),

    State#gen_bunny_mon{
      connections=dict:store(ConnectionRef,
                             #connection{consumer=ConsumerPid,
                                         info=ConnectionInfo,
                                         connection_pid=ConnectionPid},
                             Connections)}.


remove_connection(ConnectionRef,
                  State=#gen_bunny_mon{connections=Connections}) ->
    true = erlang:demonitor(ConnectionRef),

    {ok, Connection} = dict:find(ConnectionRef, Connections),
    NewConnections = dict:erase(ConnectionRef, Connections),

    {upgrade_connection(Connection), State#gen_bunny_mon{
                   connections=NewConnections}}.


schedule_reconnect(ConsumerPid, ConnectionInfo, NotifyOnConnect) ->
    timer:send_after(?RECONNECT_DELAY,
                     {reconnect,
                      ConsumerPid, ConnectionInfo, NotifyOnConnect}).


do_connect(ConsumerPid, ConnectionInfo,
           State=#gen_bunny_mon{connect_fun=ConnectFun}) ->
    try
        {ok, {ConnectionPid, ChannelPid}} = ConnectFun(ConnectionInfo),
        {{ok, {ConnectionPid, ChannelPid}}, add_connection(
                                              ConsumerPid, ConnectionPid,
                                              ConnectionInfo,
                                              State)}
    catch
        Type:What ->
            {{connection_error, {{Type, What, erlang:get_stacktrace()},
                                 {connection_info, ConnectionInfo}}}, State}
    end.


upgrade_connection({connection, ConsumerPid, ConnectionInfo}) ->
    #connection{consumer=ConsumerPid,
                info=ConnectionInfo}.
