% -*- mode: erlang -*-
{application,
 gen_bunny,
 [{description,  "gen_bunny"},
  {vsn,          "0.1"},
  {modules,      [
                  bunnyc,
                  bunny_util,
                  gen_bunny
                 ]},
  {registered,   []},
  {mod,          {gen_bunny_app, []}},
  {env,          []},
  {applications, [kernel, stdlib, sasl, crypto]}]}.
