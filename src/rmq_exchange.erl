-module(rmq_exchange).
-include("gen_rabbit.hrl").

-export([new/1,
         get_name/1,
         get_type/1,
         set_type/2,
         is_durable/1,
         set_durable/2,
         is_passive/1,
         set_passive/2,
         is_auto_delete/1,
         set_auto_delete/2,
         is_nowait/1,
         set_nowait/2,
         is_internal/1,
         set_internal/2,
         declare/1]).

-record(rmq_exchange, {name, declare}).

new(Name) when is_binary(Name) ->
    #rmq_exchange{name=Name, declare=#'exchange.declare'{exchange=Name}}.

get_name(#rmq_exchange{name=Name}) -> Name.

get_type(#rmq_exchange{declare=#'exchange.declare'{type=T}}) -> T.

set_type(E=#rmq_exchange{declare=D}, Type) when is_binary(Type) ->
    E#rmq_exchange{declare=D#'exchange.declare'{type=Type}}.

is_durable(#rmq_exchange{declare=#'exchange.declare'{durable=D}}) -> D.

set_durable(E=#rmq_exchange{declare=D}, Durable) when is_boolean(Durable) -> 
    E#rmq_exchange{declare=D#'exchange.declare'{durable=Durable}}.

is_passive(#rmq_exchange{declare=#'exchange.declare'{passive=P}}) -> P.

set_passive(E=#rmq_exchange{declare=D}, Passive) when is_boolean(Passive) -> 
    E#rmq_exchange{declare=D#'exchange.declare'{passive=Passive}}.

is_auto_delete(#rmq_exchange{declare=#'exchange.declare'{auto_delete=A}}) -> A.

set_auto_delete(E=#rmq_exchange{declare=D}, AD) when is_boolean(AD) -> 
    E=#rmq_exchange{declare=D#'exchange.declare'{auto_delete=AD}}.

is_nowait(#rmq_exchange{declare=#'exchange.declare'{nowait=NW}}) -> NW.

set_nowait(E=#rmq_exchange{declare=D}, NW) when is_boolean(NW) -> 
    E#rmq_exchange{declare=D#'exchange.declare'{nowait=NW}}.

is_internal(#rmq_exchange{declare=#'exchange.declare'{internal=I}}) -> I.

set_internal(E=#rmq_exchange{declare=D}, I) when is_boolean(I) -> 
    E#rmq_exchange{declare=D#'exchange.declare'{internal=I}}.

declare(#rmq_exchange{declare=D}) -> D.

%%-record('exchange.declare', {ticket = 1, exchange, type = <<"direct">>, passive = false, durable = false, auto_delete = false, internal = false, nowait = false, arguments = []}).
%%-record('exchange.delete', {ticket = 1, exchange, if_unused = false, nowait = false}).
%%-record('exchange.delete_ok', {}).
