-ifndef(RIAK_MQ_HRL_PREFIX).
-define(RIAK_MQ_HRL_PREFIX, true).

-include_lib("rabbit.hrl").
-include_lib("rabbit_framing.hrl").
-include_lib("amqp_client.hrl").

-define(is_queue(X), element(1, X) =:= rmq_queue).
-define(is_exchange(X), element(1, X) =:= rmq_exchange).
-define(is_binding(X), element(1, X) =:= rmq_binding).
-define(is_channel(X), element(1, X) =:= rmq_channel).
-define(is_connection(X), element(1, X) =:= rmq_connection).

-endif. %% RIAK_MQ_HRL_PREIFX

