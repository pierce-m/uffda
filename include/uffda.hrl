-type service_name()    :: atom().
-type service_pid()     :: pid().
-type service_fsm()     :: atom().
-type service_fsm_pid() :: pid().

-type register_option() :: {max_startup_millis, non_neg_integer()}.


-type service_event()   :: unregister
                         | {starting, service_pid()}
                         | {re_init,  service_pid()}
                         | online
                         | offline
                         | current_status.

-type service_status()  :: not_registered
                         | registered
                         | starting_up
                         | restarting
                         | slow_start
                         | slow_restart
                         | crashed
                         | down
                         | up.

-define(MAX_STARTUP_TIME, 3000).

-define(IF_UFFDA_RUNNING(__Server, __Action),
        case whereis(__Server) of
            undefined -> {error, {not_started, __Server}};
            __Uffda_Pid when is_pid(__Uffda_Pid) ->
                __Action
        end).

-define(PUBLISH_MGR, uffda_publish_manager).

-type sub_type() :: pid | sse | email | text.

-type event() :: subscription_starting | updating | unsubscribe.

-type call() :: report_subscriber.

-type state() :: {module(), ass()}.

-type address() :: pid() | string() | {string(), string(), string()}.
-record(ass, {address :: address(),
              service :: service_name(),
              status :: nonexistent | service_status()}).
-type ass() :: #ass{}.
