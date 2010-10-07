REBAR:=./rebar

all: erl

erl:
	$(REBAR) get-deps compile

test: all
	$(REBAR) skip_deps=true eunit

clean:
	$(REBAR) clean
	-rm -rvf deps ebin

