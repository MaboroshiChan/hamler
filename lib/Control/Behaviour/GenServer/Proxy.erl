%%---------------------------------------------------------------------------
%% |
%% Module      :  Proxy
%% Copyright   :  (c) 2020 EMQ Technologies Co., Ltd.
%% License     :  BSD-style (see the LICENSE file)
%%
%% Maintainer  :  Feng Lee, feng@emqx.io
%%                Yang M, yangm@emqx.io
%% Stability   :  experimental
%% Portability :  portable
%%
%% The GenServer Proxy FFI module.
%%
%---------------------------------------------------------------------------
-module('Proxy').

-behaviour(gen_server).

%% gen_server callbacks
-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).

-record(proxy, {handleCall, handleCast, state}).

init([Class, Init, Args]) ->
  case Init(Args) of
    {'InitOk', State} ->
      {ok, init_ok(Class, State)};
    {'InitHibernate', State} ->
      {ok, init_ok(Class, State), hibernate};
    {'InitStop', Reason} ->
      {stop, Reason};
    {'InitIgnore'} ->
      ignore
  end.

init_ok(#{handleCall := HandleCall, handleCast := HandleCast}, State) ->
  #proxy{handleCall = HandleCall, handleCast = HandleCast, state = State}.

handle_call(Request, From, Proxy = #proxy{handleCall = HandleCall, state = State}) ->
  io:format("Call: ~p~n", [Request]),
  case uncurry(HandleCall, [Request, From, State]) of
    {'ServerIgnore', St} ->
      {reply, ignored, Proxy#proxy{state = St}};
    {'ServerReply', Rep, St} ->
      {reply, Rep, Proxy#proxy{state = St}};
    {'ServerNoReply', St} ->
      {noreply, Proxy#proxy{state = St}};
    {'ServerStop', Reason, St} ->
      {stop, Reason, Proxy#proxy{state = St}};
    {'ServerStopReply', Reason, Rep, St} ->
      {stop, Reason, Rep, Proxy#proxy{state = St}}
  end.

handle_cast(Msg, Proxy = #proxy{handleCast = HandleCast, state = State}) ->
  io:format("Cast: ~p~n", [Msg]),
  case uncurry(HandleCast, [Msg, State]) of
    {'ServerIgnore', St} ->
      {noreply, Proxy#proxy{state = St}};
    {'ServerNoReply', St} ->
      {noreply, Proxy#proxy{state = St}};
    {'ServerStop', Reason, St} ->
      {stop, Reason, Proxy#proxy{state = St}};
    Result ->
      io:format("Result: ~p~n", [Result]),
      {noreply, Proxy}
  end.

handle_info(Info, Proxy) ->
  error_logger:error_msg("Unexpected Info: ~p", [Info]),
  {noreply, Proxy}.

terminate(_Reason, _Proxy) ->
  ok.

code_change(_OldVsn, Proxy, _Extra) ->
  {ok, Proxy}.

%%---------------------------------------------------------------------------
%% | Internal functions
%%---------------------------------------------------------------------------

uncurry(Fun, [H|T]) -> uncurry(Fun(H), T);
uncurry(Ret, []) -> Ret.
