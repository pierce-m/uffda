PROJECT = uffda

DEPS = cowboy eper jiffy

V = 0

TEST_DEPS = proper test_commons
dep_proper = git https://github.com/th0114nd/proper master
dep_test_commons = git https://github.com/tigertext/test_commons master


ERLC_OPTS := +debug_info +"{cover_enabled, true}"
COMPILE_FIRST := pubsub/uffda_publisher

# Needed for testing
TEST_ERLC_OPTS := -I include $(ERLC_OPTS)
CT_OPTS := -cover test/uffda.coverspec
CT_SUITES := uffda_basic uffda_registry uffda_service uffda_system uffda_pubsub

DIALYZER_OPTS := -I include test/uffda -Werror_handling -Wrace_conditions -Wunmatched_returns

EDOC_DIRS := ["src", "examples", "test/uffda", "test/test_commons"]
EDOC_OPTS := {preprocess, true}, {source_path, ${EDOC_DIRS}}, nopackages, {subpackages, true}

ERL_PATH := -pa ../uffda/ebin deps/*/ebin 
SERVER := erl -smp enable $(ERL_PATH)

include erlang.mk

run: all
	$(SERVER) -s uffda

dev: all
	$(SERVER) -pa test

images: doc
	mkdir -p doc/images
	dot -Tpng doc/states.dot -o doc/images/states.png
	dot -Tpng doc/tc_proper_model_behaviour.dot -o doc/images/tc_proper_model_behaviour.png
	dot -Tpng doc/unify.dot -o doc/images/unify.png
	dot -Tpng doc/test_hierarchy.dot -o doc/images/test_hierarchy.png

release: clean-release all
	relx -o rel/$(PROJECT)

clean::
	rm -rf rel
	rm -rf _rel
	rm -rf logs
