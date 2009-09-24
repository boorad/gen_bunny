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

-export([new_binding/3]).

-export([new_exchange/1,
         new_exchange/2,
         get_type/1,
         set_type/2]).

-export([is_durable/1,
         set_durable/2]).

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
    #content{
             class_id=60,
             properties= #'P_basic'{},
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
%% Binding helpers
%%

%% @spec new_binding(ExchangeName::servobj_name(),
%%                   QueueName::servobj_name(),
%%                   RoutingKey::servobj_name()) -> binding()
%% @doc Create a new binding that routes messages delivered to Exchange 
%%       that match RoutingKey to the queue named QueueName.
-spec(new_binding(servobj_name(), servobj_name(), binary()) -> binding()).
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
%% Binding helpers
%%

new_binding_test() ->
    Binding = new_binding(<<"Exchange">>, <<"Queue">>, <<"Key">>),
    ?assertMatch(#binding{queue_name = <<"Queue">>,
                          exchange_name = <<"Exchange">>,
                          key = <<"Key">>}, Binding).
