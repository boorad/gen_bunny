ERL          ?= erl
EBIN_DIRS    := deps/effigy/ebin deps/rabbitmq-erlang-client/dist/*/ebin
APP          := gen_bunny
REBAR	     := ./rebar

all: rabbitmq-server rabbitmq-erlang-client erl

erl:
	@$(REBAR) compile

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

test: all
	@$(REBAR) eunit

clean:
	@echo "removing:"
	@$(REBAR) clean
	(cd deps/rabbitmq-server;$(MAKE) clean)
	(cd deps/rabbitmq-erlang-client;$(MAKE) clean)

distclean:
	$(REBAR) distclean
	@rm -rvf deps/*

dialyzer: erl
	@dialyzer -Wno_match -Wno_return -c ebin/ | tee test/dialyzer.log
