#!/bin/sh

VERSION="2_1_0"

BASE_URL="http://hg.rabbitmq.com/"

GIT_BASE_URL="http://github.com/dreid/"

DEPS="amqp_client rabbit_common"

mkdir -p build_tmp
pushd build_tmp

for project in rabbitmq-erlang-client rabbitmq-server rabbitmq-codegen; do
    hg clone -r rabbitmq_v${VERSION} ${BASE_URL}${project};
done

pushd rabbitmq-erlang-client
make
popd

stamp=$(date "+%Y_%m_%dT%H_%M_%S");

for dep in ${DEPS}; do
    git clone ${GIT_BASE_URL}${dep}.git;
    pushd ${dep};
    rm src/*
    rm include/*
    popd;
done

pushd rabbitmq-erlang-client/
cp -v src/* ../amqp_client/src/
cp -v include/* ../amqp_client/include/

common_deps=$(erl -noshell -eval '{ok,[{_,_,[_,_,{modules, Mods},_,_,_]}]} =
                                      file:consult("rabbit_common.app"),
                                      [io:format("~p ",[M]) || M <- Mods],
                                      halt().')
popd

pushd rabbitmq-server

for mod in ${common_deps}; do
    cp -v src/${mod}.erl ../rabbit_common/src/;
done

cp -v include/* ../rabbit_common/include;

popd

cp -v rabbitmq-erlang-client/rabbit_common.app \
   rabbit_common/src/rabbit_common.app.src

cp -v rabbitmq-erlang-client/dist/amqp_client/ebin/amqp_client.app \
   amqp_client/src/amqp_client.app.src
