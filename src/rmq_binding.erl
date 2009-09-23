-module(rmq_binding).
-include("riak_mq.hrl").
-export([new/3,
         get_queue/1,
         get_exchange/1,
         get_routing_key/1,
         is_nowait/1,
         set_nowait/2,
         binding/1]).


-record(rmq_binding, {queue, exchange, routing_key, bind}).

new(Queue, Exchange, RKey) when ?is_queue(Queue), ?is_exchange(Exchange), is_binary(RKey) ->
    #rmq_binding{queue=Queue,
                 exchange=Exchange,
                 routing_key=RKey,
                 bind=#'queue.bind'{queue=rmq_queue:get_name(Queue),
                                    exchange=rmq_exchange:get_name(Exchange),
                                    routing_key=RKey}}.

get_queue(#rmq_binding{bind=#'queue.bind'{queue=Q}}) -> Q.

get_exchange(#rmq_binding{bind=#'queue.bind'{exchange=E}}) -> E.

get_routing_key(#rmq_binding{bind=#'queue.bind'{routing_key=K}}) -> K.

is_nowait(#rmq_binding{bind=#'queue.bind'{nowait=NW}}) -> NW.

set_nowait(B=#rmq_binding{bind=B}, NW) when is_boolean(NW) -> 
    B#rmq_binding{bind=B#'queue.bind'{nowait=NW}}.

binding(#rmq_binding{bind=B}) -> B.
     




