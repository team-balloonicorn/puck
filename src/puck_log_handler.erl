-module(puck_log_handler).

-export([install/1, anything_to_string/1]).
% Logger callbacks
-export([log/2]).

install(SendEmail) ->
    ok = logger:add_handler(?MODULE, ?MODULE, #{config => SendEmail}),
    nil.

log(Event, #{config := SendEmail}) ->
    case Event of
        #{level := error, msg := Error} ->
            erlang:spawn(fun() -> handle_error(Error, SendEmail) end);

        _ ->
            nil
    end.

handle_error(Error, SendEmail) ->
    try
        case Error of
            {string, String} -> SendEmail(String);
            Other -> SendEmail(anything_to_string(Other))
        end
    catch
        _:EmailError -> logger:warning(anything_to_string({
            failed_to_send_error_email, EmailError
        }))
    end.

anything_to_string(Term) ->
    list_to_binary(io_lib:format("~p", [Term])).
