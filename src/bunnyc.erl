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

-include("gen_bunny.hrl").

-ifdef(TEST).
-compile(export_all).
-endif.

-export([start_link/4, stop/1]).
-export([publish/3,
         publish/4,
         async_publish/3,
         async_publish/4,
         get/2,
         ack/2]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

%%
%% API
%%
publish(Name, Key, Message) ->
    publish(Name, Key, Message, []).

publish(Name, Key, Message, Opts) ->
    gen_server:call(Name, {publish, Key, Message, Opts}).


async_publish(Name, Key, Message) ->
    async_publish(Name, Key, Message, []).

async_publish(Name, Key, Message, Opts) ->
    gen_server:cast(Name, {publish, Key, Message, Opts}).


get(Name, NoAck) ->
    gen_server:call(Name, {get, NoAck}).


ack(Name, Tag) ->
    gen_server:cast(Name, {ack, Tag}).


start_link(Name, ConnectionInfo, DeclareInfo, Args) ->
    application:start(gen_bunny),
    gen_server:start_link({local, Name}, ?MODULE, [ConnectionInfo, DeclareInfo, Args], []).


stop(Name) ->
    gen_server:call(Name, stop).


%%
%% Callbacks
%%

init([ConnectionInfo, DeclareInfo, Args]) ->
    ConnectFun = proplists:get_value(connect_fun, Args,
                                     fun gen_bunny_mon:connect/1),
    DeclareFun = proplists:get_value(declare_fun, Args,
                                     fun bunny_util:declare/2),

    {ok, {ConnectionPid, ChannelPid}} = ConnectFun(ConnectionInfo),

    {ok, {Exchange, Queue}} = DeclareFun(ChannelPid, DeclareInfo),

    {ok, #bunnyc_state{connection=ConnectionPid,
                channel=ChannelPid,
                exchange=Exchange,
                queue=Queue}}.


handle_call({publish, Key, Message, Opts}, _From,
            State = #bunnyc_state{channel=Channel, exchange=Exchange})
  when is_binary(Key), is_binary(Message) orelse ?is_message(Message),
       is_list(Opts) ->
    Resp = internal_publish(fun amqp_channel:call/3,
                            Channel, Exchange, Key, Message, Opts),
    {reply, Resp, State};

handle_call({get, NoAck}, _From,
            State = #bunnyc_state{channel=Channel, queue=Queue}) ->
    Resp = internal_get(Channel, Queue, NoAck),
    {reply, Resp, State};

handle_call(stop, _From,
            State = #bunnyc_state{channel=Channel, connection=Connection}) ->
    amqp_channel:close(Channel),
    amqp_connection:close(Connection),
    {stop, normal, ok, State}.

handle_cast({publish, Key, Message, Opts},
            State = #bunnyc_state{channel=Channel, exchange=Exchange})
  when is_binary(Key), is_binary(Message) orelse ?is_message(Message),
       is_list(Opts) ->
    internal_publish(fun amqp_channel:cast/3,
                     Channel, Exchange, Key, Message, Opts),
    {noreply, State};

handle_cast({ack, Tag}, State = #bunnyc_state{channel=Channel}) ->
    internal_ack(Channel, Tag),
    {noreply, State};

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
internal_publish(Fun, Channel, Exchange, Key, Message, Opts)
  when ?is_message(Message) ->
    Mandatory = proplists:get_value(mandatory, Opts, false),

    BasicPublish = #'basic.publish'{
      exchange = bunny_util:get_name(Exchange),
      routing_key = Key,
      mandatory = Mandatory},

    Fun(Channel, BasicPublish, Message);
internal_publish(Fun, Channel, Exchange, Key, Message, Opts)
  when is_binary(Message) ->
    internal_publish(Fun, Channel, Exchange, Key,
                     bunny_util:new_message(Message), Opts).


internal_get(Channel, Queue, NoAck) ->
    amqp_channel:call(Channel, #'basic.get'{queue=bunny_util:get_name(Queue),
                                            no_ack=NoAck}).


internal_ack(Channel, DeliveryTag) ->
    amqp_channel:cast(Channel, #'basic.ack'{delivery_tag=DeliveryTag}).
