-module(uffda_subscription).

-export([start_link/0,
         subscribe/3,
         subscribe/4,
         subscribe_file/2,
         unsubscribe/3,
         notify/2]).

-author('tholland@tigertext.com').
-include("uffda.hrl").

-spec start_link() -> {ok, pid()} | {error, {already_started, pid()}}.
start_link() ->
    gen_event:start_link({local, ?PUBLISH_MGR}).

-spec find_vars(sub_type(), address(), service_name(), nonexistent | service_status()) ->
    {{module(), address(), service_name()}, state()}.
find_vars(Sub_Type, Address, Service, Status) ->
    Module = case Sub_Type of
        pid -> uffda_pid_sender;
        sse -> uffda_pid_sender;
        email -> uffda_email_sender;
        sms -> uffda_sms_sender;
        tigertext -> uffda_tigertext_sender
        end,
    Ass = #ass{address = Address,
               service = Service,
               status = Status},
    Mass = {Module, Ass},
    Id = {Module, Address, Service}, 
    {Id, Mass}.

-spec subscribe(sub_type(), address(), service_name()) -> ok | {error, any()}.
subscribe(Sub_Type, Address, Service) ->
    Status = case uffda_client:service_status(Service) of
        Stat when is_atom(Stat) -> Stat;
        {error, _} -> nonexistent
        end,
    subscribe(Sub_Type, Address, Service, Status).
    
-spec subscribe(sub_type(), address(), service_name(), service_status()) -> ok.
subscribe(Sub_Type, Address, Service, Status)
  when is_atom(Sub_Type), is_list(Address) or is_pid(Address) or is_tuple(Address), is_atom(Service), is_atom(Status) ->
    {Id, Mass} = find_vars(Sub_Type, Address, Service, Status),
    gen_event:add_handler(?PUBLISH_MGR, {uffda_publisher, Id}, Mass).

-spec subscribe_file(file:name_all(), service_name()) -> ok.
subscribe_file(File_Name, Service) ->
    case file:consult(File_Name) of
        {ok, Subscribers} -> _ = [subscribe(Type, Address, Service) || {Type, Address} <- Subscribers], ok;
        _ -> error_logger:error_msg("Could not read subscribers from ~s", [File_Name])
    end.

-spec unsubscribe(sub_type(), address(), service_name()) -> ok.
unsubscribe(Sub_Type, Address, Service)
  when is_atom(Sub_Type), is_list(Address) or is_pid(Address) or is_tuple(Address), is_atom(Service) ->
    {Id, _Mass} = find_vars(Sub_Type, Address, Service, nonexistent),
    gen_event:delete_handler(?PUBLISH_MGR, {uffda_publisher, Id}, stop).

-spec notify(service_name(), service_status()) -> ok.
notify(Service, Status)
  when is_atom(Service), is_atom(Status) ->
    gen_event:notify(?PUBLISH_MGR, {publish, Service, Status}).
