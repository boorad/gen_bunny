-module(rmq_channel).
-include("riak_mq.hrl").
-export([new/1,
         get_pid/1,
         get_connection/1,
         declare_exchange/2, 
         declare_queue/2,
         delete_queue/2,
         bind_queue/2,
         close/1]).

-record(rmq_channel, {pid, connection}).

new(Connection) when ?is_connection(Connection) ->
    case lib_amqp:start_channel(rmq_connection:get_pid(Connection)) of
        ChannelPid when is_pid(ChannelPid) ->
            #rmq_channel{pid=ChannelPid, connection=Connection};
        _ ->
            throw({error, channel_open_failure})
    end.

get_pid(#rmq_channel{pid=P}) -> P.

get_connection(#rmq_channel{connection=C}) -> C.
    
declare_exchange(#rmq_channel{pid=P}, Exchange) when ?is_exchange(Exchange) ->
    #'exchange.declare_ok'{} = amqp_channel:call(P, rmq_exchange:declare(Exchange)),
    ok.

declare_queue(#rmq_channel{pid=P}, Queue) when ?is_queue(Queue) ->
    #'queue.declare_ok'{} = amqp_channel:call(P, rmq_queue:declare(Queue)),
    ok.

delete_queue(#rmq_channel{pid=P}, Queue) when ?is_queue(Queue) ->
    #'queue.delete_ok'{} = amqp_channel:call(P,#'queue.delete'{queue=rmq_queue:get_name(Queue)}).

bind_queue(#rmq_channel{pid=P}, Binding) when ?is_binding(Binding) ->
    #'queue.bind_ok'{} = lib_amqp:bind_queue(
                           P, 
                           rmq_binding:get_exchange(Binding),
                           rmq_binding:get_queue(Binding),
                           rmq_binding:get_routing_key(Binding)),
    ok.
                                             
close(#rmq_channel{pid=P}) -> lib_amqp:close_channel(P).
