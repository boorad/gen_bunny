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
-module(example_gb).
-behavior(gen_bunny).

-export([start_link/1,
         init/1,
         handle_message/2,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2]).

-export([get_messages/1]).

-include_lib("gen_bunny.hrl").

-record(state, {messages=[]}).

open_connection(direct) ->
    Connection = lib_amqp:start_connection(),
    Channel = lib_amqp:start_channel(Connection),
    {Connection, Channel};
open_connection(network) ->
    Connection = amqp_connection:start_network("guest", "guest", "127.0.0.1", 
                                               ?PROTOCOL_PORT, <<"/">>),
    Channel = lib_amqp:start_channel(Connection),
    {Connection, Channel}.

setup(Type) ->
    {_Connection, Channel} = open_connection(Type),
    %% TODO : need utility stuff for these
    Exchange = bunny_util:set_durable(
                 bunny_util:new_exchange(<<"bunny.test">>), true),
    Queue = bunny_util:set_durable(
              bunny_util:new_queue(<<"bunny.test">>), true),
    _Binding = bunny_util:new_binding(<<"bunny.test">>, <<"bunny.test">>,
                                      <<"bunny.test">>),    
    amqp_channel:call(Channel, Exchange),
    amqp_channel:call(Channel, Queue),
    lib_amqp:bind_queue(Channel, <<"bunny.test">>, <<"bunny.test">>,
                        <<"bunny.test">>).
    

start_link(Type) ->
    setup(Type),
    gen_bunny:start_link(?MODULE, {direct, "guest", "guest"}, 
                         <<"bunny.test">>, []).

init([]) -> 
    {ok, #state{}}.

get_messages(Pid) ->
    gen_bunny:call(Pid, get_messages).

handle_message(Message, State=#state{messages=Messages}) -> 
    NewMessages = [Message|Messages],
    {noreply, State#state{messages=NewMessages}}.

handle_call(get_messages, _From, State=#state{messages=Messages}) -> 
    {reply, Messages, State}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info(_Info, State) -> {noreply, State}.

terminate(Reason, _State) -> 
    io:format("~p terminating with reason ~p~n", [?MODULE, Reason]),
    ok.


%%
%% Tests
%%

-include_lib("eunit/include/eunit.hrl").

