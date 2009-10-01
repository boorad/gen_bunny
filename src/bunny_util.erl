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

%% @doc Utility functions for creating and manipulating RabbitMQ queues,
%%      exchanges, and messages.

-module(bunny_util).
-author('David Reid <dreid@dreid.org>').
-author('Andy Gross <andy@andygross.org>').
-include("gen_bunny.hrl").

-export([new_message/1,
         get_payload/1,
         get_delivery_mode/1,
         set_delivery_mode/2,
         get_content_type/1,
         set_content_type/2]).

-export([new_queue/1]).

-export([new_exchange/1,
         new_exchange/2,
         get_type/1,
         set_type/2]).

-export([get_name/1,
         is_durable/1,
         set_durable/2]).

-export([connect/0, connect/1, declare/2]).

%% @type message()=#content{}
%% @type payload()=#binary{}
%% @type delivery_mode()=non_neg_integer()
%% @type content_type()=binary()
%% @type exchange()=#'exchange.declare'{}
%% @type servobj_name()=binary()
%% @type exchange_type()=binary()
%% @type bunny_queue()=#'queue.declare'{}
%% @type binding()=#binding{}
%% @type durable_obj()=exchange()|bunny_queue()


%%
%% Message helpers
%%

%% @spec new_message(Payload::payload()) -> message()
%% @doc Construct a new message with a binary Payload.
-spec(new_message(payload()) -> message()).
new_message(Payload) when is_binary(Payload) ->
    #content{class_id=60,
             properties= amqp_util:basic_properties(),
             properties_bin=none,
             payload_fragments_rev=[Payload]}.

%% @spec get_payload(Message::message()) -> payload()
%% @doc Return the payload for a message.
-spec(get_payload(message()) -> payload()).
get_payload(#content{payload_fragments_rev=[Payload]}) ->
    Payload.

%% @spec get_delivery_mode(Message::message()) -> delivery_mode()
%% @doc Return the delivery mode for Message.
-spec(get_delivery_mode(message()) -> delivery_mode()).
get_delivery_mode(Message) when ?is_message(Message) ->
    (Message#content.properties)#'P_basic'.delivery_mode.

%% @spec set_delivery_mode(Message::message(), Mode::delivery_mode())
%%        -> message()
%% @doc Set the delivery mode for Message.
-spec(set_delivery_mode(message(), delivery_mode()) -> message()).
set_delivery_mode(Message = #content{properties=Props}, Mode)
  when ?is_message(Message), is_integer(Mode) ->
    Message#content{properties=Props#'P_basic'{delivery_mode=Mode}}.

%% @spec get_content_type(Message::message()) -> content_type()
%% @doc Return the content type for Message.
-spec(get_content_type(message()) -> content_type()).
get_content_type(Message) when ?is_message(Message) ->
    (Message#content.properties)#'P_basic'.content_type.

%% @spec set_content_type(Message::message(), Type::content_type()) -> message()
%% @doc Set the content type for Message to Type.
-spec(set_content_type(message(), content_type()) -> message()).
set_content_type(Message = #content{properties=Props}, Type)
  when ?is_message(Message), is_binary(Type) ->
    Message#content{properties=Props#'P_basic'{content_type=Type}}.

%%
%% Exchange helpers
%%

%% @spec new_exchange(Name::servobj_name()) -> exchange()
%% @doc Create a new exchange definition.  Exchange type defaults to "direct".
%% @equiv new_exchange(Name, <<"direct">>)
-spec(new_exchange(servobj_name()) -> exchange()).
new_exchange(Name) ->
    new_exchange(Name, <<"direct">>).

%% @spec new_exchange(Name::servobj_name, Type::exchange_type()) -> exchange()
%% @doc Create a new exchange definition of type Type.
-spec(new_exchange(servobj_name(), exchange_type()) -> exchange()).
new_exchange(Name, Type) when is_binary(Name), is_binary(Type) ->
    #'exchange.declare'{exchange=Name, type=Type}.

%% XXX maybe call these  [get|set]_exchange_type() ?

%% @spec get_type(Exchange::exchange()) -> exchange_type()
%% @doc  Return the exchange type for Exchange.
-spec(get_type(exchange()) -> exchange_type()).
get_type(#'exchange.declare'{type=Type}) ->
    Type.

%% @spec set_type(Exchange::exchange(), Type::exchange_type()) -> exchange()
%% @doc  Set the exchange type for Exchange
-spec(set_type(exchange(), exchange_type()) -> exchange()).
set_type(Exchange, Type) when ?is_exchange(Exchange), is_binary(Type) ->
    Exchange#'exchange.declare'{type=Type}.


%%
%% Queue helpers
%%
%%

%% @spec new_queue(Name::servobj_name()) -> bunny_queue()
%% @doc  Create a new Queue named Name
-spec(new_queue(servobj_name()) -> bunny_queue()).
new_queue(Name) when is_binary(Name) ->
    #'queue.declare'{queue=Name}.


%%
%% Common helpers
%% XXX: I don't particularly like this, but I don't like them having longer
%%      names either.

%% @spec get_name(QueueOrExchange::exchange()|bunny_queue()) -> servobj_name()
%% @doc  Return the name of the Queue or Exchange.
-spec(get_name(exchange()|bunny_queue()) -> servobj_name()).
get_name(#'exchange.declare'{exchange=Name})  ->
    Name;
get_name(#'queue.declare'{queue=Name}) ->
    Name.

%% @spec is_durable(QueueOrExchange::durable_obj()) -> boolean()
%% @doc  Return the durability flag on a Queue or exchange
-spec(is_durable(durable_obj()) -> boolean()).
is_durable(#'exchange.declare'{durable=Durable}) when is_boolean(Durable) ->
    Durable;
is_durable(#'queue.declare'{durable=Durable}) ->
    Durable.

%% @spec set_durable(QueueOrExchange::durable_obj(), boolean()) -> durable_obj()
%% @doc  Set the durability flag on a Queue or Exchange
set_durable(Exchange, Durable)
  when ?is_exchange(Exchange), is_boolean(Durable) ->
    Exchange#'exchange.declare'{durable=Durable};
set_durable(Queue, Durable) when ?is_queue(Queue), is_boolean(Durable) ->
    Queue#'queue.declare'{durable=Durable}.


%%
%% Connection and Declaration helpers.
%%

-define(DEFAULT_USER, "guest").
-define(DEFAULT_PASS, "guest").
-define(DEFAULT_VHOST, <<"/">>).

connect() ->
    connect(direct).

connect(direct) ->
    connect({direct, {?DEFAULT_USER, ?DEFAULT_PASS}});
connect({direct, {User, Pass}}) ->
    Connection = amqp_connection:start_direct(User, Pass),
    Channel = lib_amqp:start_channel(Connection),
    {Connection, Channel};
connect({network, Host}) ->
    connect({network, Host, ?PROTOCOL_PORT});
connect({network, Host, Port}) ->
    connect({network, Host, Port, {?DEFAULT_USER, ?DEFAULT_PASS}});
connect({network, Host, Port, Creds}) ->
    connect({network, Host, Port, Creds, ?DEFAULT_VHOST});
connect({network, Host, Port, {User, Pass}, VHost}) when is_binary(VHost) ->
    Connection = amqp_connection:start_network(User, Pass, Host, Port, VHost),
    Channel = lib_amqp:start_channel(Connection),
    {Connection, Channel}.


declare(Channel, NameForEverything) when is_binary(NameForEverything) ->
    declare(Channel, {NameForEverything, NameForEverything, NameForEverything});
declare(Channel, {ExchangeName, QueueName, RoutingKey})
  when is_binary(ExchangeName), is_binary(QueueName), is_binary(RoutingKey) ->
    declare(Channel, {ExchangeName, QueueName, [RoutingKey]});
declare(Channel, {ExchangeName, QueueName, RoutingKeys})
  when is_binary(ExchangeName), is_binary(QueueName), is_list(RoutingKeys) ->
    declare(Channel, {new_exchange(ExchangeName),
                      new_queue(QueueName),
                      RoutingKeys});
declare(Channel, {Exchange, Queue, RoutingKey})
  when ?is_exchange(Exchange), ?is_queue(Queue), is_binary(RoutingKey) ->
    declare(Channel, {Exchange, Queue, [RoutingKey]});
declare(Channel, {Exchange, Queue, RoutingKeys})
  when ?is_exchange(Exchange), ?is_queue(Queue), is_list(RoutingKeys)->
    amqp_channel:call(Channel, Exchange),
    amqp_channel:call(Channel, Queue),

    ExchangeName = get_name(Exchange),
    QueueName = get_name(Queue),

    [lib_amqp:bind_queue(Channel, ExchangeName, QueueName, RoutingKey) ||
        RoutingKey <- RoutingKeys],

    {Exchange, Queue}.


%%
%% Tests
%%

-include_lib("eunit/include/eunit.hrl").

%%
%% Message Helpers
%%

new_message_test() ->
    Foo = new_message(<<"Foo">>),
    ?assert(?is_message(Foo)),
    ?assertMatch(
       #content{payload_fragments_rev=[Payload]} when Payload =:= <<"Foo">>,
       Foo).


get_payload_test() ->
    Bar = #content{payload_fragments_rev=[<<"Bar">>]},
    ?assertEqual(<<"Bar">>, get_payload(Bar)).


set_delivery_mode_test() ->
    Foo = new_message(<<"Foo">>),
    FooModed = set_delivery_mode(Foo, 2),
    ?assertEqual((FooModed#content.properties)#'P_basic'.delivery_mode, 2).


get_delivery_mode_test() ->
    Msg = #content{properties=#'P_basic'{delivery_mode=2}},
    ?assertEqual(2, get_delivery_mode(Msg)).


set_content_type_test() ->
    Msg = new_message(<<"true">>),
    NewMsg = set_content_type(Msg, <<"application/json">>),
    ?assertEqual((NewMsg#content.properties)#'P_basic'.content_type,
                 <<"application/json">>).


get_content_type_test() ->
    Msg = #content{
      properties=#'P_basic'{content_type = <<"application/json">>}},
    ?assertEqual(<<"application/json">>, get_content_type(Msg)).


%%
%% Exchange Helpers
%%

new_exchange_test() ->
    Exchange = new_exchange(<<"Hello">>),
    ?assert(?is_exchange(Exchange)),
    ?assertMatch(#'exchange.declare'{exchange = <<"Hello">>,
                                     type = <<"direct">>}, Exchange).


new_exchange_with_type_test() ->
    Exchange = new_exchange(<<"Hello">>, <<"topic">>),
    ?assert(?is_exchange(Exchange)),
    ?assertMatch(#'exchange.declare'{exchange = <<"Hello">>,
                                     type = <<"topic">>}, Exchange).


get_type_test() ->
    ?assertEqual(<<"direct">>,
                 get_type(#'exchange.declare'{type = <<"direct">>})).


set_type_test() ->
    Exchange = new_exchange(<<"Hello">>),
    NewExchange = set_type(Exchange, <<"topic">>),

    ?assertMatch(#'exchange.declare'{exchange = <<"Hello">>,
                                     type = <<"topic">>}, NewExchange).


is_durable_exchange_test() ->
    ?assertEqual(true,
                 is_durable(#'exchange.declare'{durable=true})),
    ?assertEqual(false,
                 is_durable(#'exchange.declare'{durable=false})).


set_durable_exchange_test() ->
    Exchange = new_exchange(<<"Hello">>),
    NewExchange = set_durable(Exchange, true),
    ?assertEqual(true, NewExchange#'exchange.declare'.durable),

    NewExchange2 = set_durable(Exchange, false),
    ?assertEqual(false, NewExchange2#'exchange.declare'.durable).


%%
%% Queue helpers
%%


new_queue_test() ->
    Queue = new_queue(<<"Hello">>),
    ?assert(?is_queue(Queue)),
    ?assertMatch(#'queue.declare'{queue = <<"Hello">>}, Queue).


is_durable_queue_test() ->
    ?assertEqual(true,
                 is_durable(#'queue.declare'{durable=true})),
    ?assertEqual(false,
                 is_durable(#'queue.declare'{durable=false})).


set_durable_queue_test() ->
    Queue = new_queue(<<"Hello">>),
    NewQueue = set_durable(Queue, true),
    ?assertEqual(true, NewQueue#'queue.declare'.durable),

    NewQueue2 = set_durable(Queue, false),
    ?assertEqual(false, NewQueue2#'queue.declare'.durable).


%%
%% Connect helper
%%
connect_setup() ->
    {ok, _} = mock:mock(amqp_connection),
    ok.

connect_stop(_) ->
    mock:verify_and_stop(amqp_connection),
    ok.

direct_expects(User, Pass) ->
    mock:expects(amqp_connection, start_direct,
                 fun({U, P}) when U =:= User, P =:= Pass ->
                         true
                 end,
                 dummy_direct_conn),

    mock:expects(amqp_connection, open_channel,
                 fun({dummy_direct_conn}) ->
                         true
                 end,
                 dummy_direct_channel),
    ok.

network_expects(Host, Port, User, Pass, VHost) ->
    mock:expects(amqp_connection, start_network,
                 fun({U, P0, H, P1, V}) when U =:= User,
                                             P0 =:= Pass,
                                             H =:= Host,
                                             P1 =:= Port,
                                             V =:= VHost ->
                         true
                 end,
                 dummy_network_conn),

    mock:expects(amqp_connection, open_channel,
                 fun({dummy_network_conn}) ->
                         true
                 end,
                 dummy_network_channel),
    ok.


connect_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             direct_expects(?DEFAULT_USER, ?DEFAULT_PASS),

             ?assertEqual({dummy_direct_conn, dummy_direct_channel}, connect())
         end])}.


connect_direct_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             direct_expects(?DEFAULT_USER, ?DEFAULT_PASS),
             ?assertEqual({dummy_direct_conn, dummy_direct_channel},
                          connect(direct))
         end])}.


connect_direct_creds_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             direct_expects("al", "franken"),
             ?assertEqual({dummy_direct_conn, dummy_direct_channel},
                          connect({direct, {"al", "franken"}}))
         end])}.


connect_network_host_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             ?PROTOCOL_PORT,
                             ?DEFAULT_USER,
                             ?DEFAULT_PASS,
                             ?DEFAULT_VHOST),
             ?assertEqual({dummy_network_conn, dummy_network_channel},
                          connect({network, "amqp.example.com"}))
         end])}.

connect_network_host_port_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             10000,
                             ?DEFAULT_USER,
                             ?DEFAULT_PASS,
                             ?DEFAULT_VHOST),
             ?assertEqual({dummy_network_conn, dummy_network_channel},
                          connect({network, "amqp.example.com", 10000}))
         end])}.


connect_network_host_port_creds_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             10000,
                             "al",
                             "franken",
                             ?DEFAULT_VHOST),
             ?assertEqual({dummy_network_conn, dummy_network_channel},
                          connect({network, "amqp.example.com", 10000,
                                   {"al", "franken"}}))
         end])}.


connect_network_host_port_creds_vhost_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             10000,
                             "al",
                             "franken",
                             <<"/awesome">>),
             ?assertEqual({dummy_network_conn, dummy_network_channel},
                          connect({network, "amqp.example.com", 10000,
                                   {"al", "franken"}, <<"/awesome">>}))
         end])}.

%%
%% Declare Tests
%%

declare_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(lib_amqp),
    ok.


declare_stop(_) ->
    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(lib_amqp),
    ok.


declare_expects(Exchange, Queue, Bindings) ->
    QName = Queue#'queue.declare'.queue,
    EName = Exchange#'exchange.declare'.exchange,

    mock:expects(amqp_channel, call,
                 fun({dummy_channel, Q = #'queue.declare'{}})
                    when Q =:= Queue ->
                         true;

                    ({dummy_channel, E = #'exchange.declare'{}})
                    when E =:= Exchange ->
                         true
                 end,
                 {Exchange, Queue},
                 2),

    mock:expects(lib_amqp, bind_queue,
                 fun({dummy_channel, E, Q, K}) when E =:= EName,
                                                    Q =:= QName ->
                         case lists:member(K, Bindings) of
                             true ->
                                 true
                         end
                 end,
                 ok,
                 length(Bindings)),
    ok.



declare_everything_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(new_exchange(<<"Foo">>),
                             new_queue(<<"Foo">>),
                             [<<"Foo">>]),
             ?assertEqual({new_exchange(<<"Foo">>),
                           new_queue(<<"Foo">>)},
                          declare(dummy_channel, <<"Foo">>))
         end])}.


declare_names_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(new_exchange(<<"Foo">>),
                             new_queue(<<"Bar">>),
                             [<<"Baz">>]),
             ?assertEqual({new_exchange(<<"Foo">>),
                           new_queue(<<"Bar">>)},
                          declare(dummy_channel,
                                  {<<"Foo">>, <<"Bar">>, <<"Baz">>}))
         end])}.


declare_names_multiple_keys_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(new_exchange(<<"Foo">>),
                             new_queue(<<"Bar">>),
                             [<<"Baz">>, <<"Bax">>]),
             ?assertEqual({new_exchange(<<"Foo">>),
                           new_queue(<<"Bar">>)},
                          declare(dummy_channel,
                                  {<<"Foo">>, <<"Bar">>,
                                   [<<"Baz">>, <<"Bax">>]}))
         end])}.


declare_records_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(new_exchange(<<"Foo">>),
                             new_queue(<<"Bar">>),
                             [<<"Baz">>]),
             ?assertEqual({new_exchange(<<"Foo">>),
                           new_queue(<<"Bar">>)},
                          declare(dummy_channel,
                                  {new_exchange(<<"Foo">>),
                                   new_queue(<<"Bar">>),
                                   <<"Baz">>}))
         end])}.


declare_records_multiple_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(new_exchange(<<"Foo">>),
                             new_queue(<<"Bar">>),
                             [<<"Baz">>, <<"Bax">>]),
             ?assertEqual({new_exchange(<<"Foo">>),
                           new_queue(<<"Bar">>)},
                          declare(dummy_channel,
                                  {new_exchange(<<"Foo">>),
                                   new_queue(<<"Bar">>),
                                   [<<"Baz">>, <<"Bax">>]}))
         end])}.
