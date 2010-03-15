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

-ifdef(TEST).
-compile(export_all).
-endif.

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
-export([declare_exchange/2, declare_queue/2, bind_queue/4]).

%% @type message()=#content{}
%% @type payload()=#binary{}
%% @type delivery_mode()=non_neg_integer()
%% @type content_type()=binary()
%% @type exchange()=#'exchange.declare'{}
%% @type servobj_name()=binary()
%% @type exchange_type()=binary()
%% @type bunny_queue()=#'queue.declare'{}
%% @type binding()=#'queue.bind{}
%% @type durable_obj()=exchange()|bunny_queue()


%%
%% Message helpers
%%

%% @spec new_message(Payload::payload()) -> message()
%% @doc Construct a new message with a binary Payload.
-spec(new_message(payload()) -> message()).
new_message(Payload) when is_binary(Payload) ->
    #content{class_id=60,
             properties=#'P_basic'{},
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
new_exchange(Exchange) when ?is_exchange(Exchange) ->
    Exchange;
new_exchange(Name) ->
    new_exchange(Name, <<"direct">>).

%% @spec new_exchange(Name::servobj_name, Type::exchange_type()) -> exchange()
%% @doc Create a new exchange definition of type Type.
-spec(new_exchange(servobj_name(), exchange_type()) -> exchange()).
new_exchange(Exchange, Type) when ?is_exchange(Exchange), is_binary(Type) ->
    Exchange#'exchange.declare'{type=Type};
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
new_queue(Queue) when ?is_queue(Queue) ->
    Queue;
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

connect() ->
    connect(direct).

connect(direct) ->
    connect({direct, #amqp_params{}});
connect({direct, Params}) when is_record(Params, amqp_params) ->
    Connection = amqp_connection:start_direct(Params),
    Channel = amqp_connection:open_channel(Connection),
    {ok, {Connection, Channel}};
connect({network, Params}) when is_record(Params, amqp_params) ->
    Connection = amqp_connection:start_network(Params),
    Channel = amqp_connection:open_channel(Connection),
    {ok, {Connection, Channel}};
connect({network, Host}) ->
    connect({network, #amqp_params{host=Host}});
connect({network, Host, Port}) ->
    connect({network, #amqp_params{host=Host, port=Port}});
connect({network, Host, Port, {User, Pass}}) ->
    connect({network, #amqp_params{host=Host, port=Port,
                                   username=User,
                                   password=Pass}});
connect({network, Host, Port, {User, Pass}, VHost}) ->
    connect({network, #amqp_params{host=Host, port=Port,
                                   username=User,
                                   password=Pass,
                                   virtual_host=VHost}}).



declare(Channel, NameForEverything) when is_binary(NameForEverything) ->
    declare(Channel,
            {NameForEverything, NameForEverything, NameForEverything});

declare(Channel, {Exchange}) ->
    {ok, Exchange1} = declare_exchange(Channel, Exchange),
    {ok, {Exchange1, no_queue}};

declare(Channel, {Exchange, Queue, RoutingKey})
  when is_binary(RoutingKey) ->
    {ok, Exchange1} = declare_exchange(Channel, Exchange),
    {ok, Queue1} = declare_queue(Channel, Queue),
    ok = bind_queue(Channel, Exchange, Queue, RoutingKey),

    {ok, {Exchange1, Queue1}}.


declare_exchange(Channel, Exchange) ->
    Exchange1 = new_exchange(Exchange),
    #'exchange.declare_ok'{} = amqp_channel:call(
                                 Channel,
                                 Exchange1),
    {ok, Exchange1}.


declare_queue(Channel, Queue) ->
    Queue1 = new_queue(Queue),
    #'queue.declare_ok'{} = amqp_channel:call(
                                 Channel,
                                 Queue1),
    {ok, Queue1}.


bind_queue(Channel, Exchange, Queue, RoutingKey) ->
    ExchangeName = get_name(new_exchange(Exchange)),
    QueueName = get_name(new_queue(Queue)),

    Binding = #'queue.bind'{queue=QueueName,
                            exchange=ExchangeName,
                            routing_key=RoutingKey},

    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),
    ok.
