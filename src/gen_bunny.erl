-module(gen_bunny).
-author('Andy Gross <andy@basho.com>').
-author('David Reid <dreid@mochimedia.com').
-behavior(gen_server).
-include_lib("gen_bunny.hrl").

-export([start_link/3]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([behaviour_info/1]).

-record(state, {mod, modstate, options}).

behaviour_info(callbacks) ->
    [{init, 1},
     {handle_message, 2},
     {terminate, 2}];
behaviour_info(_) -> 
    undefined.

start_link(Module, Options, InitArgs) 
  when is_list(Options), is_list(InitArgs) ->
    gen_server:start_link(?MODULE, [Module, Options, InitArgs], []).

init([Module, Options, InitArgs]) ->
    %% TODO:  for now im assuming all consumer info is in the "options"
    %% proplist.  likely that we'll change this to accept more args for
    %% subscription info and put the more obscure stuff in the proplist.

    %% TODO:  actually do something 
    case Module:init(InitArgs) of
        {ok, ModState} ->
            {ok, #state{mod=Module, modstate=ModState, options=Options}};
        Error ->
            Error
    end.

handle_call(_Request, _From, State=#state{}) ->
    {reply, ok, State}.

handle_cast(_Msg, State=#state{}) ->
    {noreply, State}.

handle_info({#'basic.deliver'{},
            {content, ClassId, _Props, PropertiesBin, [Payload]}},
            State=#state{mod=Module, modstate=ModState}) ->
    %% TODO: figure out what fields we want to expose from the 'P_basic' record
    #'P_basic'{} = rabbit_framing:decode_properties(ClassId, PropertiesBin),
    case Module:handle_message(Payload, ModState) of
        {noreply, NewModState} ->
            {noreply, State#state{modstate=NewModState}};
        {noreply, NewModState, A} when A =:= hibernate orelse is_number(A) ->
            {noreply, State#state{modstate=NewModState}, A};
        {stop, Reason, NewModState} ->
            {stop, Reason, State#state{modstate=NewModState}}
    end.

terminate(Reason, #state{mod=Mod, modstate=ModState}) ->
    Mod:terminate(Reason, ModState),
    ok.

code_change(_OldVersion, State, _Extra) ->
    %% TODO:  support code changes?
    {ok, State}.



    
    
