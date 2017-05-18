%%% @doc 
%%% Block Type: Logic Exclusive OR 
%%% Description:  Set the block output value to boolean Exclusive OR of the inputs
%%%               
%%% @end 

-module(lblx_logic_xor).  

-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0, description/0, version/0]).
-export([create/2, create/4, create/5, upgrade/1, initialize/1, execute/2, delete/1, handle_info/2]).

groups() -> [logic].

description() -> "XOR of the Binary Inputs".

version() -> "0.1.0".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: block_name(),
                      Description :: string()) -> list(config_attr()).

default_configs(BlockName, Description) -> 
  attrib_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
    ]). 


-spec default_inputs() -> list(input_attr()).

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {input_a, {empty, ?EMPTY_LINK}}, 
      {input_b, {empty, ?EMPTY_LINK}} 
  ]). 


-spec default_outputs() -> list(output_attr()).
                            
default_outputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:outputs(),
    [
    ]). 


%%  
%% Create a set of block attributes for this block type.  
%% Init attributes are used to override the default attribute values
%% and to add attributes to the lists of default attributes
%%
-spec create(BlockName :: block_name(),
             Description :: string()) -> block_defn().

create(BlockName, Description) -> 
  create(BlockName, Description, [], [], []).

-spec create(BlockName :: block_name(),
             Description :: string(),  
             InitConfig :: list(config_attr()), 
             InitInputs :: list(input_attr())) -> block_defn().
   
create(BlockName, Description, InitConfig, InitInputs) -> 
  create(BlockName, Description, InitConfig, InitInputs, []).

-spec create(BlockName :: block_name(),
             Description :: string(), 
             InitConfig :: list(config_attr()), 
             InitInputs :: list(input_attr()), 
             InitOutputs :: list(output_attr())) -> block_defn().

create(BlockName, Description, InitConfig, InitInputs, InitOutputs) ->

  % Update Default Config, Input, Output, and Private attribute values 
  % with the initial values passed into this function.
  %
  % If any of the intial attributes do not already exist in the 
  % default attribute lists, merge_attribute_lists() will create them.
    
  Config = attrib_utils:merge_attribute_lists(default_configs(BlockName, Description), InitConfig),
  Inputs = attrib_utils:merge_attribute_lists(default_inputs(), InitInputs), 
  Outputs = attrib_utils:merge_attribute_lists(default_outputs(), InitOutputs),

  % This is the block definition, 
  {Config, Inputs, Outputs}.


%%
%% Upgrade block attribute values, when block code and block data versions are different
%% 
-spec upgrade(BlockDefn :: block_defn()) -> {ok, block_defn()} | {error, atom()}.

upgrade({Config, Inputs, Outputs}) ->
  ModuleVer = version(),
  {BlockName, BlockModule, ConfigVer} = config_utils:name_module_version(Config),
  BlockType = type_utils:type_name(BlockModule),

  case attrib_utils:set_value(Config, version, version()) of
    {ok, UpdConfig} ->
      log_server:info(block_type_upgraded_from_ver_to, 
                            [BlockName, BlockType, ConfigVer, ModuleVer]),
      {ok, {UpdConfig, Inputs, Outputs}};

    {error, Reason} ->
      log_server:error(err_upgrading_block_type_from_ver_to, 
                            [Reason, BlockName, BlockType, ConfigVer, ModuleVer]),
      {error, Reason}
  end.


%%
%% Initialize block values
%% Perform any setup here as needed before starting execution
%%
-spec initialize(BlockState :: block_state()) -> block_state().

initialize({Config, Inputs, Outputs, Private}) ->
  
  % No config values to check
  
  Outputs1 = output_utils:set_value_status(Outputs, null, initialed),  

  % This is the block state
  {Config, Inputs, Outputs1, Private}.


%%
%%  Execute the block specific functionality
%%
-spec execute(BlockState :: block_state(), 
              ExecMethod :: exec_method()) -> block_state().

execute({Config, Inputs, Outputs, Private}, _ExecMethod) ->

  case input_utils:get_boolean(Inputs, input_a) of
    {ok, null} ->
      Value = null, Status = no_input;
    
    {ok, InputA} ->
      case input_utils:get_boolean(Inputs, input_b) of
        {ok, null} ->
          Value = null, Status = no_input;
    
        {ok, InputB} ->
          Status = normal,
          % Exclusive OR, if one or the other, but not both are true, output is true
          Value = (InputA andalso (not InputB)) orelse ((not InputA) andalso InputB);
        
        {error, Reason} ->
          {Value, Status} = input_utils:log_error(Config, input_b, Reason)
      end;

    {error, Reason} ->
      {Value, Status} = input_utils:log_error(Config, input_a, Reason)
  end,
   
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

  % Return updated block state
  {Config, Inputs, Outputs1, Private}.


%% 
%%  Delete the block
%%	
-spec delete(BlockState :: block_state()) -> block_defn().

delete({Config, Inputs, Outputs, _Private}) -> 
  {Config, Inputs, Outputs}.


%% 
%% Unknown Info message, just log a warning
%% 
-spec handle_info(Info :: term(), 
                  BlockState :: block_state()) -> {noreply, block_state()}.

handle_info(Info, BlockState) ->
  log_server:warning(block_server_unknown_info_msg, [Info]),
  {noreply, BlockState}.


%% ====================================================================
%% Internal functions
%% ====================================================================


%% ====================================================================
%% Tests
%% ====================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

block_test_() ->
  {"Input to Output tests for: " ++ atom_to_list(?MODULE),
   {setup, 
      fun setup/0, 
      fun cleanup/1,
      fun (BlockState) -> 
        {inorder,
        [
          test_io(BlockState)
        ]}
      end} 
  }.

setup() ->
  unit_test_utils:block_setup(?MODULE).

cleanup(BlockState) ->
  unit_test_utils:block_cleanup(?MODULE, BlockState).

test_io(BlockState) ->
  unit_test_utils:create_io_tests(?MODULE, input_cos, BlockState, test_sets()).

test_sets() ->
  [
    {[], [{status, no_input}, {value, null}]},
    {[{input_a, null}, {input_b, false}], [{status, no_input}, {value, null}]},
    {[{input_a, true}, {input_b, null}], [{status, no_input}, {value, null}]},
    {[{input_a, bad_value}, {input_b, false}], [{status, input_err}, {value, null}]},
    {[{input_a, true}, {input_b, bad_value}], [{status, input_err}, {value, null}]},
    {[{input_a, false}, {input_b, false}], [{status, normal}, {value, false}]},
    {[{input_a, true}, {input_b, false}], [{status, normal}, {value, true}]},
    {[{input_a, false}, {input_b, true}], [{status, normal}, {value, true}]},
    {[{input_a, true}, {input_b, true}], [{status, normal}, {value, false}]}
  ].


-endif.