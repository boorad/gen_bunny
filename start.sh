#!/usr/bin/env bash

export MNESIA_BASE=priv/rabbit-mnesia
export LOG_BASE=priv/log/rabbit
export SERVER_ERL_ARGS="+K true +A30 \
-kernel inet_default_listen_options [{nodelay,true},{sndbuf,16384},{recbuf,4096}] \
-kernel inet_default_connect_options [{nodelay,true}]"
RABBITMQ_NODE_IP_ADDRESS=$1
RABBITMQ_NODE_PORT=5672

[ "x" = "x$RABBITMQ_NODENAME" ] && RABBITMQ_NODENAME=${NODENAME}
[ "x" = "x$RABBITMQ_NODE_IP_ADDRESS" ] && RABBITMQ_NODE_IP_ADDRESS=${NODE_IP_ADDRESS}
[ "x" = "x$RABBITMQ_NODE_PORT" ] && RABBITMQ_NODE_PORT=${NODE_PORT}
[ "x" = "x$RABBITMQ_SERVER_ERL_ARGS" ] && RABBITMQ_SERVER_ERL_ARGS=${SERVER_ERL_ARGS}
[ "x" = "x$RABBITMQ_CLUSTER_CONFIG_FILE" ] && RABBITMQ_CLUSTER_CONFIG_FILE=${CLUSTER_CONFIG_FILE}
[ "x" = "x$RABBITMQ_LOG_BASE" ] && RABBITMQ_LOG_BASE=${LOG_BASE}
[ "x" = "x$RABBITMQ_MNESIA_BASE" ] && RABBITMQ_MNESIA_BASE=${MNESIA_BASE}
[ "x" = "x$RABBITMQ_SERVER_START_ARGS" ] && RABBITMQ_SERVER_START_ARGS=${SERVER_START_ARGS}

[ "x" = "x$RABBITMQ_MNESIA_DIR" ] && RABBITMQ_MNESIA_DIR=${MNESIA_DIR}
[ "x" = "x$RABBITMQ_MNESIA_DIR" ] && RABBITMQ_MNESIA_DIR=${RABBITMQ_MNESIA_BASE}/${RABBITMQ_NODENAME}

## Log rotation
[ "x" = "x$RABBITMQ_LOGS" ] && RABBITMQ_LOGS=${LOGS}
[ "x" = "x$RABBITMQ_LOGS" ] && RABBITMQ_LOGS="${RABBITMQ_LOG_BASE}/${RABBITMQ_NODENAME}.log"
[ "x" = "x$RABBITMQ_SASL_LOGS" ] && RABBITMQ_SASL_LOGS=${SASL_LOGS}
[ "x" = "x$RABBITMQ_SASL_LOGS" ] && RABBITMQ_SASL_LOGS="${RABBITMQ_LOG_BASE}/${RABBITMQ_NODENAME}-sasl.log"
[ "x" = "x$RABBITMQ_BACKUP_EXTENSION" ] && RABBITMQ_BACKUP_EXTENSION=${BACKUP_EXTENSION}
[ "x" = "x$RABBITMQ_BACKUP_EXTENSION" ] && RABBITMQ_BACKUP_EXTENSION=".1"

[ -f  "${RABBITMQ_LOGS}" ] && cat "${RABBITMQ_LOGS}" >> "${RABBITMQ_LOGS}${RABBITMQ_BACKUP_EXTENSION}"
[ -f  "${RABBITMQ_SASL_LOGS}" ] && cat "${RABBITMQ_SASL_LOGS}" >> "${RABBITMQ_SASL_LOGS}${RABBITMQ_BACKUP_EXTENSION}"

exec erl \
    -pa ebin \
    -pa deps/*/ebin \
    -s rabbit \
    -name rmq@$1 \
    -boot start_sasl \
    -mnesia dir "\"${RABBITMQ_MNESIA_DIR}\"" \ 
    +W w \
    ${SERVER_ERL_ARGS} \
    -rabbit tcp_listeners '[{"'${RABBITMQ_NODE_IP_ADDRESS}'", '${RABBITMQ_NODE_PORT}'}]' \
    -sasl errlog_type error \
    -kernel error_logger '{file,"'${RABBITMQ_LOGS}'"}' \
    -sasl sasl_error_logger '{file,"'${RABBITMQ_SASL_LOGS}'"}' \    
    -os_mon start_cpu_sup true \
    -os_mon start_disksup false \
    -os_mon start_memsup false \
    -os_mon start_os_sup false \
    -os_mon memsup_system_only true \
    -os_mon system_memory_high_watermark 0.95 \
