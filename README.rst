gen_bunny
---------

gen_bunny is a RabbitMQ_ client library for erlang whose primary goal is to be
easy to use.  Especially for simple publisher and consumer applications.


Getting the code
================

One of gen_bunny's goals is to make it as easy to get all the required code
build it, and start using it as possible.  To achieve this goal we've used
rebar_ for dependency management, as our build tool, and as our test runner.

To get a local copy of gen_bunny only the following steps are needed.

::

  git clone http://github.com/dreid/gen_bunny.git
  cd gen_bunny
  make
  make test


Using rebar
===========

Using rebar_ for dependency management means that gen_bunny can also be used as
a rebar_ dependency.  This is the preferred way to get gen_bunny into your
application, and in fact at this time the only supported way.

To depend on gen_bunny in your application simply add the following line to
your project's ``rebar.config`` file.

::

  {deps, [{gen_bunny, ".*",
           {git, "http://github.com/dreid/gen_bunny.git", ""}}]}.



After that simply using ``rebar get-deps compile`` will fetch the necessary
amqp_client and rabbit_common dependencies and build them along with gen_bunny.

.. _RabbitMQ: http://rabbitmq.com/
.. _rebar: http://hg.basho.com/rebar/wiki/Home
