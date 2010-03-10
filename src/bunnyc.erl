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
-export([publish/3,
         publish/4,
         async_publish/3,
         async_publish/4,
         get/2,
         ack/2]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {connection, channel, exchange, queue, key}).

%%
%% API
%%
publish(Name, Key, Message) ->
    publish(Name, Key, Message, []).

publish(Name, Key, Message, Opts) ->
    gen_server:call(Name, {publish, Key, Message, Opts}).


async_publish(Name, Key, Message) ->
    async_publish(Name, Key, Message, []).

async_publish(Name, Key, Message, Opts) ->
    gen_server:cast(Name, {publish, Key, Message, Opts}).


get(Name, NoAck) ->
    gen_server:call(Name, {get, NoAck}).


ack(Name, Tag) ->
    gen_server:cast(Name, {ack, Tag}).


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


handle_call({publish, Key, Message, Opts}, _From,
            State = #state{channel=Channel, exchange=Exchange})
  when is_binary(Key), is_binary(Message) orelse ?is_message(Message),
       is_list(Opts) ->
    Resp = internal_publish(fun amqp_channel:call/3,
                            Channel, Exchange, Key, Message, Opts),
    {reply, Resp, State};

handle_call({get, NoAck}, _From,
            State = #state{channel=Channel, queue=Queue}) ->
    Resp = internal_get(Channel, Queue, NoAck),
    {reply, Resp, State};

handle_call(stop, _From,
            State = #state{channel=Channel, connection=Connection}) ->
    amqp_channel:close(Channel),
    amqp_connection:close(Connection),
    {stop, normal, ok, State}.

handle_cast({publish, Key, Message, Opts},
            State = #state{channel=Channel, exchange=Exchange})
  when is_binary(Key), is_binary(Message) orelse ?is_message(Message),
       is_list(Opts) ->
    internal_publish(fun amqp_channel:cast/3,
                     Channel, Exchange, Key, Message, Opts),
    {noreply, State};

handle_cast({ack, Tag}, State = #state{channel=Channel}) ->
    internal_ack(Channel, Tag),
    {noreply, State};

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
internal_publish(Fun, Channel, Exchange, Key, Message, Opts)
  when ?is_message(Message) ->
    Mandatory = proplists:get_value(mandatory, Opts, false),

    BasicPublish = #'basic.publish'{
      exchange = bunny_util:get_name(Exchange),
      routing_key = Key,
      mandatory = Mandatory},

    Fun(Channel, BasicPublish, Message);
internal_publish(Fun, Channel, Exchange, Key, Message, Opts)
  when is_binary(Message) ->
    internal_publish(Fun, Channel, Exchange, Key,
                     bunny_util:new_message(Message), Opts).


internal_get(Channel, Queue, NoAck) ->
    amqp_channel:call(Channel, #'basic.get'{queue=bunny_util:get_name(Queue),
                                            no_ack=NoAck}).


internal_ack(Channel, DeliveryTag) ->
    amqp_channel:cast(Channel, #'basic.ack'{delivery_tag=DeliveryTag}).

%%
%% Tests
%%

-include_lib("eunit/include/eunit.hrl").

bunnyc_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),
    ok.


bunnyc_stop(_) ->
    bunnyc:stop(bunnyc_test),

    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
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
    mock:expects(amqp_channel, close,
                 fun({dummy_channel}) ->
                         true
                 end,
                 ok),

    mock:expects(amqp_connection, close,
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
             {ok, Pid} = bunnyc:start_link(bunnyc_test, direct,
                                           <<"bunnyc.test">>, DummyFuns),
             ?assertEqual(is_pid(Pid), true),
             ?assertEqual(is_process_alive(Pid), true)
         end])}.



normal_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),
    {ok, _} = bunnyc:start_link(
                bunnyc_test, direct, <<"bunnyc.test">>,
                connect_and_declare_expects(<<"bunnyc.test">>)),
    stop_expects(),
    ok.


normal_stop(_) ->
    bunnyc:stop(bunnyc_test),
    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
    ok.


publish_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, call,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>},
                    Message}) when ?is_message(Message) ->
                       bunny_util:get_payload(Message) =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>))
         end])}.


async_publish_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, cast,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>},
                    Message}) when ?is_message(Message) ->
                       bunny_util:get_payload(Message) =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:async_publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>))
         end])}.


publish_message_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             ExpectedMessage = bunny_util:set_delivery_mode(
                                 bunny_util:new_message(<<"HELLO">>),
                                 2),

             mock:expects(
               amqp_channel, call,
               fun({dummy_channel, #'basic.publish'{exchange=Exchange,
                                                    routing_key=Key},
                    Message}) when ?is_message(Message) ->
                       Exchange =:= <<"bunnyc.test">>
                           andalso Key =:= <<"bunnyc.test">>
                           andalso ExpectedMessage =:= Message
               end,
               ok),
             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                ExpectedMessage))
         end])}.


async_publish_message_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             ExpectedMessage = bunny_util:set_delivery_mode(
                                 bunny_util:new_message(<<"HELLO">>),
                                 2),

             mock:expects(
               amqp_channel, cast,
               fun({dummy_channel, #'basic.publish'{exchange=Exchange,
                                                    routing_key=Key},
                    Message}) when ?is_message(Message) ->
                       Exchange =:= <<"bunnyc.test">>
                           andalso Key =:= <<"bunnyc.test">>
                           andalso ExpectedMessage =:= Message
               end,
               ok),
             ?assertEqual(ok, bunnyc:async_publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                ExpectedMessage))
         end])}.


publish_mandatory_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, call,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>,
                      mandatory = true},
                    Message}) when ?is_message(Message) ->
                       bunny_util:get_payload(Message) =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>, [{mandatory, true}]))
         end])}.


async_publish_mandatory_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, cast,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>,
                      mandatory = true},
                    Message}) when ?is_message(Message) ->
                       bunny_util:get_payload(Message) =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:async_publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>, [{mandatory, true}]))
         end])}.


get_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(amqp_channel, call,
                          fun({dummy_channel,
                               #'basic.get'{
                                 queue= <<"bunnyc.test">>,
                                 no_ack=false}}) ->
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
             mock:expects(amqp_channel, call,
                          fun({dummy_channel,
                               #'basic.get'{queue= <<"bunnyc.test">>,
                                            no_ack=true}}) ->
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
             mock:expects(amqp_channel, cast,
                          fun({dummy_channel, #'basic.ack'{
                                 delivery_tag= <<"sometag">>}}) ->
                                  true
                          end,
                          ok),
             ?assertEqual(ok, bunnyc:ack(bunnyc_test, <<"sometag">>))
         end])}.


%% These are mostly to placate cover.

unknown_cast_test() ->
    ?assertEqual({noreply, #state{}},
                 bunnyc:handle_cast(unknown_cast, #state{})).


unknown_info_test() ->
    ?assertEqual({noreply, #state{}},
                 bunnyc:handle_info(unknown_info, #state{})).


code_change_test() ->
    ?assertEqual({ok, #state{}}, bunnyc:code_change(ign, #state{}, ign)).
