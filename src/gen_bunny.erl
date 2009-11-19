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

-export([call/2,
         call/3,
         cast/2]).

-export([get_connection/1,
         get_channel/1,
         get_consumer_tag/1,
         ack/1,
         ack/2,
         stop/1]).

-record(state, {declare_fun,
                connect_fun,
                mod,
                modstate,
                channel,
                connection,
                queue,
                connection_info,
                declare_info,
                consumer_tag,
                no_ack,
                channel_mon,
                connection_mon}).

behaviour_info(callbacks) ->
    [{init, 1},
     {handle_message, 2},
     {handle_call, 3},
     {handle_cast, 2},
     {handle_info, 2},
     {terminate, 2}];
behaviour_info(_) ->
    undefined.

start_link(Module, ConnectionInfo, DeclareInfo, InitArgs)
  when is_atom(ConnectionInfo) orelse is_tuple(ConnectionInfo),
       is_binary(DeclareInfo) orelse is_tuple(DeclareInfo),
       is_list(InitArgs) ->
    gen_server:start_link(
      ?MODULE,
      [Module, ConnectionInfo, DeclareInfo, InitArgs],
      []).

call(Name, Request) ->
    gen_server:call(Name, Request).

call(Name, Request, Timeout) ->
    gen_server:call(Name, Request, Timeout).

cast(Dest, Request) ->
    gen_server:cast(Dest, Request).


init([Module, ConnectionInfo, DeclareInfo, InitArgs0]) ->
    {NoAck, InitArgs1} = get_opt(no_ack, InitArgs0, true),
    {ConnectFun, InitArgs2} = get_opt(connect_fun, InitArgs1,
                                      fun bunny_util:connect/1),
    {DeclareFun, InitArgs3} = get_opt(declare_fun, InitArgs2,
                                      fun bunny_util:declare/2),

    case Module:init(InitArgs3) of
        {ok, ModState} ->
            case connect_declare_subscribe(
                   ConnectFun, DeclareFun,
                   ConnectionInfo, DeclareInfo, NoAck) of
                {ok, ConnectionPid, ChannelPid, QueueName} ->
                    ChannelRef = erlang:monitor(process, ChannelPid),
                    ConnectionRef = erlang:monitor(process, ConnectionPid),
                    {ok, #state{connect_fun=ConnectFun,
                                declare_fun=DeclareFun,
                                mod=Module,
                                modstate=ModState,
                                channel=ChannelPid,
                                connection=ConnectionPid,
                                connection_info=ConnectionInfo,
                                declare_info=DeclareInfo,
                                queue=QueueName,
                                no_ack=NoAck,
                                channel_mon=ChannelRef,
                                connection_mon=ConnectionRef}};
                {_ErrClass, {error, Reason}} ->
                    Module:terminate(Reason, ModState),
                    {stop, Reason}
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

ack(Tag) ->
    ack(self(), Tag).

ack(Pid, Tag) when is_pid(Pid), is_integer(Tag) ->
    gen_server:cast(Pid, {ack, Tag}).

handle_call(get_connection, _From, State=#state{connection=Connection}) ->
    {reply, Connection, State};
handle_call(get_channel, _From, State=#state{channel=Channel}) ->
    {reply, Channel, State};
handle_call(get_consumer_tag, _From, State=#state{consumer_tag=CTag}) ->
    {reply, CTag, State};
handle_call(Request, From, State=#state{mod=Module, modstate=ModState}) ->
    case Module:handle_call(Request, From, ModState) of
        {reply, Reply, NewModState} ->
            {reply, Reply, State#state{modstate=NewModState}};
        {reply, Reply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {reply, Reply, State#state{modstate=NewModState}, A};
        {noreply, NewModState} ->
            {noreply, State#state{modstate=NewModState}};
        {noreply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {noreply, State#state{modstate=NewModState}, A};
        {stop, Reason, NewModState} ->
            {stop, Reason, State#state{modstate=NewModState}};
        {stop, Reason, Reply, NewModState} ->
            {stop, Reason, Reply, State#state{modstate=NewModState}}
  end.

handle_cast(stop, State=#state{channel=Channel, consumer_tag=CTag, connection=Connection}) ->
    ok = lib_amqp:unsubscribe(Channel, CTag),
    ok = lib_amqp:teardown(Connection, Channel),
    {stop, normal, State};
handle_cast({ack, Tag}, State=#state{channel=Channel}) ->
    lib_amqp:ack(Channel, Tag),
    {noreply, State};
handle_cast(Msg, State=#state{mod=Module, modstate=ModState}) ->
    case Module:handle_cast(Msg, ModState) of
        {noreply, NewModState} ->
            {noreply, State#state{modstate=NewModState}};
        {noreply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {noreply, State#state{modstate=NewModState}, A};
        {stop, Reason, NewModState} ->
            {stop, Reason, State#state{modstate=NewModState}}
    end.

handle_info({Envelope=#'basic.deliver'{},
             Message0},
            State=#state{no_ack=NoAck, mod=Module, modstate=ModState})
  when ?is_message(Message0) ->
    Message1 = rabbit_binary_parser:ensure_content_decoded(Message0),

    Message = case NoAck of
                  true ->
                      Message1;
                  false ->
                      {Envelope#'basic.deliver'.delivery_tag, Message1}
              end,

    case Module:handle_message(Message, ModState) of
        {noreply, NewModState} ->
            {noreply, State#state{modstate=NewModState}};
        {noreply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {noreply, State#state{modstate=NewModState}, A};
        {stop, Reason, NewModState} ->
            {stop, Reason, State#state{modstate=NewModState}}
    end;
handle_info(#'basic.consume_ok'{consumer_tag=CTag}, State=#state{}) ->
    {noreply, State#state{consumer_tag=CTag}};
handle_info({'DOWN', MonitorRef, process, _Object, _Info},
            State=#state{channel_mon=ChannelRef,
                         connection=Connection,
                         declare_fun=DeclareFun,
                         declare_info=DeclareInfo,
                         no_ack=NoAck})
  when MonitorRef =:= ChannelRef ->
    true = erlang:demonitor(ChannelRef),
    Channel = lib_amqp:start_channel(Connection),
    NewChannelRef = erlang:monitor(process, Channel),
    {ok, QueueName} =
        declare_subscribe(
          Channel, DeclareFun, DeclareInfo, NoAck),

    {noreply, State#state{queue=QueueName,
                          channel=Channel,
                          channel_mon=NewChannelRef}};
handle_info({'DOWN', MonitorRef, process, _Object, _Info},
            State=#state{channel_mon=ChannelRef,
                         connection_mon=ConnectionRef,
                         connect_fun=ConnectFun,
                         connection_info=ConnectionInfo,
                         declare_fun=DeclareFun,
                         declare_info=DeclareInfo,
                         no_ack=NoAck})
  when MonitorRef =:= ConnectionRef ->
    true = erlang:demonitor(ChannelRef),
    true = erlang:demonitor(ConnectionRef),
    {ok, NewConnection, NewChannel, QueueName} =
        connect_declare_subscribe(
          ConnectFun, DeclareFun, ConnectionInfo, DeclareInfo, NoAck),

    NewConnectionRef = erlang:monitor(process, NewConnection),
    NewChannelRef = erlang:monitor(process, NewChannel),

    {noreply, State#state{queue=QueueName,
                          connection=NewConnection,
                          channel=NewChannel,
                          channel_mon=NewChannelRef,
                          connection_mon=NewConnectionRef}};
handle_info(Info, State=#state{mod=Module, modstate=ModState}) ->
    io:format("Unknown info message: ~p~n", [Info]),
    case Module:handle_info(Info, ModState) of
        {noreply, NewModState} ->
            {noreply, State#state{modstate=NewModState}};
        {noreply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {noreply, State#state{modstate=NewModState}, A};
        {stop, Reason, NewModState} ->
            {stop, Reason, State#state{modstate=NewModState}}
    end.


terminate(Reason, #state{mod=Mod, modstate=ModState}) ->
    io:format("gen_bunny terminating with reason ~p~n", [Reason]),
    Mod:terminate(Reason, ModState),
    ok.

code_change(_OldVersion, State, _Extra) ->
    %% TODO:  support code changes?
    {ok, State}.

%% TODO: better error handling here.
connect_declare_subscribe(ConnectFun, DeclareFun,
                          ConnectionInfo, DeclareInfo, NoAck) ->
    %% TODO: link?
    case catch ConnectFun(ConnectionInfo) of
        {'EXIT', {Reason, _Stack}} ->
            Reason;
        {ConnectionPid, ChannelPid} when is_pid(ConnectionPid),
                                         is_pid(ChannelPid) ->
            case declare_subscribe(ChannelPid, DeclareFun,
                                   DeclareInfo, NoAck) of
                {ok, QueueName} ->
                    {ok, ConnectionPid, ChannelPid, QueueName};
                Reason ->
                    Reason
            end
    end.

declare_subscribe(ChannelPid, DeclareFun, DeclareInfo, NoAck) ->
    case catch DeclareFun(ChannelPid, DeclareInfo) of
        {'EXIT', {Reason, _Stack}} ->
            Reason;
        {_Exchange, Queue} when ?is_queue(Queue) ->
            QueueName = bunny_util:get_name(Queue),
            lib_amqp:subscribe(ChannelPid,
                               QueueName,
                               self(), NoAck),
            {ok, QueueName}
    end.

get_opt(Opt, Proplist, Default) ->
    {proplists:get_value(Opt, Proplist, Default),
     proplists:delete(Opt, Proplist)}.


%%
%% Tests
%%
-include_lib("eunit/include/eunit.hrl").

cds_setup() ->
    {ok, _} = mock:mock(lib_amqp),
    ok.

cds_stop(_) ->
    mock:verify_and_stop(lib_amqp),
    ok.


cds_expects(_DummyConn, DummyChannel, NoAck) ->
    mock:expects(lib_amqp, subscribe,
                 fun({Chan, <<"cds.test">>, _Pid, NA})
                    when Chan =:= DummyChannel,
                         NA =:= NoAck ->
                         true
                 end,
                 ok),
    ok.

cds_funs(DummyConn, DummyChannel) ->
    ConnectFun = fun(direct) ->
                         {DummyConn, DummyChannel}
                 end,

    DeclareFun = fun(Chan, <<"cds.test">>) when Chan =:= DummyChannel ->
                         {bunny_util:new_exchange(<<"cds.test">>),
                          bunny_util:new_queue(<<"cds.test">>)}
                 end,

    {ConnectFun, DeclareFun}.


cds_test_() ->
    DummyConn = c:pid(0,0,0),
    DummyChannel = c:pid(0,0,1),
    {ConnectFun, DeclareFun} = cds_funs(DummyConn, DummyChannel),

    {setup, fun cds_setup/0, fun cds_stop/1,
     ?_test(
        [begin
             cds_expects(DummyConn, DummyChannel, false),
             connect_declare_subscribe(ConnectFun, DeclareFun,
                                       direct, <<"cds.test">>, false)
         end])}.


cds_noack_test_() ->
    DummyConn = c:pid(0,0,0),
    DummyChannel = c:pid(0,0,1),
    {ConnectFun, DeclareFun} = cds_funs(DummyConn, DummyChannel),

    {setup, fun cds_setup/0, fun cds_stop/1,
     ?_test(
        [begin
             cds_expects(DummyConn, DummyChannel, true),
             connect_declare_subscribe(ConnectFun, DeclareFun,
                                       direct, <<"cds.test">>, true)
         end])}.


cds_conn_error_test_() ->
    ConnectFun = fun(direct) ->
                         {'EXIT', {{blah, "You suck"}, []}}
                 end,

    {setup, fun cds_setup/0, fun cds_stop/1,
     ?_test(
        [begin
             ?assertEqual(
                {blah, "You suck"},
                connect_declare_subscribe(ConnectFun, noop,
                                          direct, <<"cds.test">>, true))
         end])}.


cds_declare_error_test_() ->
    DummyConn = c:pid(0,0,0),
    DummyChannel = c:pid(0,0,1),
    {ConnectFun, _} = cds_funs(DummyConn, DummyChannel),

    DeclareFun = fun(Chan, <<"cds.test">>) when Chan =:= DummyChannel ->
                         {'EXIT', {{blah, "I declare that you suck"}, []}}
                 end,

    {setup, fun cds_setup/0, fun cds_stop/1,
     ?_test(
        [begin
             ?assertEqual(
                {blah, "I declare that you suck"},
                connect_declare_subscribe(ConnectFun, DeclareFun,
                                          direct, <<"cds.test">>, true))
         end])}.


test_gb_setup_1(NoAck) ->
    {ok, _} = mock:mock(lib_amqp),

    ConnectionPid = spawn_fake_proc(),
    ChannelPid = spawn_fake_proc(),

    mock:expects(lib_amqp, subscribe,
                 fun({Channel, <<"bunny.test">>, _Pid, NA})
                    when Channel =:= ChannelPid,
                         NA =:= NoAck ->
                         true
                 end,
                 ok),

    ConnectFun = fun(direct) ->
                         {ConnectionPid, ChannelPid}
                 end,

    DeclareFun = fun(Channel, <<"bunny.test">>)
                    when Channel =:= ChannelPid ->
                         {bunny_util:new_exchange(<<"bunny.test">>),
                          bunny_util:new_queue(<<"bunny.test">>)}
                 end,

    {ok, TestPid} = test_gb:start_link([{connect_fun, ConnectFun},
                                        {declare_fun, DeclareFun},
                                        {no_ack, NoAck}]),

    TestPid ! #'basic.consume_ok'{consumer_tag = <<"bunny.consumer">>},

    {ConnectionPid, ChannelPid, TestPid}.


test_gb_setup() ->
    test_gb_setup_1(true).


test_gb_noack_false_setup() ->
    test_gb_setup_1(false).


test_gb_stop({_ConnectionPid, _ChannelPid, TestPid}) ->
    ExpectedChannelPid = gen_bunny:get_channel(TestPid),
    ExpectedConnectionPid = gen_bunny:get_connection(TestPid),

    mock:expects(lib_amqp, unsubscribe,
                 fun({Channel, <<"bunny.consumer">>})
                    when Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),

    mock:expects(lib_amqp, teardown,
                 fun({Connection, Channel})
                    when Connection =:= ExpectedConnectionPid,
                         Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),
    gen_bunny:stop(TestPid),
    timer:sleep(100), %% I hate this.
    mock:verify_and_stop(lib_amqp),
    ok.

test_gb_start_link_test_() ->
    {setup, fun test_gb_setup/0, fun test_gb_stop/1,
     fun({ConnectionPid, ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     ?assertEqual(ConnectionPid, gen_bunny:get_connection(TestPid)),
                     ?assertEqual(ChannelPid, gen_bunny:get_channel(TestPid)),
                     ?assertEqual(<<"bunny.consumer">>,
                                  gen_bunny:get_consumer_tag(TestPid))
                 end])
     end}.


test_gb_handle_message_test_() ->
    {setup, fun test_gb_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, _ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     ExpectedMessage = bunny_util:new_message(<<"Testing">>),
                     TestPid ! {#'basic.deliver'{}, ExpectedMessage},
                     ?assertEqual([ExpectedMessage],
                                  test_gb:get_messages(TestPid))
                 end])
     end}.


test_gb_handle_message_decode_properties_test_() ->
    {setup, fun test_gb_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, _ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     ExpectedMessage = {
                       content, 60, amqp_util:basic_properties(),
                       <<152,0,24,97,112,112,108,105,99,97,116,105,111,110,
                        47,111,99,116,101,116,45,115,116,114,101,97,109,1,0>>,
                       [<<"zomgasdfasdf">>]},
                     RawMessage = {
                       content, 60, none,
                       <<152,0,24,97,112,112,108,105,99,97,116,105,111,110,
                        47,111,99,116,101,116,45,115,116,114,101,97,109,1,0>>,
                       [<<"zomgasdfasdf">>]},
                     TestPid ! {#'basic.deliver'{}, RawMessage},
                     ?assertEqual([ExpectedMessage], test_gb:get_messages(TestPid))
                 end])
     end}.


test_gb_handle_message_noack_false_test_() ->
    {setup, fun test_gb_noack_false_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, _ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     ExpectedMessage = {1, {
                       content, 60, amqp_util:basic_properties(),
                       <<152,0,24,97,112,112,108,105,99,97,116,105,111,110,
                        47,111,99,116,101,116,45,115,116,114,101,97,109,1,0>>,
                       [<<"zomgasdfasdf">>]}},
                     RawMessage = {
                       content, 60, none,
                       <<152,0,24,97,112,112,108,105,99,97,116,105,111,110,
                        47,111,99,116,101,116,45,115,116,114,101,97,109,1,0>>,
                       [<<"zomgasdfasdf">>]},
                     TestPid ! {#'basic.deliver'{delivery_tag=1}, RawMessage},
                     ?assertEqual([ExpectedMessage], test_gb:get_messages(TestPid))
                 end])
     end}.


test_gb_ack_test_() ->
    {setup, fun test_gb_noack_false_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     mock:expects(lib_amqp, ack,
                                  fun({Channel, Tag})
                                     when Channel =:= ChannelPid,
                                          Tag =:= 1 ->
                                          true
                                  end,
                                  ok),
                     ?assertEqual(ok, gen_bunny:ack(TestPid, 1))
                 end])
     end}.


test_gb_self_ack_test_() ->
    {setup, fun test_gb_noack_false_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     mock:expects(lib_amqp, ack,
                                  fun({Channel, Tag})
                                     when Channel =:= ChannelPid,
                                          Tag =:= 1 ->
                                          true
                                  end,
                                  ok),
                     %% Ack in a round about way so that we can test
                     %% gen_bunny:ack/1
                     ?assertEqual(ok, test_gb:ack_stuff(TestPid, 1))
                 end])
     end}.

test_gb_call_passthrough_test_() ->
    {setup, fun test_gb_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, _ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     ok = gen_bunny:call(TestPid, test),
                     ?assertEqual([test], test_gb:get_calls(TestPid))
                 end])
     end}.


test_gb_cast_passthrough_test_() ->
    {setup, fun test_gb_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, _ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     gen_bunny:cast(TestPid, cast_test),
                     timer:sleep(100),
                     ?assertEqual([cast_test], test_gb:get_casts(TestPid))
                 end])
     end}.


test_gb_info_passthrough_test_() ->
    {setup, fun test_gb_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, _ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     TestPid ! info_test,
                     ?assertEqual([info_test], test_gb:get_infos(TestPid))
                 end])
     end}.

test_monitor_setup() ->
    {ok, _} = mock:mock(lib_amqp),

    ConnectionPid = spawn_fake_proc(),
    NewConnectionPid = spawn_fake_proc(),

    ChannelPid = spawn_fake_proc(),
    NewChannelPid = spawn_fake_proc(),

    mock:expects(lib_amqp, subscribe,
              fun({_Channel, <<"bunny.test">>, _Pid, _NA}) ->
                      true
                 end,
                 ok, 2),

    ConnectFun = fun(direct) ->
                         case get('_connect_fun_run_before') of
                             undefined ->
                                 put('_connect_fun_run_before', true),
                                 {ConnectionPid, ChannelPid};
                             true ->
                                 {NewConnectionPid, NewChannelPid}
                         end
                 end,

    DeclareFun = fun(_Channel, <<"bunny.test">>) ->
                         {bunny_util:new_exchange(<<"bunny.test">>),
                          bunny_util:new_queue(<<"bunny.test">>)}
                 end,

    {ok, TestPid} = test_gb:start_link([{connect_fun, ConnectFun},
                                        {declare_fun, DeclareFun}]),

    TestPid ! #'basic.consume_ok'{consumer_tag = <<"bunny.consumer">>},

    {ConnectionPid, NewConnectionPid, ChannelPid, NewChannelPid, TestPid}.

test_monitor_stop({_ConnectionPid, _NewConnectionPid,
                   _ChannelPid, _NewChannelPid, TestPid}) ->
    ExpectedChannelPid = gen_bunny:get_channel(TestPid),
    ExpectedConnectionPid = gen_bunny:get_connection(TestPid),

    mock:expects(lib_amqp, unsubscribe,
                 fun({Channel, <<"bunny.consumer">>})
                    when Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),

    mock:expects(lib_amqp, teardown,
                 fun({Connection, Channel})
                    when Connection =:= ExpectedConnectionPid,
                         Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),
    gen_bunny:stop(TestPid),
    timer:sleep(100), %% I hate this.
    mock:verify_and_stop(lib_amqp),
    ok.

channel_monitor_test_() ->
    {setup, fun test_monitor_setup/0, fun test_monitor_stop/1,
     fun({ConnectionPid, _, ChannelPid, NewChannelPid, TestPid}) ->
             ?_test(
                [begin
                     MonRef = erlang:monitor(process, ChannelPid),

                     mock:expects(
                       lib_amqp, start_channel,
                       fun({Connection})
                          when is_pid(Connection) andalso
                               Connection =:= ConnectionPid ->
                               true
                       end,
                       fun(_, _) ->
                               NewChannelPid
                       end),

                     exit(ChannelPid, die),
                     ?assertEqual(true, erlang:is_process_alive(TestPid)),
                     ?assertEqual(false, erlang:is_process_alive(ChannelPid)),

                     receive
                         {'DOWN', MonRef, process, ChannelPid, die} ->
                             ok
                     end,

                     ?assertMatch(NewChannelPid,
                                  gen_bunny:get_channel(TestPid)),
                     ?assert(ChannelPid =/= NewChannelPid),
                     ?assertEqual(true, erlang:is_process_alive(NewChannelPid))
                 end])
     end}.


connection_monitor_test_() ->
    {setup, fun test_monitor_setup/0, fun test_monitor_stop/1,
     fun({ConnectionPid, NewConnectionPid,
          ChannelPid, NewChannelPid, TestPid}) ->
             ?_test(
                [begin
                     MonRef = erlang:monitor(process, ConnectionPid),

                     exit(ConnectionPid, die),
                     ?assertEqual(true, erlang:is_process_alive(TestPid)),
                     ?assertEqual(false,
                                  erlang:is_process_alive(ConnectionPid)),

                     receive
                         {'DOWN', MonRef, process, ConnectionPid, die} ->
                             ok
                     end,

                     ?assertMatch(NewConnectionPid,
                                  gen_bunny:get_connection(TestPid)),
                     ?assert(ConnectionPid =/= NewConnectionPid),
                     ?assertEqual(true,
                                  erlang:is_process_alive(NewConnectionPid)),

                     ?assertMatch(NewChannelPid,
                                  gen_bunny:get_channel(TestPid)),
                     ?assert(ChannelPid =/= NewChannelPid),
                     ?assertEqual(true, erlang:is_process_alive(NewChannelPid))
                 end])
     end}.

%% These are mostly to placate cover.

behaviour_info_test() ->
    ?assertEqual(lists:sort([{init, 1},
                             {handle_message, 2},
                             {handle_call, 3},
                             {handle_cast, 2},
                             {handle_info, 2},
                             {terminate, 2}]),
                 lists:sort(gen_bunny:behaviour_info(callbacks))),
    ?assertEqual(undefined, gen_bunny:behaviour_info(ign)).


code_change_test() ->
    ?assertEqual({ok, #state{}}, gen_bunny:code_change(ign, #state{}, ign)).


%% Test Utils

fake_proc() ->
    receive
        _ ->
            ok
    after 1000 ->
            fake_proc()
    end.

spawn_fake_proc() ->
    spawn(fun() -> fake_proc() end).
