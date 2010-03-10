ERL          ?= erl
EBIN_DIRS    := deps/effigy/ebin deps/rabbitmq-erlang-client/dist/*/ebin
APP          := gen_bunny

all: rabbitmq-server rabbitmq-erlang-client effigy erl

erl: ebin/$(APP).app src/$(APP).app.src
	@$(ERL) -pa ebin -pa $(EBIN_DIRS) -noinput +B \
	  -eval 'case make:all() of up_to_date -> halt(0); error -> halt(1) end.'

deps/effigy:
	hg clone http://bitbucket.org/dreid/effigy/ deps/effigy

deps/rabbitmq-server: 
	hg clone -r rabbitmq_v1_7_2 http://hg.rabbitmq.com/rabbitmq-server deps/rabbitmq-server

deps/rabbitmq-codegen: 
	hg clone -r rabbitmq_v1_7_2 http://hg.rabbitmq.com/rabbitmq-codegen deps/rabbitmq-codegen

deps/rabbitmq-erlang-client:
	hg clone -r rabbitmq_v1_7_0 http://hg.rabbitmq.com/rabbitmq-erlang-client deps/rabbitmq-erlang-client

rabbitmq-server: deps/rabbitmq-codegen deps/rabbitmq-server
	@(cd deps/rabbitmq-server;PYTHONPATH="deps/rabbitmq-codegen/" $(MAKE))

rabbitmq-erlang-client: deps/rabbitmq-erlang-client
	@(cd deps/rabbitmq-erlang-client;$(MAKE) BROKER_DIR=../rabbitmq-server)

effigy: deps/effigy
	@(cd deps/effigy;./rebar compile)

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
