
#include <stdio.h>
#include <string.h>

#include "erl_interface.h"

#define BUFSIZE 1000
#define SELF(fd) erl_mk_pid(erl_thisnodename(),fd,0,erl_thiscreation())


int main() {


    ErlConnect conn;                         /* Connection data */
  int listen;
  int port = 6666;
  //emsg
  int fd;
unsigned char buf[BUFSIZE];              /* Buffer for incoming message */
 ErlMessage emsg1;                         /* Incoming message */

  
  printf("hello!\n");


  erl_init(NULL, 0);


  int ret = erl_connect_init(1,"hello",0);


  if ((
     fd = erl_connect("smsrouter@elmir-N56VZ")
     ) < 0)
  //erl_err_quit("erl_connect");
  fprintf(stderr, "Connected to smsrouter@ubuntu\n\r");  


  
  /* Make a listen socket */
  /* if ((listen = my_listen(port)) <= 0) */
  /*   erl_err_quit("my_listen"); */


  /* if (erl_publish(port) == -1) */
  /*   erl_err_quit("erl_publish"); */

  /* if ((fd = erl_accept(listen, &conn)) == ERL_ERROR) */
  /*   erl_err_quit("erl_accept"); */
  /* fprintf(stderr, "Connected to %s\n\r", conn.nodename); */
  int got;
ETERM *fromp, *tuplep, *fnp, *argp, *resp;

//#define SELF(fd) erl_mk_pid(erl_thisnodename(),fd,0,erl_thiscreation())
ETERM *dlg_ind_tuple[2], *emsg;
ETERM *id_tuple[3];
 
int sockfd, creation=1;
//unsigned short  mtype = 0xaabb;



//13353706001104970566152009030d133c37080011049705661510000b0906070400000100140300

//example of MAP_MSG_DLG_IND (0x87e3)
//received by smsrouter
// p02010d13353706001104970566152009030d133c37080011049705661510000b0906070400000100140300

 unsigned char payload[] ={0x02, 0x01, 0x0d, 0x13, 0x35, 0x37, 0x06, 0x00, 0x11, 0x04, 0x97, 0x05, 0x66, 0x15, 0x20, 0x09, 0x03, 0x0d, 0x13, 0x3c, 0x37, 0x08, 0x00, 0x11, 0x04, 0x97, 0x05, 0x66, 0x15, 0x10, 0x00, 0x0b, 0x09, 0x06, 0x07, 0x04, 0x00, 0x00, 0x01, 0x00, 0x14, 0x03, 0x00 };

 
 unsigned char mtype[] = {2, 4 , 6 , 8};

 //arr[0] = SELF(sockfd);

 printf(" mtype 0 pos = %d\n", (unsigned char) mtype);
 printf(" mtype 1 pos = %d\n", * ((unsigned char *) &mtype + 1));
 printf("sizeof payload = %d\n", sizeof (payload));
 
 //return 0;
 
dlg_ind_tuple[0] = erl_mk_atom("type");
// arr[1] = erl_mk_atom("map_msg_dlg_ind");
dlg_ind_tuple[1] = erl_mk_atom("dlg_ind");

 int id = 64700;
 id_tuple[0]  = erl_mk_atom("dlg_ind_open");
 id_tuple[1]  =  erl_mk_uint(id);
 
//Q1
// how to transfer message type - binary, integer or like atom
//first choice - use atoms
 
 id_tuple[2] = erl_mk_binary( (unsigned char *)&payload, sizeof(payload));
//emsg = erl_mk_binary( &payload[0], sizeof (payload) );
 emsg = erl_mk_tuple(id_tuple, 3);
// TBD - reciever should be changed on broker
if (!erl_reg_send(fd, "broker", emsg))
printf("couldn't send msg to erlang!/n");
erl_free_term(emsg);
 

  
  while(1)
    {
 got = erl_receive_msg(fd, buf, BUFSIZE, &emsg1);

 if (got == ERL_TICK) {
      printf("ERL_TICK received\n");
      /* ignore */
    }
      

    }
    
  

  printf("ret = %d\n", ret);
return 0;
}


  
int my_listen(int port) {
  int listen_fd;
  struct sockaddr_in addr;
  int on = 1;

  if ((listen_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    return (-1);

  setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));

  memset((void*) &addr, 0, (size_t) sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);

  if (bind(listen_fd, (struct sockaddr*) &addr, sizeof(addr)) < 0)
    return (-1);

  listen(listen_fd, 5);
  return listen_fd;
}
