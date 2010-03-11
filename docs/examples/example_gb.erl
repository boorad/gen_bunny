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
-module(example_gb).
-behavior(gen_bunny).

-export([start_link/0,
         start_link/3,
         init/1,
         handle_message/2,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2]).

-export([get_messages/1]).

-include_lib("gen_bunny.hrl").

-record(state, {messages=[]}).

start_link() ->
    start_link(direct, <<"bunny.test">>, []).

start_link(Conn, Declare, Opts) ->
    gen_bunny:start_link(?MODULE, Conn, Declare, Opts).


init([]) ->
    {ok, #state{}}.

get_messages(Pid) ->
    gen_bunny:call(Pid, get_messages).

handle_message(Message, State=#state{messages=Messages}) ->
    NewMessages = [Message|Messages],
    {noreply, State#state{messages=NewMessages}}.

handle_call(get_messages, _From, State=#state{messages=Messages}) ->
    {reply, Messages, State}.

handle_cast(_Msg, State) -> {noreply, State}.

handle_info(Info, State) ->
    io:format("Unknown message: ~p~n", [Info]),
    {noreply, State}.

terminate(Reason, _State) ->
    io:format("~p terminating with reason ~p~n", [?MODULE, Reason]),
    ok.
