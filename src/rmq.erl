-module(rmq).
-include_lib("gen_bunny.hrl").
-export([new_client/3]).

new_client(ExchangeName, QueueName, IsDurable) 
  when is_binary(ExchangeName), is_binary(QueueName), is_boolean(IsDurable) ->
    Connection = rmq_connection:new(),
    Channel = rmq_connection:new_channel(Connection),
    Exchange0 = rmq_exchange:set_type(rmq_exchange:new(ExchangeName), <<"direct">>),
    Exchange = 
        case IsDurable of 
            true -> rmq_exchange:set_durable(Exchange0, true);
            false -> Exchange0
        end,
    ok = rmq_channel:declare_exchange(Channel, Exchange),
    Queue0 = rmq_queue:new(QueueName),
    Queue = 
        case IsDurable of
            true -> rmq_queue:set_durable(Queue0, true);
            false -> Queue0
        end,
    ok = rmq_channel:declare_queue(Channel, Queue),
    Binding = rmq_binding:new(Queue, Exchange, rmq_queue:get_name(Queue)),
    ok = rmq_channel:bind_queue(Channel, Binding),
    rmq_client:new(Connection, Channel, Exchange, Binding).
                
                   
            
