-module(puck_ffi).

-export([priv_directory/0]).

priv_directory() ->
    list_to_binary(code:priv_dir(puck)).
