%%% @doc 
%%% Implement a command line interface (CLI) over SSH
%%%               
%%% @end 

-module(ui_ssh_cli).

-export([listen/1, listen/2]).

%% %% our shell function
%% -export([start_our_shell/1]).

%% our command functions
-export([cli_prime/1, cli_primes/1, cli_gcd/2, cli_lcm/2,
	 cli_factors/1, cli_exit/0, cli_rho/1, cli_help/0,
	cli_self/0, cli_user/0, cli_host/0, cli_node/0, cli_nodes/0, cli_connect/1, cli_status/0]).

listen(Port) ->
    listen(Port, []).

listen(Port, Options) ->
    error_logger:info_msg("Starting SSH CLI User Interface on port: ~p ~n", [Port]),
    crypto:start(),
    ssh:start(),
    ssh:daemon(any, Port, [{shell, fun(U, H) -> start_our_shell(U, H) end} | Options]).

%% our_routines
our_routines() ->
    [
     {"exit",    ui_ssh_cli, cli_exit,    "            exit application"},
     {"factors", ui_ssh_cli, cli_factors, "<int>       prime factors of <int>"},
     {"gcd",     ui_ssh_cli, cli_gcd,     "<int> <int> greatest common divisor"},
     {"help",    ui_ssh_cli, cli_help,    "            help text"},
     {"lcm",     ui_ssh_cli, cli_lcm,     "<int> <int> least common multiplier"},
     {"prime",   ui_ssh_cli, cli_prime,   "<int>       check for primality"},
     {"primes",  ui_ssh_cli, cli_primes,  "<int>       print all primes up to <int>"},
     {"rho",     ui_ssh_cli, cli_rho,     "<int>       prime factors using rho's alg."},
     {"user",    ui_ssh_cli, cli_user,    "            print name of user"},
     {"host",    ui_ssh_cli, cli_host,    "            print host addr"},
     {"self",    ui_ssh_cli, cli_self,    "            print my pid"},
     {"nodes",   ui_ssh_cli, cli_nodes,   "            print connected nodes"},
     {"node",    ui_ssh_cli, cli_node,    "            print the local node"},
     {"connect", ui_ssh_cli, cli_connect, "<node>      connect to <node>"},
     {"status",  ui_ssh_cli, cli_status,  "            display block status"}
    ].

%% (we could of course generate this from module_info() something like this)
%% our_routines1() ->
%%     {value, {exports, Exports}} =
%% 	lists:keysearch(exports, 1, module_info()),
%%     get_cli(Exports, []).

%% our_args1(N) -> our_args1(N, "").
%% our_args1(0, S) -> S;
%% our_args1(N, S) -> our_args1(N-1, S ++ "<int> ").

%% get_cli([], Acc) ->
%%     lists:sort(Acc);
%% get_cli([{A, Arity} | Rest], Acc) ->
%%     L = atom_to_list(A),
%%     case lists:prefix("cli_", L) of
%% 	true -> get_cli(Rest, [{tl4(L), A, our_args1(Arity)} | Acc]);
%% 	false -> get_cli(Rest, Acc)
%%     end.

%% the longest common prefix of two strings
common_prefix([C | R1], [C | R2], Acc) ->
    common_prefix(R1, R2, [C | Acc]);
common_prefix(_, _, Acc) ->
    lists:reverse(Acc).

%% longest prefix in a list, given a prefix
longest_prefix(List, Prefix) ->
    case [A || {A, _, _} <- List, lists:prefix(Prefix, A)] of
	[] ->
	    {none, List};
	[S | Rest] ->
	    NewPrefix0 =
		lists:foldl(fun(A, P) ->
				    common_prefix(A, P, [])
			    end, S, Rest),
	    NewPrefix = nthtail(length(Prefix), NewPrefix0),
	    {prefix, NewPrefix, [S | Rest]}
    end.			

%%% our expand function (called when the user presses TAB)
%%% input: a reversed list with the row to left of the cursor
%%% output: {yes|no, Expansion, ListofPossibleMatches}
%%% where the atom no yields a beep
%%% Expansion is a string inserted at the cursor
%%% List... is a list that will be printed
%%% Here we beep on prefixes that don't match and when the command
%%% filled in
expand([$  | _]) ->
    {no, "", []};
expand(RevBefore) ->    
    Before = lists:reverse(RevBefore),
    case longest_prefix(our_routines(), Before) of
	{prefix, P, [_]} ->
	    {yes, P ++ " ", []};
	{prefix, "", M} ->
	    {yes, "", M};
	{prefix, P, _M} ->
	    {yes, P, []};
	{none, _M} ->
	    {no, "", []}
    end.

 
%%% spawns out shell loop, we use plain io to input and output
%%% over ssh (the group module is our group leader, and takes
%%% care of sending input to the ssh_sample_cli server)
start_our_shell(User, Peer) ->
  
  spawn(fun() ->
	  io:setopts([{expand_fun, fun(Bef) -> expand(Bef) end}]),
    io:format("~n   W E L C O M E  T O  L i n k B l o x !~n~n"),
		io:format("Enter command\n"),
		put(user, User),
		put(peer_name, Peer),
    % default current node to local node
    put(curr_node, node()),
		our_shell_loop()
	end).


%%% an ordinary Read-Eval-Print-loop
our_shell_loop() ->
  % use the current node for the UI prompt
  Prompt = atom_to_list(get(curr_node)) ++ "> ",
  % Read
  Line = ui_main:get_input(Prompt), %io:get_line(Prompt),
  % Eval
  Result = eval_cli(Line),
  % Print
  io:format("--> ~p\n", [Result]),
  case Result of
	  done -> 
	    exit(normal);
	  _ -> 
	    our_shell_loop()
    end.



%%% evaluate a command line
eval_cli(Line) ->
  case string:tokens(Line, " \n") of
	  [] -> [];
	  [Command | Args] ->
	    case command_to_function(Command) of
        unknown_cmd ->
          io:format("~p Unknown command~n", Command);
        {Module, Function} ->
          io:format("Args: ~p~n", [Args]),
          % Old UI functions expecting Args are in one list, 
		      case catch apply(Module, Function, [Args]) of
			      {'EXIT', Error} ->
			        {error, Error}; % wrong_number_of_arguments};
			      Result ->
			        Result
		      end;
		    Error ->
		      Error
	    end
    end.

%%% translate a command to a function
command_to_function(Command) ->
  case lists:keysearch(Command, 1, our_routines()) of
	  {value, {_, Module, Function, _}} -> {Module, Function};
	  false -> unknown_cmd
  end.

%%% make command arguments to integers
%fix_args(ArgStrings) ->
  %{ok, ArgStrings}.
  %case catch [list_to_integer(A) || A <- ArgStrings] of
	%  {'EXIT', _} ->
	%    {error, only_integer_arguments};
	%  Args ->
	%    {ok, Args}
  %end.
		     
%%% the commands, check for reasonable arguments here too
cli_prime(N) when N < 1000000000 ->
    rho(N) == [N] andalso is_prime(N);
cli_prime(N) when N < 10000 ->
    is_prime(N).

cli_primes(N) when N < 1000000 ->
    primes(N).

cli_gcd(A, B) when is_integer(A), is_integer(B) ->
    gcd(A, B).

cli_lcm(A, B) when is_integer(A), is_integer(B) ->
    lcm(A, B).

cli_factors(A) when A < 1000000 ->
    factors(A).

cli_user() ->
    get(user).

cli_host() ->
    get(peer_name).

cli_self() ->
    self().
    
cli_rho(A) ->
    rho(A).

cli_exit() ->
    done.

cli_status() ->
  ui_main:ui_status([]).

% Execute Erlang BIF node()
cli_node() ->
  io:format( "Node: ~p~n", [node()]).

% Execute Erlang BIF nodes()
cli_nodes() ->  
  io:format( "Nodes: ~p~n", [[node() | nodes()]]).

% Connect ui to another node
cli_connect(Args) ->
  io:format("Connect Args: ~p~n", [Args]),
  ui_main:ui_connect(Args).



help_str(L) ->
    help_str(L, []).
help_str([], Acc) ->
    lists:sort(Acc);
help_str([{CommandName,_, _, HelpS} | Rest], Acc) ->
    C = string:left(CommandName, 10),
    help_str(Rest, [[C, " ", HelpS, $\n] | Acc]).

cli_help() ->
    HelpString = ["CLI Sample\n" | help_str(our_routines())],
    io:format("~s\n", [HelpString]).

%% a quite simple Sieve of Erastothenes (not tail-recursive, though)
primes(Size) ->
    era(math:sqrt(Size), lists:seq(2,Size)).

era(Max, [H|T]) when H =< Max ->
    [H | era(Max, sieve([H|T], H))];
era(_Max, L) -> 
    L.

sieve([H|T], N) when H rem N =/= 0 ->
    [H | sieve(T, N)];
sieve([_H|T], N) ->
    sieve(T, N);
sieve([], _N) ->
    [].

%% another sieve, for getting the next prime incrementally
next_prime([], _) ->
    2;
next_prime([2], 2) ->
    3;
next_prime(Primes, P) ->
    next_prime1(Primes, P).

next_prime1(Primes, P) ->
    P1 = P + 2,
    case divides(Primes, trunc(math:sqrt(P1)), P1) of
	false -> P1;
	true -> next_prime1(Primes, P1)
    end.

divides([], _, _) ->
    false;
divides([A | _], Nsqrt, _) when A > Nsqrt ->
    false;
divides([A | _], _, N) when N rem A == 0 ->
    true;
divides([_ | R], Nsqrt, N) ->
    divides(R, Nsqrt, N).

is_prime(P) ->
    lists:all(fun(A) -> P rem A =/= 0 end, primes(trunc(math:sqrt(P)))).

%% Normal gcd, Euclid
gcd(R, Q) when abs(Q) < abs(R) -> gcd1(Q,R);
gcd(R, Q) -> gcd1(R,Q).

gcd1(0, Q) -> Q;
gcd1(R, Q) ->
    gcd1(Q rem R, R).

%% Least common multiple of (R,Q)
lcm(0, _Q) -> 0;
lcm(_R, 0) -> 0;
lcm(R, Q) ->
    (Q div gcd(R, Q)) * R.

%%% Prime factors of a number (na�ve implementation)
factors(N) ->
    Nsqrt = trunc(math:sqrt(N)),
    factors([], N, 2, Nsqrt, []).
    
factors(_Primes, N, Prime, Nsqrt, Factors) when Prime > Nsqrt ->
    lists:reverse(Factors, [N]);
factors(Primes, N, Prime, Nsqrt, Factors) ->
    case N rem Prime of
	0 ->
	    %%io:format("factor ------- ~p\n", [Prime]),
	    N1 = N div Prime,
	    factors(Primes, N1, Prime, trunc(math:sqrt(N1)), [Prime|Factors]);
	_ ->
	    Primes1 = Primes ++ [Prime],
	    Prime1 = next_prime(Primes1, Prime),
	    factors(Primes1, N, Prime1, Nsqrt, Factors)
    end.

%%% Prime factors using Rho's algorithm ("reminded" from wikipedia.org)
%%% (should perhaps have used Brent instead, but it's not as readable)
rho_pseudo(X, C, N) ->
    (X * X + C) rem N.

rho(N) when N > 1000 ->
    case rho(2, 2, 1, N, fun(X) -> rho_pseudo(X, 1, N) end) of
	failure ->
	    [N];
	F ->
	    lists:sort(rho(F) ++ rho(N div F))
    end;
rho(N) ->
    factors(N).

rho(X, Y, 1, N, Pseudo) ->
    X1 = Pseudo(X),
    Y1 = Pseudo(Pseudo(Y)),
    D = gcd(absdiff(X1, Y1), N),
    rho(X1, Y1, D, N, Pseudo);
rho(_X, _Y, D, N, _Pseudo) when 1 < D, D < N ->
    D;
rho(_X, _Y, D, N, _Pseudo) when D == N ->
    failure.
    
absdiff(A, B) when A > B ->
    A - B;
absdiff(A, B) ->
    B - A.

%%% nthtail as in lists, but no badarg if n > the length of list
nthtail(0, A) -> A;
nthtail(N, [_ | A]) -> nthtail(N-1, A);
nthtail(_, _) -> [].
