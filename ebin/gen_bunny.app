% -*- mode: erlang -*-
{application,
 gen_bunny,
 [{description,  "gen_bunny"},
  {vsn,          "0.1"},
  {modules,      [
                  bunnyc,
                  bunny_util,
                  gen_bunny,
                  gen_bunny_mon,

                  %% Unit tests
                  test_gb,
                  bunny_util_tests,
                  gen_bunny_tests,
                  bunnyc_tests
                 ]},
  {registered,   []},
  {mod,          {gen_bunny_app, []}},
  {env,          []},
  {applications, [kernel, stdlib, sasl, crypto]}]}.
