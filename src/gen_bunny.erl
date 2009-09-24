%% The MIT License

%% Copyright (c) David Reid <dreid@dreid.org>, Andy Gross <andy@andygross.org>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.

%% @doc The gen_bunny RabbitMQ consumer behavior.
-module(gen_bunny).
-author('Andy Gross <andy@andygross.org>').
-author('David Reid <dreid@dreid.org').
-behavior(gen_server).
-include_lib("gen_bunny.hrl").

-export([start_link/4]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([behaviour_info/1]).

-record(state, {mod, modstate, channel, queue}).

behaviour_info(callbacks) ->
    [{init, 1},
     {handle_message, 2},
     {terminate, 2}];
behaviour_info(_) -> 
    undefined.

start_link(Module, ChannelPid, QueueName, InitArgs) 
  when is_pid(ChannelPid), is_binary(QueueName), is_list(InitArgs)  ->
    gen_server:start_link(?MODULE, [Module,ChannelPid,QueueName,InitArgs], []).

init([Module, ChannelPid, QueueName, InitArgs]) ->
    %% TODO:  actually do something 
    case Module:init(InitArgs) of
        {ok, ModState} ->
            {ok, #state{mod=Module, 
                        modstate=ModState, 
                        channel=ChannelPid,
                        queue=QueueName}};
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



    
    
