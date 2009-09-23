-module(bunny_util).

-include("gen_bunny.hrl").

-export([new_message/1,
         get_payload/1,
         get_delivery_mode/1,
         set_delivery_mode/2,
         get_content_type/1,
         set_content_type/2]).

-export([new_queue/1]).

-export([new_binding/3]).

-export([is_durable/1,
         set_durable/2]).

%%
%% Message helpers
%%

new_message(Payload) when is_binary(Payload) ->
    #content{
             class_id=60,
             properties= #'P_basic'{},
             payload_fragments_rev=[Payload]}.

get_payload(#content{payload_fragments_rev=[Payload]}) ->
    Payload.

get_delivery_mode(Message) when ?is_message(Message) ->
    (Message#content.properties)#'P_basic'.delivery_mode.

set_delivery_mode(Message = #content{properties=Props}, Mode)
  when ?is_message(Message), is_integer(Mode) ->
    Message#content{properties=Props#'P_basic'{delivery_mode=Mode}}.

get_content_type(Message) when ?is_message(Message) ->
    (Message#content.properties)#'P_basic'.content_type.

set_content_type(Message = #content{properties=Props}, Type)
  when ?is_message(Message), is_binary(Type) ->
    Message#content{properties=Props#'P_basic'{content_type=Type}}.

%%
%% Exchange helpers
%%

new_exchange(Name) ->
    new_exchange(Name, <<"direct">>).

new_exchange(Name, Type) when is_binary(Name), is_binary(Type) ->
    #'exchange.declare'{exchange=Name, type=Type}.

get_type(#'exchange.declare'{type=Type}) ->
    Type.

set_type(Exchange, Type) when ?is_exchange(Exchange), is_binary(Type) ->
    Exchange#'exchange.declare'{type=Type}.


%%
%% Queue helpers
%%

new_queue(Name) when is_binary(Name) ->
    #'queue.declare'{queue=Name}.

%%
%% Binding helpers
%%

new_binding(ExchangeName, QueueName, RoutingKey)
  when is_binary(ExchangeName),
       is_binary(QueueName),
       is_binary(RoutingKey) ->
    #binding{exchange_name=ExchangeName,
             queue_name=QueueName,
             key=RoutingKey}.

%%
%% Common helpers
%% XXX: I don't particularly like this, but I don't like them having longer
%%      names either.


is_durable(#'exchange.declare'{durable=Durable}) when is_boolean(Durable) ->
    Durable;
is_durable(#'queue.declare'{durable=Durable}) ->
    Durable.


set_durable(Exchange, Durable) when is_boolean(Durable) ->
    Exchange#'exchange.declare'{durable=Durable};
set_durable(Queue, Durable) when ?is_queue(Queue), is_boolean(Durable) ->
    Queue#'queue.declare'{durable=Durable}.


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
                 is_durable(#'exchange.declare'{durable=true})),
    ?assertEqual(false,
                 is_durable(#'exchange.declare'{durable=false})).


set_durable_queue_test() ->
    Exchange = new_exchange(<<"Hello">>),
    NewExchange = set_durable(Exchange, true),
    ?assertEqual(true, NewExchange#'exchange.declare'.durable),

    NewExchange2 = set_durable(Exchange, false),
    ?assertEqual(false, NewExchange2#'exchange.declare'.durable).


%%
%% Binding helpers
%%

new_binding_test() ->
    Binding = new_binding(<<"Exchange">>, <<"Queue">>, <<"Key">>),
    ?assertMatch(#binding{queue_name = <<"Queue">>,
                          exchange_name = <<"Exchange">>,
                          key = <<"Key">>}, Binding).
