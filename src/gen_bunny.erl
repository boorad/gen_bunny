%% The MIT License

%% Copyright (c) David Reid <dreid@dreid.org>, Andy Gross <andy@andygross.org>

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

%% @doc The gen_bunny RabbitMQ consumer behavior.
-module(gen_bunny).
-author('Andy Gross <andy@andygross.org>').
-author('David Reid <dreid@dreid.org').
-behavior(gen_server).
-include_lib("gen_bunny.hrl").

-export([start_link/4]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([behaviour_info/1]).
-export([get_connection/1,
         get_channel/1,
         get_consumer_tag/1,
         stop/1]).

-record(state, {mod, 
                modstate, 
                channel, 
                connection,
                queue, 
                consumer_tag}).

behaviour_info(callbacks) ->
    [{init, 1},
     {handle_message, 2},
     {terminate, 2}];
behaviour_info(_) -> 
    undefined.

start_link(Module, ConnectionInfo, QueueName, InitArgs) 
  when is_tuple(ConnectionInfo), is_binary(QueueName), is_list(InitArgs)  ->
    gen_server:start_link(
      ?MODULE, 
      [Module,ConnectionInfo, QueueName, InitArgs], 
      []).

init([Module, ConnectionInfo, QueueName, InitArgs]) ->
    case Module:init(InitArgs) of
        {ok, ModState} ->
            case connect_and_subscribe(ConnectionInfo, QueueName) of
                {ok, ChannelPid, ConnectionPid} ->
                    %% TODO:  monitor channel/connection pids?
                    {ok, #state{mod=Module, 
                                modstate=ModState,
                                channel=ChannelPid,
                                connection=ConnectionPid,
                                queue=QueueName}};
                Err ->
                    Module:terminate(Err, ModState),
                    Err
            end;
        Error ->
            Error
    end.

stop(Pid) when is_pid(Pid) ->
    gen_server:cast(Pid, stop).

get_connection(Pid) when is_pid(Pid) ->
    gen_server:call(Pid, get_connection).

get_channel(Pid) when is_pid(Pid) ->
    gen_server:call(Pid, get_channel).

get_consumer_tag(Pid) when is_pid(Pid) ->
    gen_server:call(Pid, get_consumer_tag).

handle_call(get_connection, _From, State=#state{connection=Connection}) ->
    {reply, Connection, State};
handle_call(get_channel, _From, State=#state{channel=Channel}) ->
    {reply, Channel, State};
handle_call(get_consumer_tag, _From, State=#state{consumer_tag=CTag}) ->
    {reply, CTag, State}.

handle_cast(stop, State=#state{channel=Channel, consumer_tag=CTag, connection=Connection}) ->
    ok = lib_amqp:unsubscribe(Channel, CTag),
    ok = lib_amqp:teardown(Connection, Channel),
    {stop, normal, State}.

handle_info({#'basic.deliver'{},
            {content, _ClassId, _Props, _PropertiesBin, [Payload]}},
            State=#state{mod=Module, modstate=ModState}) ->
    %% TODO: figure out what fields we want to expose from the 'P_basic' record
    %% TODO: decode_properties is failing for me - do we even need to do this?
    %%#'P_basic'{} = rabbit_framing:decode_properties(ClassId, PropertiesBin),
    case Module:handle_message(Payload, ModState) of
        {noreply, NewModState} ->
            {noreply, State#state{modstate=NewModState}};
        {noreply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {noreply, State#state{modstate=NewModState}, A};
        {stop, Reason, NewModState} ->
            {stop, Reason, State#state{modstate=NewModState}}
    end;
handle_info(#'basic.consume_ok'{consumer_tag=CTag}, State=#state{}) ->
    {noreply, State#state{consumer_tag=CTag}}.
    

terminate(Reason, #state{mod=Mod, modstate=ModState}) ->
    Mod:terminate(Reason, ModState),
    ok.

code_change(_OldVersion, State, _Extra) ->
    %% TODO:  support code changes?
    {ok, State}.

%% TODO: better error handling here.
connect_and_subscribe({direct, Username, Password}, QueueName) ->
    %% TODO: link? 
    ConnectionPid = amqp_connection:start_direct(Username, Password),
    ChannelPid = amqp_connection:open_channel(ConnectionPid),
    lib_amqp:subscribe(ChannelPid, QueueName, self()),
    {ok, ChannelPid, ConnectionPid};
connect_and_subscribe({network, Host, Port, Username, Password, VHost}, 
                      QueueName) ->
    
    ConnectionPid = amqp_connection:start_network(Username, Password, Host,
                                                  Port, VHost),
    ChannelPid = amqp_connection:open_channel(ConnectionPid),
    lib_amqp:subscribe(ChannelPid, QueueName, self()),
    {ok, ChannelPid, ConnectionPid}.


    
