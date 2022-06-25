-module(puck_ffi).

-export([priv_directory/0, timestamp/0]).

priv_directory() ->
    list_to_binary(code:priv_dir(puck)).

timestamp() ->
    Now = erlang:system_time(second),
    Timestamp = list_to_binary(calendar:system_time_to_rfc3339(Now)),
    Date = binary:part(Timestamp, 0, 10),
    Time = binary:part(Timestamp, 11, 8),
    <<Date/binary, " ", Time/binary>>.
