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
-module(bunnyc).
-author('Andy Gross <andy@andygross.org>').
-author('David Reid <dreid@dreid.org').

-behavior(gen_server).

-include_lib("gen_bunny.hrl").

-export([start_link/4]).
-export([publish/3]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {connection, channel, exchange}).

%%
%% API
%%
publish(Name, Key, Payload) ->
    gen_server:call(Name, {publish, Key, Payload}).

start_link(Name, ConnectionInfo, DeclareInfo, Args) ->
    gen_server:start_link({local, Name}, ?MODULE, [ConnectionInfo, DeclareInfo, Args], []).

%%
%% Callbacks
%%

init([ConnectionInfo, DeclareInfo, _Args]) ->
    {ConnectionPid, ChannelPid} = bunny_util:connect(ConnectionInfo),

    {Exchange, _Queue} = bunny_util:declare(ChannelPid, DeclareInfo),

    {ok, #state{connection=ConnectionPid,
                channel=ChannelPid,
                exchange=Exchange}}.


handle_call({publish, Key, Payload}, _From,
            State = #state{channel=Channel, exchange=Exchange})
  when is_binary(Key), is_binary(Payload) ->
    Resp = publish(Channel, Exchange, Key, Payload),
    {reply, Resp, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.


handle_cast(_Request, State) ->
    {noreply, State}.


handle_info(_Info, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

%%
%% Internal
%%

publish(Channel, Exchange, Key, Payload) ->
    lib_amqp:publish(Channel, bunny_util:get_name(Exchange), Key, Payload),
    ok.
