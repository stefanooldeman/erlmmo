%% @author author <author@example.com>
%% @copyright YYYY author.
%% @doc Example webmachine_resource.

%%
% This resource provides the following urls:
% POST /v1/chat     message=MyTextBlaBlub&channel=Global    Post a message to the other sessions
%%
-module(resource_chat).
-export([init/1, malformed_request/2, resource_exists/2, service_available/2, allowed_methods/2, process_post/2]).

-include_lib("webmachine/include/webmachine.hrl").

-record(state, {sessionkey, session, message, channel}).

init([]) ->
    {ok,
        #state{}
    }.
    
% Make sure that the session_master is available
service_available(ReqData, State) ->
    Status = case global:whereis_name(session_master) of
        undefined -> false;
        _ -> true
    end,
    {Status, ReqData, State}.

   
allowed_methods(ReqData, State) ->
    {['POST'], ReqData, State}.
    

%%
% Checks that all parameters are given for the POST request
malformed_request(ReqData, State) ->
    SessionKey = case wrq:path_info(sessionkey, ReqData) of
        undefined -> wrq:get_qs_value("apikey", ReqData);
        A -> mochiweb_util:unquote(A)
    end,
    
    case SessionKey of
        undefined -> {true, ReqData, State};
        _ -> 
            Message = wrq:get_qs_value("message", ReqData),
            Channel = wrq:get_qs_value("channel", ReqData),
            
            case [Message, Channel] of
                [undefined,_] -> {true, ReqData, State};
                [_,undefined] -> {true, ReqData, State};
                _ ->             {false, ReqData, State#state{sessionkey=SessionKey,message=list_to_binary(Message),channel=list_to_binary(Channel)}}
            end
    end.
       
resource_exists(ReqData, State = #state{sessionkey=Sessionkey}) ->
    case session_master:find(Sessionkey) of
        {error, no_session} -> {false, ReqData, State};
        {ok, Session} ->
            {true, ReqData, State#state{session=Session}}
    end.
    


% Lets do the real work
% get the parameters
% and process them through the session_master
process_post(ReqData, State = #state{session=Session, message=Message, channel=Channel}) ->
    ok = Session:chat_send(Channel, Message),
    NewReqData = wrq:set_resp_body(mochijson2:encode(<<"OK">>), ReqData),
    {true, NewReqData, State}.
