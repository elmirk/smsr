map_user:	test_client.c
	gcc -o map_user test_client.c -I/opt/erlang/otp_src_21.1/lib/erl_interface/include -L/usr/local/lib/erlang/lib/erl_interface-3.10.4/lib -lerl_interface -lei -lpthread -Wall -Wextra
