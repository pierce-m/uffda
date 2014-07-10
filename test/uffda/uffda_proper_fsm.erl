-module(uffda_proper_fsm).
-behavior(proper_fsm).

-export([initial_state/0,
        initial_state_data/0,
        precondition/4,
        postcondition/5,
        next_state/5]).

-define(FSM, uffda_service_fsm).

%% Initial state of a registered FSM
initial_state() -> ?STATE_REGISTERED.

%% Initial data carried by FSM
initial_state_data() -> #state_data{}.

?STATE_REGISTERED(_S) -> [{?STATE_UP, {call, ?FSM, ?STATE_REGISTERED, [online, #state_data{}]}},
                          {?STATE_DOWN, {call, ?FSM, ?STATE_REGISTERED, [offline, #state_data{}]}},
                          {?STATE_STARTING_UP, {call, ?FSM, ?STATE_REGISTERED, [{starting, self()}, #state_data{}]}}].

%% Continue to verify state transitions from here down
?STATE_STARTING_UP(_S) -> [{?STATE_UP, {call, ?FSM, ?STATE_STARTING_UP, [online, #state_data]}},
                           {?STATE_DOWN, {call, ?FSM, ?STATE_STARTING_UP, [offline, #state_data]}},
                           {?STATE_STARTING_UP, {call, ?FSM, ?STATE_STARTING_UP, [{starting, self()}, #state_data{}]}}].

?STATE_RESTARTING(_S) -> [{?STATE_UP, {call, ?FSM, ?STATE_RESTARTING, [online, #state_data{}]}}, 
                          {?STATE_DOWN, {call, ?FSM, ?STATE_RESTARTING, [offline, #state_data{}]}}
                          {?STATE_RESTARTING, {call, ?FSM, ?STATE_RESTARTING, [{starting, self()}, #state_data{}]}}].

?STATE_UP(_S) -> [{?STATE_RESTARTING, {call, ?FSM, ?STATE_UP, [{starting, self()}, #state_data{}]}},
                   {history, {call, ?FSM, ?STATE_UP, [online, #state_data{}]}},
                   {?STATE_DOWN, {call, ?FSM, ?STATE_UP, [offline, #state_data{}]}}].

?STATE_DOWN(_S) -> [{?STATE_RESTARTING, {call, ?FSM, ?STATE_DOWN, [{starting, self()}, #state_data{}]}}
                    {?STATE_UP, {call, ?FSM, ?STATE_DOWN, [online, _]}},
                    {history, {call, ?FSM, ?STATE_DOWN, [offline, _]}}].

%% Continue revising transitions from here
?STATE_DELAYED_START(_S) ->
    [{?STATE_STARTING_UP, {call, ?FSM, ?STATE_DELAYED_START, [{starting, self()}, #state_data{}]}}
     {?STATE_UP, {call, ?FSM, ?STATE_DELAYED_START, [online, #state_data{}]}},
     {?STATE_DOWN, {call, ?FSM, ?STATE_DELAYED_START, [offline, #state_data{}]}}].

?STATE_DELAYED_RESTART(_S) ->
    [{?STATE_RESTARTING, {call, ?FSM, ?STATE_DELAYED_RESTART, [{starting, self()}, #state_data{}]}},
     {?STATE_UP, {call, ?FSM, ?STATE_DELAYED_RESTART, [online, #state_data{}]}},
     {?STATE_DOWN, {call, ?FSM, ?STATE_DELAYED_RESTART, [offline, #state_data{}]}}].

?STATE_CRASHED(_S) ->
    [{?STATE_RESTARTING, {call, ?FSM, ?STATE_CRASHED, [{starting, self()}, #state_data{}]}},
     {?STATE_UP, {call, ?FSM, ?STATE_CRASHED, [online, _]}},
     {?STATE_DOWN, {call, ?FSM, ?STATE_CRASHED, [offline, _]}}].

