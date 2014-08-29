-module(uffda_tigertext_sender).

-include("uffda.hrl").
-author('tholland@tigertext.com').
-behavior(uffda_publisher).

-export([send/2]).
-spec send(event(), ass()) -> ok.
send(Event, #ass{address = Address,
                 service = Service,
                 status = Status})
  when is_atom(Event), is_tuple(Address), is_atom(Service), is_atom(Status) ->
    [Event_String, Service_String, Status_String] = [atom_to_list(Item) || Item <- [Event, Service, Status]],
    {Key, Secret, Target} = Address,
    Msg = io_lib:format("uffda/~s: Service ~s is now ~s", [Event_String, Service_String, Status_String]),
    Cmd = io_lib:format("curl -u ~s:~s -vX POST https://api.tigertext.me/v2/message "
                        "-H \"Content-Type:application/x-www-form-urlencoded\" "
                        "-d \"recipient=~s&ttl=1440&body=~s\" ", [Key, Secret, Target, Msg]),
    Output = os:cmd(Cmd),
    ok.
