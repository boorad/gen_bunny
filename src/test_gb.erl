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
-module(test_gb).
-behavior(gen_bunny).

-export([start_link/1,
         init/1,
         handle_message/2,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2]).

-export([get_messages/1, get_calls/1, get_casts/1, get_infos/1]).

-include_lib("gen_bunny.hrl").

-record(state, {messages=[], calls=[], infos=[], casts=[]}).

start_link(Opts) ->
    gen_bunny:start_link(?MODULE, direct, <<"bunny.test">>, Opts).

init([]) ->
    {ok, #state{}}.

get_messages(Pid) ->
    gen_bunny:call(Pid, get_messages).

get_calls(Pid) ->
    gen_bunny:call(Pid, get_calls).

get_casts(Pid) ->
    gen_bunny:call(Pid, get_casts).

get_infos(Pid) ->
    gen_bunny:call(Pid, get_infos).

handle_message(Message, State=#state{messages=Messages})
  when ?is_message(Message) ->
    NewMessages = [Message|Messages],
    {noreply, State#state{messages=NewMessages}}.

handle_call(get_messages, _From, State=#state{messages=Messages}) ->
    {reply, Messages, State};
handle_call(get_calls, _From, State=#state{calls=Calls}) ->
    {reply, Calls, State};
handle_call(get_casts, _From, State=#state{casts=Casts}) ->
    {reply, Casts, State};
handle_call(get_infos, _From, State=#state{infos=Infos}) ->
    {reply, Infos, State};
handle_call(Msg, _From, State=#state{calls=Calls}) ->
    {reply, ok, State#state{calls=[Msg|Calls]}}.

handle_cast(Msg, State=#state{casts=Casts}) ->
    {noreply, State#state{casts=[Msg|Casts]}}.

handle_info(Info, State=#state{infos=Infos}) ->
    {noreply, State#state{infos=[Info|Infos]}}.

terminate(Reason, _State) ->
    io:format("~p terminating with reason ~p~n", [?MODULE, Reason]),
    ok.
