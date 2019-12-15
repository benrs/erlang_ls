-module(els_workspace_symbol_provider).

-behaviour(els_provider).

-export([ handle_request/2
        , is_enabled/0
        ]).

-include("erlang_ls.hrl").

%%==============================================================================
%% els_provider functions
%%==============================================================================

-spec is_enabled() -> boolean().
is_enabled() ->
  true.

-spec handle_request(any(), els_provider:state()) ->
  {any(), els_provider:state()}.
handle_request({symbol, Params}, State) ->
  %% TODO: Version 3.15 of the protocol introduces a much nicer way of
  %%       specifying queries, allowing clients to send the symbol kind.
  #{<<"query">> := Query} = Params,
  {modules(Query), State}.

%%==============================================================================
%% Internal Functions
%%==============================================================================

-spec modules(binary()) -> [symbol_information()].
modules(Query) ->
  {ok, All} = els_dt_document_index:find_by_kind(module),
  Compare   = fun(#{id := X}, #{id := Y}) -> X < Y end,
  AllSorted = lists:sort(Compare, All),
  {ok, RePattern} = re:compile(Query),
  ReOpts = [{capture, none}],
  F = fun(#{id := Id}) ->
          re:run(atom_to_binary(Id, utf8), RePattern, ReOpts) =:= match
      end,
  lists:map(fun symbol_information/1, lists:filter(F, AllSorted)).

-spec symbol_information(els_dt_document_index:item()) -> symbol_information().
symbol_information(#{id := Module, uri := Uri}) ->
  Range = #{from => {1, 1}, to => {1, 1}},
  #{ name => atom_to_binary(Module, utf8)
   , kind => ?SYMBOLKIND_MODULE
   , location => #{ uri => Uri
                  , range => els_protocol:range(Range)
                  }
   }.
