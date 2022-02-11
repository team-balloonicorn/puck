-module(gleam_gen_smtp_ffi).

-export([send/2]).

send(
    {email, FromEmail, FromName, To, Subject, Body},
    {options, Relay, Port, Username, Password, Ssl, Auth, Retries}
) ->
    ToEntries = list_to_binary(lists:join(",", To)),
    Email = <<
        "Subject: ", Subject/binary, "\r\n",
        "From: ", FromName/binary, "<", FromEmail/binary, ">\r\n",
        "To: ", ToEntries/binary, "\r\n",
        "\r\n",
        Body/binary
    >>,

    Options = [
        {relay, Relay},
        {port, Port},
        {username, Username},
        {password, Password},
        {auth, Auth},
        {ssl, Ssl},
        {retries, Retries}
    ],

    case gen_smtp_client:send_blocking({FromEmail, To, Email}, Options) of
        Receipt when is_binary(Receipt) -> {ok, nil}
    end.
