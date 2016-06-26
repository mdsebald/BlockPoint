%%% @doc 
%%% API Server.  gen_server behavior to handle requests from UI clients
%%%
%%% @end

-module(linkblox_api).

-author("Mark Sebald").

-include("block_state.hrl").

-behaviour(gen_server).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
					start/0,
					stop/1,
					create_block/4,
					delete_block/2,
					get_block/2,
					get_value/3,
					get_block_names/1,
					get_types_info/1,
					get_type_info/2,
					set_value/4,
					set_link/4,
					execute_block/2,
         	is_block_name/2, 
				 	is_block_type/2
]). 


%% Start the LinkBlox API Server
start()->
  gen_server:start_link({local, linkblox_api}, ?MODULE, null, []).


%% Stop the LinkBlox API server
stop(Node) ->
	gen_server:call({linkblox_api, Node}, stop).


%%
%% Process API calls
%%

%% Create a block
-spec create_block(Node :: node(),
									 BlockType :: type_name(),
									 BlockName :: block_name(),
									 InitAttribs :: list()) -> term().

create_block(Node, BlockType, BlockName, InitAttribs) ->
	gen_server:call({linkblox_api, Node}, 
	                {create_block, BlockType, BlockName, InitAttribs}).


%% delete a block
-spec delete_block(Node :: node(),
									 BlockName :: block_name()) -> term().

delete_block(Node, BlockName) ->
	gen_server:call({linkblox_api, Node}, 
	                {delete_block, BlockName}).


%% Get block values
-spec get_block(Node :: node(),
								BlockName :: block_name()) -> term().

get_block(Node, BlockName) ->
	gen_server:call({linkblox_api, Node}, {get_block, BlockName}).


%% Get a block value
-spec get_value(Node :: node(),
								BlockName :: block_name(),
								ValueId :: value_id()) -> term().

get_value(Node, BlockName, ValueId) ->
	gen_server:call({linkblox_api, Node}, {get_value, BlockName, ValueId}).


%% Get list of block names
-spec get_block_names(Node :: node()) -> term().

get_block_names(Node) ->
	gen_server:call({linkblox_api, Node}, get_block_names).


%% Get list of block types information
-spec get_types_info(Node :: node()) -> term().

get_types_info(Node) ->
	gen_server:call({linkblox_api, Node}, get_types_info).


%% Get the block type information for the given block
-spec get_type_info(Node :: node(),
                    BlockName :: block_name()) -> term().

get_type_info(Node, BlockName) ->
	gen_server:call({linkblox_api, Node}, {get_type_info, BlockName}).

%% Set a block value
-spec set_value(Node :: node(),
                BlockName :: block_name(),
								ValueId :: value_id(),
								Value :: value()) -> ok | {error, atom()}.

set_value(Node, BlockName, ValueId, Value) ->
	gen_server:call({linkblox_api, Node}, {set_value, BlockName, ValueId, Value}).



%% Link block input to a block output
-spec set_link(Node :: node(),
                  BlockName :: block_name(),
									InputValueId :: value_id(),
									Link :: input_link()) -> term().

set_link(Node, BlockName, InputValueId, Link) ->
	gen_server:call({linkblox_api, Node}, {set_link, BlockName, InputValueId, Link}).


%% Execute the block
-spec execute_block(Node :: node(),
                    BlockName :: block_name()) -> term().

execute_block(Node, BlockName) ->
	gen_server:call({linkblox_api, Node}, {execute_block, BlockName}).


%% Is BlockName a valid block name?
-spec is_block_name(Node :: node(),
										BlockName :: block_name()) -> term().

is_block_name(Node, BlockName) ->
	gen_server:call({linkblox_api,Node}, {is_block_name, BlockName}).


%% Is BlockTypeStr a valid block type name?
-spec is_block_type(Node :: node(),
										BlockType :: type_name()) -> term().

is_block_type(Node, BlockType) ->
	gen_server:call({linkblox_api, Node}, {is_block_type, BlockType}).

%command(Command, Args)->
 % gen_server:call(linkblox_api, {comand, Command, Args}).


%% ====================================================================
%% Behavioural functions
%% ====================================================================
	

%% ==================================================================== 
%% init/1
%% ====================================================================
-spec init(Args :: term()) -> Result when
	Result :: {ok, State}
			| {ok, State, Timeout}
			| {ok, State, hibernate}
			| {stop, Reason :: term()}
			| ignore,
	State :: term(),
	Timeout :: non_neg_integer() | infinity.

init(null) ->
  error_logger:info_msg("Starting LinkBlox API server~n"),
  {ok, []}.

%% ====================================================================
%% handle_call/3
%% ====================================================================
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) -> Result when
	Result :: {reply, Reply, NewState}
			| {reply, Reply, NewState, Timeout}
			| {reply, Reply, NewState, hibernate}
			| {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason, Reply, NewState}
			| {stop, Reason, NewState},
	Reply :: term(),
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().


%% =====================================================================
%% Stop the API server
%% =====================================================================
handle_call(stop, _From, State) ->  
  error_logger:info_msg("Stopping LinkBlox API server~n"),

  {stop, normal, ok, State};

%% =====================================================================
%% Create a block
%% =====================================================================    
% TODO: Set initial attribute values
handle_call({create_block, BlockType, BlockName, _InitAttribs}, _From, State) ->
	case lists:member(BlockType, block_types:block_type_names()) of
		true ->
			BlockModule = block_types:block_type_to_module(BlockType),
  		case valid_block_name(BlockName) of
				false ->
					BlockValues = BlockModule:create(BlockName, "Default Comment"),
					case block_supervisor:create_block(BlockValues) of
            {ok, _Pid} -> 
          		Result = ok;
            {error, Reason} -> 
              Result = {error, Reason}
					end;
				_ ->
					Result = {error, block_exists}
			end;
		_ ->
			Result = {error, invalid_block_type}
	end,
  {reply, Result, State};

%% =====================================================================
%% Delete a block
%% =====================================================================    
handle_call({delete_block, BlockName}, _From, State) ->
	case valid_block_name(BlockName) of
		true ->
			case block_supervisor:delete_block(BlockName) of
        ok -> 
					Result = ok;
				{error, Reason} -> 
					Result = {error, Reason}
			end;
		_ ->
			Result = {error, block_not_found}
	end,
  {reply, Result, State};


%% =====================================================================
%% Get all block values
%% =====================================================================    
handle_call({get_block, BlockName}, _From, State) ->
	case valid_block_name(BlockName) of
		true ->
			{Config, Inputs, Outputs, _Private} = block_server:get_block(BlockName),
			% Strip private values,
			Result = {ok, {Config, Inputs, Outputs}};
		_ ->
			Result = {error, block_not_found}
	end,
  {reply, Result, State};


%% =====================================================================
%% Get a block value
%% =====================================================================    
handle_call({get_value, BlockName, ValueId}, _From, State) ->
	case valid_block_name(BlockName) of
		true ->
      case block_server:get_value(BlockName, ValueId) of
				{ok, CurrentValue} ->
					Result = {ok, CurrentValue};

      	{error, not_found} ->
					Result = {error, value_not_found};

				{error, Reason} ->
					Result = {error, Reason}
			end;
		_ ->
			Result = {error, block_not_found}
	end,
  {reply, Result, State};


%% =====================================================================
%% Get a list of all block names
%% =====================================================================    
handle_call(get_block_names, _From, State) ->
	Result = block_supervisor:block_names(),
  {reply, Result, State};


%% =====================================================================
%% Get a list of all block types information 
%% =====================================================================    
handle_call(get_types_info, _From, State) ->
	Result = block_types:block_types_info(),
  {reply, Result, State};


%% =====================================================================
%% Get the type info for the given block name 
%% =====================================================================    
handle_call({get_type_info, BlockName}, _From, State) ->
	% Get the block_module (i.e. block code), for the given block
	% Block type info is in there.
	case block_server:get_value(BlockName, block_module) of
		{ok, BlockModule} ->
			Result = block_types:block_type_info(BlockModule);

		{error, Reason} ->
			Result = {error, Reason}	
	end,
  {reply, Result, State};


%% =====================================================================
%% Set a block value 
%% =====================================================================    
handle_call({set_value, BlockName, ValueId, Value}, _From, State) ->
	case valid_block_name(BlockName) of
		true ->
			Result = block_server:set_value(BlockName, ValueId, Value);

		_ ->
			Result = {error, block_not_found}
	end,
  {reply, Result, State};	


%% =====================================================================
%% Link block input to a block output 
%% =====================================================================    
handle_call({set_link, BlockName, InputValueId, Link}, _From, State) ->
	case valid_block_name(BlockName) of
		true ->
			Result = block_server:set_link(BlockName, InputValueId, Link);

		_ ->
			Result = {error, block_not_found}
	end,
  {reply, Result, State};	


%% =====================================================================
%% Execute block
%% =====================================================================    
handle_call({execute_block, BlockName}, _From, State) ->
	case valid_block_name(BlockName) of
		true ->
			block_server:execute(BlockName),
			Result = ok;
		_ ->
			Result = {error, block_not_found}
	end,
  {reply, Result, State};


%% =====================================================================
%% Is BlockNameStr a valid block name?
%% =====================================================================    
handle_call({is_block_name, BlockName}, _From, State) ->
  case valid_block_name(BlockName) of
		true-> 
			Result = true;
		_ ->
			Result = false
	end,
  {reply, Result, State};


%% =====================================================================
%% Is BlockTypeStr a valid block type?
%% =====================================================================    
handle_call({is_block_type, BlockType}, _From, State) ->
  Result = lists:member(BlockType, block_types:block_type_names()),
  {reply, Result, State};


%% =====================================================================
%% Unknown Call message
%% =====================================================================      
handle_call(Request, From, State) ->
  error_logger:warning_msg("linkblox_api: Unknown call message: ~p From: ~p~n", 
                            [Request, From]),
  {reply, ok, State}.


%% ====================================================================
%% handle_cast/2
%% ====================================================================
-spec handle_cast(Request :: term(), State :: term()) -> Result when
  Result :: {noreply, NewState}
     | {noreply, NewState, Timeout}
     | {noreply, NewState, hibernate}
     | {stop, Reason, NewState},
  NewState :: term(),
  Timeout :: non_neg_integer() | infinity,
  Reason :: term().

%% =====================================================================
%% Unknown Cast message
%% =====================================================================      
handle_cast(Msg, State) ->
  error_logger:warning_msg("linkblox_api: Unknown cast message: ~p~n", [Msg]),
  {noreply, State}.


%% ====================================================================
%% handle_info/2
%% ====================================================================
-spec handle_info(Info :: timeout | term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.


%% =====================================================================
%% Unknown Info message
%% =====================================================================
handle_info(Info, State) ->
  error_logger:warning_msg("Unknown info message: ~p~n", [Info]),
  {noreply, State}.


%% ====================================================================
%% terminate/2
%% ====================================================================
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
      
terminate(normal, _State) ->
  ok;
    
terminate(Reason, _State) ->
  error_logger:error_msg("LinkBlox API server, Abnormal Termination: ~p~n", [Reason]),
  ok.


%% ====================================================================
%% code_change/3
%% ====================================================================
-spec code_change(OldVsn, State :: term(), Extra :: term()) -> Result when
	Result :: {ok, NewState :: term()} | {error, Reason :: term()},
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
  
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================

%%
%% Is the BlockName a valid block name?
%%
-spec valid_block_name(BlockName :: block_name())-> boolean().

valid_block_name(BlockName)->
  lists:member(BlockName, block_supervisor:block_names()).


%% ====================================================================
%% Tests
%% ====================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-ifdef(UNDER_DEVELOPMENT).

linkblox_api_test_() ->
	{
		setup,
		fun start_linkblox_api/0,
		fun stop_linkblox_api/1,
		fun() ->
			{
				inorder,
			 	[
					create_block_test(),
					delete_block_test()
				]
			}
		end
	}.

start_linkblox_api() ->
	% Need to start LinkBlox Supervisor
	% That will start the API Server, (i.e. this module) and the block supervisor
	% which is needed for some calls
	% TODO: May not be able to get this to work.  
	%   node() returns 'nonode@nohost'. May not be valid  
	linkblox_supervisor:start_link("NoFile"). 
 
stop_linkblox_api(_) ->
	stop(node()).

create_block_test() ->
	create_block(node(), "template", "test_block", []).

delete_block_test() ->
	delete_block(node(), "test_block"). 

-endif.
-endif.