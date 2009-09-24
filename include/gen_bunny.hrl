-ifndef(GEN_BUNNY_HRL_PREFIX).
-define(GEN_BUNNY_HRL_PREFIX, true).

-include_lib("rabbit.hrl").
-include_lib("rabbit_framing.hrl").
-include_lib("amqp_client.hrl").

-define(is_queue(X), element(1, X) =:= 'queue.declare').
-define(is_exchange(X), element(1, X) =:= 'exchange.declare').
-define(is_binding(X), element(1, X) =:= binding).
-define(is_channel(X), element(1, X) =:= rmq_channel).
-define(is_connection(X), element(1, X) =:= rmq_connection).

-define(is_message(X), element(1, X) =:= content).

-endif. %% GEN_BUNNY_HRL_PREIFX

