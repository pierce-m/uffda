%% @doc
%%   A tc_proper_model is a behaviour which describes a scenario and a set of events,
%%   deduces the expected results and then observes and compares the actual results when
%%   the events are fed to the scenario. The scenario is expected to be a description
%%   of a running erlang configuration (e.g., a supervisor hierarchy with children),
%%   while the events are a series of exported function calls or actions that impact
%%   the corresponding running erlang scenario.
%%
%%   A collection of scenarios can be generated either by using file:consult/1 on a
%%   static set of scenario descriptions, or by using proper to generate random
%%   scenario descriptions. A static set could be generated by saving randomly
%%   generated scenarios or by hand-editing specific scenarios that reproduce an
%%   actual bug observed in production afflicting the software being tested.
%% @end
-module(tc_proper_model).

%% External API: Certifying code against a set of proper model instances.
-export([
         test_all_models/1,
         verify_all_scenarios/1
        ]).

%% Steps used to validate a single scenario.
-export([
         generate_test_case/2,
         generate_observed_case/2,
         passed_test_case/2
        ]).

-include("tc_proper_model.hrl").

%% Behaviour callbacks for generating a tc_proper_model and expected outcomes
-callback get_all_test_model_ids() -> [{Model_Id :: tc_proper_model_id(), Source :: tc_proper_model_source()}].
-callback generate_proper_model(Model_Id :: tc_proper_model_id(), Source :: tc_proper_model_source()) -> tc_proper_model().
-callback deduce_proper_expected_status(Scenario_Instance :: tc_proper_scenario()) -> Expected_Status :: term().

%% Behaviour callbacks used per scenario when validating against the model
-callback vivify_proper_scenario(Scenario :: tc_proper_scenario()) -> tc_proper_scenario_live_ref().
-callback translate_proper_scenario_dsl(tc_proper_scenario_dsl_desc()) -> tc_proper_scenario_live_desc().
-callback translate_proper_scenario_events(tc_proper_scenario_dsl_events()) -> tc_proper_scenario_live_events().
-callback generate_proper_observation(Test_Case_Instance :: tc_proper_test_case()) -> Observed_Status :: term().
-callback passed_proper_test_case(Case_Number     :: pos_integer(),
                                  Expected_Status :: tc_proper_scenario_dsl_status(),
                                  Observed_Status :: tc_proper_scenario_live_status()) -> boolean().


%%-------------------------------------------------------------------
%% External API for testing all models implemented by a module.
%%-------------------------------------------------------------------

-spec test_all_models(module()) -> [{tc_proper_model_id(), tc_proper_model_result()}].
test_all_models(Module) ->
    [begin
         Test_Model = Module:generate_proper_model(Model_Id, Source),
         {Model_Id, verify_all_scenarios(Test_Model)}
     end || {Model_Id, Source} <- Module:get_all_test_model_ids()].

-spec verify_all_scenarios(Test_Model :: tc_proper_model()) -> tc_proper_model_result().
%% @doc
%%   Given a model and corresponding scenarios, generate observed test cases and
%%   validate that they all pass.
%% @end
verify_all_scenarios(#tc_proper_model{scenarios=[]}) -> {true, []};
verify_all_scenarios(#tc_proper_model{behaviour=Module, scenarios=Scenarios}) ->
    {Success, Success_Case_Count, Failed_Cases}
        = lists:foldl(fun(#tc_proper_scenario{instance=Case_Number} = Scenario_Instance,
                          {Boolean_Result, Success_Case_Count, Failures}) when Case_Number > 0 ->
                        try
                            Test_Case     = generate_test_case     (Module, Scenario_Instance),
                            Observed_Case = generate_observed_case (Module, Test_Case),
                            case passed_test_case(Module, Observed_Case) of
                                %% Errors should not be possible as we have filled in Observed_Case properly.
                                {ok, true}  -> {Boolean_Result, Success_Case_Count+1, Failures};
                                {ok, false} -> {false,          Success_Case_Count,   [Observed_Case | Failures]}
                            end
                        catch Error:Type ->
                                error_logger:error_msg("Scenario instance ~p crashed with ~p  Stacktrace: ~p~n",
                                                       [Scenario_Instance, {Error, Type}, erlang:get_stacktrace()]),
                                {false, Success_Case_Count, [Scenario_Instance | Failures]}
                        end
                end, {true, 0, []}, Scenarios),
    {Success, Success_Case_Count, lists:reverse(Failed_Cases)}.


%%-------------------------------------------------------------------
%% Internal API steps used to validate a single scenario.
%%-------------------------------------------------------------------

-spec generate_test_case(module(), tc_proper_scenario()) -> tc_proper_test_case().
%% @doc
%%   Given a test case scenario to be set up, and a series of events, create a full
%%   test case by letting the behaviour module deduce the resulting status after
%%   executing the scenario. The passed in test_case should have all fields specified
%%   and not just a default initialization of the tc_proper_scenario() type.
%% @end
generate_test_case(Module, #tc_proper_scenario{instance=Case_Number} = Scenario_Instance)
  when is_integer(Case_Number), Case_Number > 0 ->
    Expected_Status = Module:deduce_proper_expected_status(Module, Scenario_Instance),
    #tc_proper_test_case{scenario=Scenario_Instance, expected_status=Expected_Status}.

-spec generate_observed_case(module(), Unexecuted_Test_Case :: tc_proper_test_case()) -> Result :: tc_proper_test_case().
%% @doc
%%   Given a test case that has not been executed yet, set up the scenario, stream
%%   the events to the scenario and then retrieve the observed status. This function
%%   returns an instance of an observed test case that can be validated later.
%% @end
generate_observed_case(Module,
                       #tc_proper_test_case{scenario=#tc_proper_scenario{instance=Case_Number} = Scenario_Dsl,
                                            observed_status=?TC_MISSING_TEST_CASE_ELEMENT} = Unexecuted_Test_Case)
  when is_integer(Case_Number), Case_Number > 0 ->
    Live_Model_Ref = Module:vivify_proper_scenario(Scenario_Dsl),
    Observation = Module:generate_proper_observation(Module, Unexecuted_Test_Case),
    #tc_proper_test_case{observed_status=Observation}.

-spec passed_test_case(module(), Observed_Test_Case :: tc_proper_test_case())
      -> {ok, boolean()}
             | {error, {expected_status_not_generated, tc_proper_test_case()}}
             | {error, {observed_status_not_generated, tc_proper_test_case()}}.
%% @doc
%%   Given a test case that has already been executed and contains an observed
%%   result status, use the behaviour module to verify if the expected status
%%   matches the observed status.
%% @end
passed_test_case(_Module, #tc_proper_test_case{expected_status=?TC_MISSING_TEST_CASE_ELEMENT} = Observed_Test_Case) ->
    {error, {expected_status_not_generated, Observed_Test_Case}};
passed_test_case(_Module, #tc_proper_test_case{observed_status=?TC_MISSING_TEST_CASE_ELEMENT} = Observed_Test_Case) ->
    {error, {observed_status_not_generated, Observed_Test_Case}};
passed_test_case( Module, #tc_proper_test_case{scenario=#tc_proper_scenario{instance=Case_Number}} = Observed_Test_Case)
  when is_integer(Case_Number), Case_Number > 0 ->
    #tc_proper_test_case{expected_status=Expected, observed_status=Observed} = Observed_Test_Case,
    Module:passed_proper_test_case(Case_Number, Expected, Observed).