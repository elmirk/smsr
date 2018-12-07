
%%% message types to convey primitive data
-define(map_msg_srv_req, 16#c7e0).
-define(map_msg_srv_ind, 16#87e1).
-define(map_msg_dlg_req, 16#c7e2).
-define(map_msg_dlg_ind, 16#87e3).


%% dialogue primitive types

-define(mapdt_open_req, 1).
-define(mapdt_close_req, 3).
-define(mapdt_delimiter_req, 5).
-define(mapdt_u_abort_req, 7).
-define(mapdt_open_rsp, 129).


%% service primitive types

-define(mapst_snd_rtism_req, 1).


%% MAP Dialogue Primitive Parameters

-define(mappn_dest_address, 1). %%Destination address
-define(mappn_orig_address, 3). %%Originating address
-define(mappn_applic_context, 11). %%Application context name 
-define(mappn_result, 5). %% Result

%% MAP Service Primitive Parameters

-define(mappn_invoke_id, 14).
-define(mappn_msisdn, 15). %%MSISDN
-define(mappn_sm_rp_pri, 16). %%Short Message Delivery Priority
-define(mappn_sc_addr, 17). %%Short Message Service Centre Address

