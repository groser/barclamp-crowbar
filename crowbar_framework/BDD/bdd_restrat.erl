% Copyright 2012, Dell 
% 
% Licensed under the Apache License, Version 2.0 (the "License"); 
% you may not use this file except in compliance with the License. 
% You may obtain a copy of the License at 
% 
%  eurl://www.apache.org/licenses/LICENSE-2.0 
% 
% Unless required by applicable law or agreed to in writing, software 
% distributed under the License is distributed on an "AS IS" BASIS, 
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
% See the License for the specific language governing permissions and 
% limitations under the License. 
% 
-module(bdd_restrat).
-export([step/3]).

% ASSUME, only 1 ajax result per feature
get_JSON(Results) ->
  {ajax, JSON, _} = lists:keyfind(ajax, 1, Results),  
  JSON.   

step(Config, _Given, {step_when, _N, ["REST requests the",Page,"page"]}) ->
  JSON = eurl:get(Config, Page),
  {ajax, json:parse(JSON), Page};

step(Config, _Given, {step_when, _N, ["REST gets the",Object,"list"]}) -> 
  % This relies on the pattern objects providing a g(path) value mapping to their root information
  URI = apply(Object, g, [path]),
  bdd_utils:log(Config, trace, "REST get ~p path", [URI]),
  case eurl:get_page(Config, URI, [{404, not_found}, {500, error}]) of
    not_found -> bdd_utils:log(Config, info, "bdd_restrat list not found at ~p.", [URI]), {ajax, not_found, URI};
    error -> bdd_utils:log(Config, info, "bdd_restrat list 500 return at ~p.", [URI]), {ajax, error, URI};
    JSON -> {ajax, json:parse(JSON), URI}
  end;
  
step(Config, _Given, {step_when, _N, ["REST gets the",Object,Key]}) ->
  % This relies on the pattern objects providing a g(path) value mapping to their root information
  URI = eurl:path(apply(Object, g, [path]), Key),
  case eurl:get_page(Config, URI, [{404, not_found}, {500, error}]) of
    not_found -> bdd_utils:log(Config, info, "bdd_restrat object not found at ~p.", [URI]), {ajax, not_found, URI};
    error -> bdd_utils:log(Config, info, "bdd_restrat object 500 return at ~p.", [URI]), {ajax, error, URI};
    JSON -> {ajax, json:parse(JSON), URI}
  end;

step(Config, Results, {step_then, _N, ["the", Object, "is properly formatted"]}) ->
  {ajax, JSON, URI} = lists:keyfind(ajax, 1, Results),     % ASSUME, only 1 ajax result per feature
  % This relies on the pattern objects providing a g(path) value mapping to their root information
  case JSON of 
    not_found -> bdd_utils:log(Config, warn, "RestRAT: Object ~p not found at ~p", [Object, URI]), false;
    error -> bdd_utils:log(Config, error, "RestRAT: Object ~p threw error at ~p", [Object, URI]), false;
    J -> apply(Object, validate, [J])
  end;
    
step(Config, Results, {step_then, _N, ["there should be a key",Key]}) -> 
  {ajax, JSON, _} = lists:keyfind(ajax, 1, Results),     % ASSUME, only 1 ajax result per feature
  bdd_utils:log(Config, trace, "JSON list ~p should have ~p~n", [JSON, Key]),
  length([K || {K, _} <- JSON, K == Key])==1;
                                                                
step(_Config, Results, {step_then,_N, ["key",Key,"should be",Value]}) ->
  Value =:= json:value(get_JSON(Results), Key);

step(_Config, Results, {step_then, _N, ["key",Key, "should contain",Count,"items"]}) -> 
  {C, _} = string:to_integer(Count),
  List = json:value(get_JSON(Results), Key),
  Items = length(List),
  Items =:= C;
                                                                
step(_Config, Results, {step_then, _N, ["key",Key,"should contain at least",Count,"items"]}) ->
  {C, _} = string:to_integer(Count),
  List = json:value(get_JSON(Results), Key),
  Items = length(List),
  Items >= C;

step(_Config, Results, {step_then, _N, ["key",Key,"should be a number"]}) -> 
  bdd_utils:is_a(number, json:value(get_JSON(Results), Key));
                                                       
step(_Config, Results, {step_then, _N, ["key",Key, "should be an empty string"]}) -> 
  bdd_utils:is_a(empty, json:value(get_JSON(Results), Key));
                                                      
step(_Config, Result, {step_then, _N, ["there should be a value",Value]}) -> 
  Test = lists:keyfind(Value,2,get_JSON(Result)),
  Test =/= false;
          
step(_Config, _Result, {_Type, _N, ["END OF RESTRAT"]}) ->
  false.
