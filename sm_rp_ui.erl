%%% @author root <root@elmir-N56VZ>
%%% @copyright (C) 2018, root
%%% @doc
%%%
%%% @end
%%% Created : 16 Dec 2018 by root <root@elmir-N56VZ>
%%%

%%--------------------------------------------------------------------
%%% 
%%% SMS-SUBMIT
%%%
%%--------------------------------------------------------------------
%% first octet(from LSB)
%% TP-MTI TP-Message-Type-Indicator M 2b Parameter describing the message type,
%%                                                01 for SMS-SUBMIT
%% TP-RD TP-Reject-Duplicates M b Parameter indicating whether or not the
%%                          SC shall accept an SMS-SUBMIT for an
%%                          SM still held in the SC which has the sam
%%                          TP-MR and the same TP-DA as a
%%                           previously submitted SM from the same OA 1
%%TP-VPF TP-Validity-Period-Format M 2b Parameter indicating whether or not the
%%                        TP-VP field is present. (10 - present, relative format)
%%TP-SRR TP-Status-Report-Request O b Parameter indicating if the MS is
%%requesting a status report.  In real SM-Submit is 1 if status report requested by ME
%%TP-UDHI TP-User-Data-Header-Indicator O b Parameter indicating that the TP-UD field
%%contains a Header
%%TP-RP TP-Reply-Path M b Parameter indicating the request for Reply
%%Path.
%%then following octets:


%%TP-MR TP-Message-Reference M 1 octet Parameter identifying the SMS-SUBMIT.
%%TP-DA TP-Destination-Address M 2-12o Address of the destination SME.
%%TP-PID TP-Protocol-Identifier M o Parameter identifying the above layer
%%protocol, if any.
%%TP-DCS TP-Data-Coding-Scheme M I Parameter identifying the coding scheme
%%within the TP-User-Data. Usually 8 for UCS2 coding scheme
%%TP-VP TP-Validity-Period O o/7o Parameter identifying the time from where
%%the message is no longer valid. 0xff enough?
%%TP-UDL TP-User-Data-Length M I Parameter indicating the length of the
%%TP-User-Data field to follow.
%%
%%
%%--------------------------------------------------------------------
%%% 
%%% SMS-DELIVER
%%%
%%--------------------------------------------------------------------
%% 
%% example of coded data 
%% 24 0b919720171182f7 0008 81901200532321 080422043504410442

%%24hex = 0010 0100
%%TP-MTI TP-Message-Type-Indicator M 2b Parameter describing the message
%%type. 00 - SMS-DELIVER
%%TP-MMS TP-More-Messages-to-Send M b Parameter indicating whether or
%%not there are more messages to send, 1 - no more message in SMSC
%%TP-LP 1 bit, = 0

%%TP-SRI TP-Status-Report-Indication O b(bit5) Parameter indicating if the SME
%%has requested a status report.1 = status report shall returned to the SME
%%TP-UDHI TP-User-Data-Header-Indicator O b Parameter indicating that the
%%                                       TP-UD field contains a Header
%%=0, no header, SM only in UD
%%TP-RP TP-Reply-Path M b Parameter indicating that Reply
%%Path exists.Reply Path  = 0, is not set

%%0b919720171182f7 - Originating Address
%%TP-PID = 00
%%TP-DCS = 08
%%TP-SCTS TP-Service-Centre-Time-Stamp M 7o Parameter identifying time when
%%the SC received the message.
%%TP-UDL TP-User-Data-Length M I Parameter indicating the length of
%%the TP-User-Data field to follow.
%%TP-UD TP-User-Data O  Depend on the TP-DCS
 

-module(sm_rp_ui).

-export([get_oa/1,
	test/0]).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------


get_oa(Data)->
    <<MTI:8, OAlength:8, OAtype:8, Rest/binary>> = Data,
    case OAtype of
	16#91 ->
	    decode_numeric_oa(OAlength, Rest);
	Other -> decode_oa_carefully(Other, OAlength, Rest)
    end.

%% even number of address digits
decode_numeric_oa(Length, Data) when (( Length band 1) == 0)->
    OAnum_bytes = Length div 2,
    << OA:OAnum_bytes, _Rest/binary >> = Data,  
    OA;
%% odd numbers of addres digits(ex. 0x0b)
decode_numeric_oa(Length, Data) ->
    OAnum_bytes = (Length+1) div 2,
%%    io:format("num bytes = ~p~n", [OAnum_bytes]),
    << OA:OAnum_bytes/binary, _Rest/binary >> = Data,  
    OA.

decode_oa_carefully(_Type,_Length,_Rest)->
    ok.
 

even(X) when X >= 0 -> (X band 1) == 0.
odd(X) when X > 0 -> not even(X).


test()->
    Data = << 16#24, 16#0b, 16#91, 16#97, 16#20, 16#17, 16#11, 16#82, 16#f7, 16#00,
	      16#08, 16#81, 16#90, 16#12, 16#00, 16#53, 16#23, 16#21, 16#08, 
	      16#04, 16#22, 16#04, 16#35, 16#04, 16#41, 16#04, 16#42 >>,
    << 16#97, 16#20, 16#17, 16#11, 16#82, 16#f7 >> = get_oa(Data),
    ok.
