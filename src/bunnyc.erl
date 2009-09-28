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
-module(bunnyc).
-author('Andy Gross <andy@andygross.org>').
-author('David Reid <dreid@dreid.org').

-behavior(gen_server).

-include_lib("gen_bunny.hrl").

-export([start_link/4, stop/1]).
-export([publish/3, get/2, ack/2]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {connection, channel, exchange, queue}).

%%
%% API
%%
publish(Name, Key, Payload) ->
    gen_server:call(Name, {publish, Key, Payload}).


get(Name, NoAck) ->
    gen_server:call(Name, {get, NoAck}).


ack(Name, Tag) ->
    gen_server:call(Name, {ack, Tag}).


start_link(Name, ConnectionInfo, DeclareInfo, Args) ->
    gen_server:start_link({local, Name}, ?MODULE, [ConnectionInfo, DeclareInfo, Args], []).


stop(Name) ->
    gen_server:call(Name, stop).


%%
%% Callbacks
%%

init([ConnectionInfo, DeclareInfo, Args]) ->
    ConnectFun = proplists:get_value(connect_fun, Args,
                                     fun bunny_util:connect/1),
    DeclareFun = proplists:get_value(declare_fun, Args,
                                     fun bunny_util:declare/2),

    {ConnectionPid, ChannelPid} = ConnectFun(ConnectionInfo),

    {Exchange, Queue} = DeclareFun(ChannelPid, DeclareInfo),

    {ok, #state{connection=ConnectionPid,
                channel=ChannelPid,
                exchange=Exchange,
                queue=Queue}}.


handle_call({publish, Key, Payload}, _From,
            State = #state{channel=Channel, exchange=Exchange})
  when is_binary(Key), is_binary(Payload) ->
    Resp = internal_publish(Channel, Exchange, Key, Payload),
    {reply, Resp, State};

handle_call({get, NoAck}, _From,
            State = #state{channel=Channel, queue=Queue}) ->
    Resp = internal_get(Channel, Queue, NoAck),
    {reply, Resp, State};

handle_call({ack, Tag}, _From, State = #state{channel=Channel}) ->
    Resp = internal_ack(Channel, Tag),
    {reply, Resp, State};

handle_call(stop, _From,
            State = #state{channel=Channel, connection=Connection}) ->
    lib_amqp:close_channel(Channel),
    lib_amqp:close_connection(Connection),
    {stop, normal, ok, State}.


handle_cast(_Request, State) ->
    {noreply, State}.


handle_info(_Info, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

%%
%% Internal
%%

internal_publish(Channel, Exchange, Key, Payload) ->
    lib_amqp:publish(Channel, bunny_util:get_name(Exchange), Key, Payload),
    ok.


internal_get(Channel, Queue, NoAck) ->
    lib_amqp:get(Channel, bunny_util:get_name(Queue), NoAck).


internal_ack(Channel, DeliveryTag) ->
    lib_amqp:ack(Channel, DeliveryTag).

%%
%% Tests
%%

-include_lib("eunit/include/eunit.hrl").

bunnyc_setup() ->
    {ok, _} = mock:mock(lib_amqp),
    ok.


bunnyc_stop(_) ->
    bunnyc:stop(bunnyc_test),

    mock:verify_and_stop(lib_amqp),
    ok.


connect_and_declare_expects(TestName) ->
    [{connect_fun,
      fun(direct) ->
              {dummy_conn, dummy_channel}
      end},

     {declare_fun,
      fun(dummy_channel, N) when N =:= TestName ->
              {#'exchange.declare'{exchange = TestName},
               #'queue.declare'{queue = TestName}}
      end}].


stop_expects() ->
    mock:expects(lib_amqp, close_channel,
                 fun({dummy_channel}) ->
                         true
                 end,
                 ok),

    mock:expects(lib_amqp, close_connection,
                 fun({dummy_conn}) ->
                         true
                 end,
                 ok),
    ok.


bunnyc_test_() ->
    {setup, fun bunnyc_setup/0, fun bunnyc_stop/1,
     ?_test(
        [begin
             DummyFuns = connect_and_declare_expects(<<"bunnyc.test">>),
             stop_expects(),
             {ok, _} = bunnyc:start_link(bunnyc_test, direct,
                                         <<"bunnyc.test">>, DummyFuns)
         end])}.



normal_setup() ->
    {ok, _} = mock:mock(lib_amqp),
    {ok, _} = bunnyc:start_link(
                bunnyc_test, direct, <<"bunnyc.test">>,
                connect_and_declare_expects(<<"bunnyc.test">>)),
    stop_expects(),
    ok.


normal_stop(_) ->
    bunnyc:stop(bunnyc_test),
    mock:verify_and_stop(lib_amqp),
    ok.


publish_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(lib_amqp, publish,
                          fun({dummy_channel, <<"bunnyc.test">>,
                               <<"bunnyc.test">>, <<"HELLO GOODBYE">>}) ->
                                  true
                          end,
                          ok),

             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>))
         end])}.


get_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(lib_amqp, get,
                          fun({dummy_channel, <<"bunnyc.test">>, false}) ->
                                  true
                          end,
                          {<<"sometag">>,
                           bunny_util:new_message(<<"somecontent">>)}),
             ?assertEqual({<<"sometag">>,
                           bunny_util:new_message(<<"somecontent">>)},
                          bunnyc:get(bunnyc_test, false))
        end])}.


get_noack_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(lib_amqp, get,
                          fun({dummy_channel, <<"bunnyc.test">>, true}) ->
                                  true
                          end,
                          bunny_util:new_message(<<"somecontent">>)),
             ?assertEqual(bunny_util:new_message(<<"somecontent">>),
                          bunnyc:get(bunnyc_test, true))
        end])}.


ack_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(lib_amqp, ack,
                          fun({dummy_channel, <<"sometag">>}) ->
                                  true
                          end,
                          ok),
             ?assertEqual(ok, bunnyc:ack(bunnyc_test, <<"sometag">>))
         end])}.
