-module(rmq_queue).
-include("riak_mq.hrl").

-export([new/1,
         get_name/1,
         is_durable/1,
         set_durable/2,
         is_passive/1,
         set_passive/2,
         is_exclusive/1,
         set_exclusive/2,
         is_auto_delete/1,
         set_auto_delete/2,
         is_nowait/1,
         set_nowait/2,
         declare/1]).

-record(rmq_queue, {name, declare}).

new(Name) when is_binary(Name) ->
    #rmq_queue{name=Name, declare=#'queue.declare'{queue=Name}}.

get_name(#rmq_queue{name=Name}) -> Name.

is_durable(#rmq_queue{declare=#'queue.declare'{durable=D}}) -> D.

set_durable(Q=#rmq_queue{declare=D}, Durable) when is_boolean(Durable) -> 
    Q#rmq_queue{declare=D#'queue.declare'{durable=Durable}}.

is_passive(#rmq_queue{declare=#'queue.declare'{passive=P}}) -> P.

set_passive(Q=#rmq_queue{declare=D}, Passive) when is_boolean(Passive) -> 
    Q#rmq_queue{declare=D#'queue.declare'{passive=Passive}}.

is_exclusive(#rmq_queue{declare=#'queue.declare'{exclusive=E}}) -> E.

set_exclusive(Q=#rmq_queue{declare=D}, Exclusive) when is_boolean(Exclusive) -> 
    Q=#rmq_queue{declare=D#'queue.declare'{exclusive=Exclusive}}.

is_auto_delete(#rmq_queue{declare=#'queue.declare'{auto_delete=A}}) -> A.

set_auto_delete(Q=#rmq_queue{declare=D}, AD) when is_boolean(AD) -> 
    Q#rmq_queue{declare=D#'queue.declare'{auto_delete=AD}}.

is_nowait(#rmq_queue{declare=#'queue.declare'{nowait=NW}}) -> NW.

set_nowait(Q=#rmq_queue{declare=D}, NW) when is_boolean(NW) -> 
    Q=#rmq_queue{declare=D#'queue.declare'{nowait=NW}}.

declare(#rmq_queue{declare=D}) -> D.
    


%%-record('queue.declare', {ticket = 1, queue = <<"">>, passive = false, durable = false, exclusive = false, auto_delete = false, nowait = false, arguments = []}).
%%-record('queue.declare_ok', {queue, message_count, consumer_count}).
%%-record('queue.purge', {ticket = 1, queue, nowait = false}).
%%-record('queue.purge_ok', {message_count}).
%%-record('queue.delete', {ticket = 1, queue, if_unused = false, if_empty = false, nowait = false}).
%%-record('queue.delete_ok', {message_count}).
%%-record('queue.unbind', {ticket = 1, queue, exchange, routing_key, arguments}).
%%-record('queue.unbind_ok', {}).

