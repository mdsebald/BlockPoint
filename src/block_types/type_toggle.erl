%%% @doc 
%%% Block Type: Toggle Output
%%% Description: Toggle binary output value each time block is executed  
%%%               
%%% @end 

-module(type_toggle).

-author("Mark Sebald").

-include("../block_state.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([type_name/0, description/0, version/0]). 
-export([create/2, create/4, create/5, initialize/1, execute/1, delete/1]).


type_name() -> "toggle".

description() -> "Toggle binary output value on block execution".

version() -> "0.1.0". 


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: atom(),
                      Description :: string()) -> list().

default_configs(BlockName, Description) -> 
  block_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [

    ]). 


-spec default_inputs() -> list().

default_inputs() -> 
  block_utils:merge_attribute_lists(
    block_common:inputs(),
    [

    ]). 


-spec default_outputs() -> list().
                            
default_outputs() -> 
  block_utils:merge_attribute_lists(
    block_common:outputs(),
    [

    ]). 

%%  
%% Create a set of block attributes for this block type.  
%% Init attributes are used to override the default attribute values
%% and to add attributes to the lists of default attributes
%%
-spec create(BlockName :: atom(),
             Description :: string()) -> block_defn().

create(BlockName, Description) -> 
  create(BlockName, Description, [], [], []).

-spec create(BlockName :: atom(),
             Description :: string(),  
             InitConfig :: list(), 
             InitInputs :: list()) -> block_defn().
   
create(BlockName, Description, InitConfig, InitInputs) -> 
  create(BlockName, Description, InitConfig, InitInputs, []).

-spec create(BlockName :: atom(),
             Description :: string(), 
             InitConfig :: list(), 
             InitInputs :: list(), 
             InitOutputs :: list()) -> block_defn().

create(BlockName, Description, InitConfig, InitInputs, InitOutputs)->

  %% Update Default Config, Input, Output, and Private attribute values 
  %% with the initial values passed into this function.
  %%
  %% If any of the intial attributes do not already exist in the 
  %% default attribute lists, merge_attribute_lists() will create them.
  %% (This is useful for block types where the number of attributes is not fixed)
    
  Config = block_utils:merge_attribute_lists(default_configs(BlockName, Description), InitConfig),
  Inputs = block_utils:merge_attribute_lists(default_inputs(), InitInputs), 
  Outputs = block_utils:merge_attribute_lists(default_outputs(), InitOutputs),

  % This is the block definition, 
  {Config, Inputs, Outputs}.

%%
%% Initialize block values before starting execution
%% Perform any setup here as needed before starting execution
%%
-spec initialize(block_state()) -> block_state().

initialize({Config, Inputs, Outputs, Private}) ->

  Outputs1 = output_utils:set_value_status(Outputs, not_active, initialed),
 
  {Config, Inputs, Outputs1, Private}.


%%
%%  Execute the block specific functionality
%%
-spec execute(block_state()) -> block_state().

execute({Config, Inputs, Outputs, Private}) ->

  % Toggle output everytime block is executed
  case block_utils:get_value(Outputs, value) of
    {ok, true}       -> Value = false,      Status = normal;
    {ok, false}      -> Value = true,       Status = normal;
    {ok, not_active} -> Value = true,       Status = normal;
    _                -> Value = not_active, Status = error
  end,
	
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),
     
  {Config, Inputs, Outputs1, Private}.


%% 
%%  Delete the block
%%	
-spec delete(block_state()) -> ok.

delete({_Config, _Inputs, _Outputs, _Private}) ->
    ok.


%% ====================================================================
%% Internal functions
%% ====================================================================