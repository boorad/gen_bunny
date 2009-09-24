-module(rmq_client, [Connection, Channel, Exchange, Binding]).

-export([
         connection/0,
         channel/0,
         exchange/0,
         binding/0,
         publish/1,
         async_publish/1,
         get/0,
         get_ack/0,
         ack/1,
         subscribe/0,
         subscribe/1,
         subscribe_ack/0,
         subscribe_ack/1,
         unsubscribe/1
        ]).

connection() -> Connection.
channel() -> Channel.
exchange() -> Exchange.
binding() -> Binding.



publish(Message) when is_binary(Message) ->
    lib_amqp:publish(rmq_channel:get_pid(Channel),
                     rmq_exchange:get_name(Exchange),
                     rmq_binding:get_queue(Binding),
                     Message);
publish(Message) -> ?MODULE:publish(term_to_binary(Message)).

async_publish(Message) when is_binary(Message) ->
    lib_amqp:async_publish(rmq_channel:get_pid(Channel),
                           rmq_exchange:get_name(Exchange),
                           rmq_binding:get_queue(Binding),
                           Message);
async_publish(Message) -> ?MODULE:async_publish(term_to_binary(Message)).

get() -> lib_amqp:get(rmq_channel:get_pid(Channel), rmq_binding:get_queue(Binding)).

get_ack() -> lib_amqp:get(rmq_channel:get_pid(Channel), rmq_binding:get_queue(Binding), false).

ack(Tag) -> lib_amqp:ack(rmq_channel:get_pid(Channel), Tag).

subscribe() -> ?MODULE:subscribe(self()).
subscribe(Consumer) -> lib_amqp:subscribe(rmq_channel:get_pid(Channel), 
                                          rmq_binding:get_queue(Binding),
                                          Consumer).
    
subscribe_ack() -> ?MODULE:subscribe_ack(self()).

subscribe_ack(Consumer) ->  lib_amqp:subscribe(rmq_channel:get_pid(Channel), 
                                               rmq_binding:get_queue(Binding),
                                               Consumer,
                                               false).
    
unsubscribe(Tag) -> lib_amqp:unsubscribe(rmq_channel:get_pid(Channel),
                                         Tag).
    
    
