ERL          ?= erl
EBIN_DIRS    := $(wildcard deps/*/ebin)
APP          := gen_bunny

all: rabbitmq-server rabbitmq-erlang-client effigy erl

erl: ebin/$(APP).app src/$(APP).app.src
	@$(ERL) -pa ebin -pa $(EBIN_DIRS) -noinput +B \
	  -eval 'case make:all() of up_to_date -> halt(0); error -> halt(1) end.'
rabbitmq-server:
	@(cd deps/rabbitmq-server;$(MAKE))

rabbitmq-erlang-client:
	@(cd deps/rabbitmq-erlang-client;$(MAKE) BROKER_DIR=../rabbitmq-server)

effigy:
	@(cd deps/effigy;./bootstarp && ./configure && $(MAKE))

docs:
	@erl -noshell -run edoc_run application '$(APP)' '"."' '[]'

test: erl
	@support/bin/run_tests.escript ebin | tee test/test.log

clean:
	@echo "removing:"
	@rm -fv ebin/*.beam ebin/*.app

dialyzer: erl
	@dialyzer -Wno_match -Wno_return -c ebin/ | tee test/dialyzer.log

ebin/$(APP).app: src/$(APP).app.src
	@echo "generating ebin/gen_bunny.app"
	@bash support/bin/make_appfile.sh >ebin/gen_bunny.app
