-ifndef(GEN_BUNNY_HRL_PREFIX).
-define(GEN_BUNNY_HRL_PREFIX, true).

-include_lib("rabbit.hrl").
-include_lib("rabbit_framing.hrl").
-include_lib("amqp_client.hrl").

-define(is_queue(X), element(1, X) =:= 'queue.declare').
-define(is_exchange(X), element(1, X) =:= 'exchange.declare').
-define(is_binding(X), element(1, X) =:= binding).
-define(is_message(X), element(1, X) =:= content).

%%
%% -types() - EDoc really needs to learn to read these.
%%
-type(message() :: #content{}).
-type(payload() :: binary()).
-type(delivery_mode() :: non_neg_integer()).
-type(content_type() :: binary()).
-type(exchange() :: #'exchange.declare'{}).
-type(servobj_name() :: binary()).
-type(exchange_type() :: binary()).
-type(bunny_queue() :: #'queue.declare'{}).
-type(binding() :: #binding{}).
-type(durable_obj() :: exchange() | bunny_queue()).

-endif. %% GEN_BUNNY_HRL_PREIFX

