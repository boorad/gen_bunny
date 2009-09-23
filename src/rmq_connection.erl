-module(rmq_connection).
-include("riak_mq.hrl").
-export([new/0,
         get_pid/1,
         new_channel/1,
         close/1]).

-record(rmq_connection, {pid}).

new() -> 
    case lib_amqp:start_connection() of
        Pid when is_pid(Pid) ->
            #rmq_connection{pid=lib_amqp:start_connection()};
        _ ->
            throw({error, connection_failure})
    end.

get_pid(#rmq_connection{pid=Pid}) -> Pid.

new_channel(C=#rmq_connection{}) -> rmq_channel:new(C).


close(#rmq_connection{pid=Pid}) -> lib_amqp:close_connection(Pid).
    
