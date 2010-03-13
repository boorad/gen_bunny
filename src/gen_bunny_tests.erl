-module(gen_bunny_tests).
-include_lib("gen_bunny.hrl").
-include_lib("eunit/include/eunit.hrl").

cds_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    ok.

cds_stop(_) ->
    mock:verify_and_stop(amqp_channel),
    ok.


cds_expects(_DummyConn, DummyChannel, NoAck) ->
    mock:expects(amqp_channel, subscribe,
                 fun({Chan,
                      #'basic.consume'{queue= <<"cds.test">>, no_ack=NA},
                      _Pid})
                    when Chan =:= DummyChannel,
                         NA =:= NoAck ->
                         true
                 end,
                 ok),
    ok.

cds_funs(DummyConn, DummyChannel) ->
    ConnectFun = fun(direct) ->
                         {ok, {DummyConn, DummyChannel}}
                 end,

    DeclareFun = fun(Chan, <<"cds.test">>) when Chan =:= DummyChannel ->
                         {ok, {bunny_util:new_exchange(<<"cds.test">>),
                               bunny_util:new_queue(<<"cds.test">>)}}
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
             gen_bunny:connect_declare_subscribe(
               ConnectFun, DeclareFun,
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
             gen_bunny:connect_declare_subscribe(
               ConnectFun, DeclareFun,
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
                gen_bunny:connect_declare_subscribe(
                  ConnectFun, noop,
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
                gen_bunny:connect_declare_subscribe(
                             ConnectFun, DeclareFun,
                             direct, <<"cds.test">>, true))
         end])}.


test_gb_setup_1(NoAck) ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),

    ConnectionPid = spawn_fake_proc(),
    ChannelPid = spawn_fake_proc(),

    mock:expects(amqp_channel, subscribe,
                 fun({Channel,
                      #'basic.consume'{queue= <<"bunny.test">>,
                                       no_ack=NA},
                      _Pid})
                    when Channel =:= ChannelPid,
                         NA =:= NoAck ->
                         true
                 end,
                 ok),

    ConnectFun = fun(direct) ->
                         {ok, {ConnectionPid, ChannelPid}}
                 end,

    DeclareFun = fun(Channel, <<"bunny.test">>)
                    when Channel =:= ChannelPid ->
                         {ok, {bunny_util:new_exchange(<<"bunny.test">>),
                               bunny_util:new_queue(<<"bunny.test">>)}}
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

    mock:expects(amqp_channel, call,
                 fun({Channel, #'basic.cancel'{
                        consumer_tag= <<"bunny.consumer">>}})
                    when Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),

    mock:expects(amqp_connection, close,
                 fun({Connection})
                    when Connection =:= ExpectedConnectionPid ->
                         true
                 end,
                 ok),

    mock:expects(amqp_channel, close,
                 fun({Channel})
                    when Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),

    gen_bunny:stop(TestPid),
    timer:sleep(100), %% I hate this.
    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
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
                       content, 60, #'P_basic'{content_type= <<"application/octet-stream">>,
                                               delivery_mode=1,
                                               priority=0},
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
     fun({_ConnectionPid, ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     ExpectedMessage =
                         {{ChannelPid, 1}, {
                            content, 60, #'P_basic'{content_type= <<"application/octet-stream">>,
                                                    delivery_mode=1,
                                                    priority=0},
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


test_gb_self_ack_test_() ->
    {setup, fun test_gb_noack_false_setup/0, fun test_gb_stop/1,
     fun({_ConnectionPid, ChannelPid, TestPid}) ->
             ?_test(
                [begin
                     mock:expects(amqp_channel, call,
                                  fun({Channel, #'basic.ack'{delivery_tag=Tag}})
                                     when Channel =:= ChannelPid,
                                          Tag =:= 1 ->
                                          true
                                  end,
                                  ok),
                     %% Ack in a round about way so that we can test
                     %% gen_bunny:ack/1
                     ?assertEqual(ok, test_gb:ack_stuff(TestPid,
                                                        {ChannelPid, 1}))
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
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),

    ConnectionPid = spawn_fake_proc(),
    NewConnectionPid = spawn_fake_proc(),

    ChannelPid = spawn_fake_proc(),
    NewChannelPid = spawn_fake_proc(),

    mock:expects(amqp_channel, subscribe,
              fun({_Channel,
                   #'basic.consume'{queue= <<"bunny.test">>},
                   _Pid}) ->
                      true
                 end,
                 ok, 2),

    ConnectFun = fun(direct) ->
                         case get('_connect_fun_run_before') of
                             undefined ->
                                 put('_connect_fun_run_before', true),
                                 {ok, {ConnectionPid, ChannelPid}};
                             true ->
                                 {ok, {NewConnectionPid, NewChannelPid}}
                         end
                 end,

    DeclareFun = fun(_Channel, <<"bunny.test">>) ->
                         {ok, {bunny_util:new_exchange(<<"bunny.test">>),
                               bunny_util:new_queue(<<"bunny.test">>)}}
                 end,

    {ok, TestPid} = test_gb:start_link([{connect_fun, ConnectFun},
                                        {declare_fun, DeclareFun}]),

    TestPid ! #'basic.consume_ok'{consumer_tag = <<"bunny.consumer">>},

    {ConnectionPid, NewConnectionPid, ChannelPid, NewChannelPid, TestPid}.

test_monitor_stop({_ConnectionPid, _NewConnectionPid,
                   _ChannelPid, _NewChannelPid, TestPid}) ->
    ExpectedChannelPid = gen_bunny:get_channel(TestPid),
    ExpectedConnectionPid = gen_bunny:get_connection(TestPid),

    mock:expects(amqp_channel, call,
                 fun({Channel, #'basic.cancel'{
                        consumer_tag= <<"bunny.consumer">>}})
                    when Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),

    mock:expects(amqp_connection, close,
                 fun({Connection})
                    when Connection =:= ExpectedConnectionPid ->
                         true
                 end,
                 ok),

    mock:expects(amqp_channel, close,
                 fun({Channel})
                    when Channel =:= ExpectedChannelPid ->
                         true
                 end,
                 ok),

    gen_bunny:stop(TestPid),
    timer:sleep(100), %% I hate this.
    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
    ok.

channel_monitor_test_() ->
    {setup, fun test_monitor_setup/0, fun test_monitor_stop/1,
     fun({ConnectionPid, _, ChannelPid, NewChannelPid, TestPid}) ->
             ?_test(
                [begin
                     MonRef = erlang:monitor(process, ChannelPid),

                     mock:expects(
                       amqp_connection, open_channel,
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

test_crash_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),

    {ok, _} = terrors:start(crash_test),
    error_logger:tty(false),

    ConnectionPid = spawn_fake_proc(),

    ChannelPid = spawn_fake_proc(),

    mock:expects(amqp_channel, subscribe,
              fun({_Channel,
                   #'basic.consume'{queue= <<"bunny.test">>},
                   _Pid}) ->
                      true
                 end,
                 ok, 1),

    ConnectFun = fun(direct) ->
                         {ok, {ConnectionPid, ChannelPid}}
                 end,

    DeclareFun = fun(_Channel, <<"bunny.test">>) ->
                         {ok, {bunny_util:new_exchange(<<"bunny.test">>),
                               bunny_util:new_queue(<<"bunny.test">>)}}
                 end,

    {ok, TestPid} = test_gb:start_link([{connect_fun, ConnectFun},
                                        {declare_fun, DeclareFun}]),

    TestPid ! #'basic.consume_ok'{consumer_tag = <<"bunny.consumer">>},

    mock:expects(amqp_channel, call,
                 fun({Channel, #'basic.cancel'{
                        consumer_tag= <<"bunny.consumer">>}})
                    when Channel =:= ChannelPid ->
                         true
                 end,
                 ok),

    mock:expects(amqp_connection, close,
                 fun({Connection})
                    when Connection =:= ConnectionPid ->
                         true
                 end,
                 ok),

    mock:expects(amqp_channel, close,
                 fun({Channel})
                    when Channel =:= ChannelPid ->
                         true
                 end,
                 ok),

    unlink(TestPid),
    TestPid.

test_crash_stop(_TestPid) ->
    error_logger:tty(true),
    _ = terrors:wait_for_errors(crash_test, 1, 10000),
    ok = terrors:stop(crash_test),
    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
    ok.

terminate_on_crash_test_() ->
    {setup, fun test_crash_setup/0, fun test_crash_stop/1,
     fun(TestPid) ->
             ?_test(
                [begin
                     process_flag(trap_exit, true),
                     link(TestPid),
                     ?assertExit({{{badmatch, crashed}, _}, _},
                                 gen_bunny:call(TestPid, crash))
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
    ?assertEqual({ok, #gen_bunny_state{}},
                 gen_bunny:code_change(ign, #gen_bunny_state{}, ign)).


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
