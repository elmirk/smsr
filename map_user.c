/*
 * map_user.c
 *
 * this application is like a broker -
 * receive messages from gctload, transfer it to erlang
 * and send replies from erlang back to gctload
 *
 */

// ORDER types, orders send from erlang to c node
// according to orders C node send messages to gctload environment

//#include "map_user.h"

#define ORDER_MAP_DLG_OPEN_REQ  1//erlang decide that c node should establish outgoing dialouge with some node
#define ORDER_MAP_DLG_OPEN_RSP 0x81 //erland decide that c node should send DLG_OPEN_RSP
#define ORDER_MAPST_SND_RTSIM_REQ 2 //erlang decide that c node should send MAP_MSG_SRV_REQ

//#ifndef PROD
//#define MAP_MSG_SRV_REQ 0xc7e0
//#define MAP_MSG_SRV_IND 0x87e1
//#define MAP_MSG_DLG_REQ 0xc7e2
//#define MAP_MSG_DLG_IND 0x87e3
//#endif

#ifdef PROD
#define ERL_NODE "smsrouter@ubuntu"
#else
#define ERL_NODE "smsrouter@elmir-N56VZ"
#endif

#define ERL_COOKIE "hello"

//ORDER_MAP_SRV_SRISM_RSP //C node should send SRI_SM_ack to SMSC-GMSC
//ORDER_MAP_DLG_CLOSE_REQ //dialog close request

#include <stdio.h>
#include <string.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>

//Erlang interface
#include "erl_interface.h"
#include "ei.h"


//#include "sysgct.h"
//#include "msg.h"

//#ifdef PROD
#include "system.h"
#include "msg.h"
#include "sysgct.h"
#include "map_inc.h"
#include "map_user.h"
//#endif

int fd1[2];//File descriptor for creating a pipe
int fd2[2];//File descriptor for creating a pipe

#define BUFSIZE 1000
#define SELF(fd) erl_mk_pid(erl_thisnodename(),fd,0,erl_thiscreation())


#define ERROR_CREATE_THREAD -11
#define ERROR_JOIN_THREAD   -12
#define SUCCESS        0

#define MAPU_MODULE_ID        (0x2e)
//#define DEFAULT_MAP_ID           (MAP_TASK_ID)


u8 mapu_mod_id = MAPU_MODULE_ID;
//u8 map_mod_id = MAP_TASK_ID;
u8 map_mod_id = 0x15;


static u8 mapu_trace = 1;

//descriptor for erlang data send/receive
static int fd;
/* orders received from erlang node */

struct order {

  unsigned int msg_type;
  unsigned int primitive_type;
  int dlg_id;
  unsigned char payload_length;
  unsigned char payload[64];

} order;

/*
 * MTR_trace_msg
 *
 * Traces (prints) any message as hexadecimal to the console.
 *
 * Always returns zero.
 */
static int MAPU_disp_msg(char *prefix, MSG *m) {
  HDR   *h;              /* pointer to message header */
  int   instance;        /* instance of MAP msg received from */
  u16   mlen;            /* length of received message */
  u8    *pptr;           /* pointer to parameter area */

  /*
   * If tracing is disabled then return
   */
  if (mapu_trace == 0)
    return 0;

  h = (HDR*)m;
  instance = GCT_get_instance(h);
  printf("%s I%04x M t%04x i%04x f%02x d%02x s%02x", prefix, instance, h->type,
          h->id, h->src, h->dst, h->status);

  if ((mlen = m->len) > 0)
  {
    if (mlen > MAX_PARAM_LEN)
      mlen = MAX_PARAM_LEN;
    printf(" p");
    pptr = get_param(m);
    while (mlen--)
    {
      printf("%c%c", BIN2CH(*pptr/16), BIN2CH(*pptr%16));
      pptr++;
    }
  }
  printf("\n");
  return 0;
}

 
/**********************************************************************
*
* thread, where we receive messages from Erlang node
* received messages transferred to main
**********************************************************************/
void* erl_receiver(int *args) {
  ErlMessage emsg1;                         /* Incoming message */
  ETERM *fromp, *tuplep, *fnp, *argp, *resp;
  ETERM *msg_type = NULL;
  ETERM *primitive_type = NULL;
  ETERM *dlg_id = NULL;
  ETERM *payload = NULL;
  int got, result;
  unsigned char data;
  struct order order;
unsigned char buf[BUFSIZE];              /* Buffer for incoming message */
  
  
 while(1)
   {

     got = erl_receive_msg(*args, &buf[0], BUFSIZE, &emsg1);
     
     if (got == ERL_TICK) {
       printf("ERL_TICK received\n");
       /* ignore */
       data = 7;
       result = write (fd1[1], &data, 1);

       if (result != 1){
	 perror ("write");
	 exit (2);
       }
     }
     else if (emsg1.type == ERL_REG_SEND)
       {
	 printf("receive PAYLOAD from erlang\n");	 
	     msg_type = erl_element(1, emsg1.msg);
	     primitive_type = erl_element(2, emsg1.msg);
	     dlg_id = erl_element(3, emsg1.msg);
	     payload = erl_element(4, emsg1.msg);
	     //printf("pointer of dlg ind type = %p\n", dlg_ind_type);
	     //printf("decoded atom = %s/n", ERL_ATOM_PTR(dlg_ind_type));
	     //printf("is atom = %d\n", ERL_IS_ATOM(dlg_ind_type));
	     order.msg_type = ERL_INT_UVALUE(msg_type); 
	     //printf("msg type from erlang = %x\n", ERL_INT_UVALUE(msg_type));
	     //printf("dlg id from erlang = %d\n", ERL_INT_UVALUE(dlg_id));
	     order.dlg_id = ERL_INT_UVALUE(dlg_id);
	     //printf("number of bytes in bynary = %d\n", ERL_BIN_SIZE(payload));
	     order.payload_length = ERL_BIN_SIZE(payload);

	     memcpy(&order.payload[0], ERL_BIN_PTR(payload), order.payload_length), 
	     
	 result = write(fd1[1], &order, sizeof(struct order));
	 //	 if (result != 1){
	 //  perror("write");
	 //  exit(2);
	 //}
       }
   }
    return SUCCESS;
}
/**********************************************************************
*
* thread, where we receive messages from gctload environment
* received messages transferred to main
**********************************************************************/
void *gct_receiver(void *args) {

  //int     result;
  // char    ch='A';

  // while(1){
  // sleep(3);
  //   result = write (fd2[1], &ch,1);
  //   if (result != 1){
  //       perror ("write");
  //       exit (2);
  //   }
  //
  //   printf ("Writer: %c\n", ch);
  //   if(ch == 'Z')
  //     ch = 'A'-1;

  //   ch++;

  HDR *h;               /* received message */

  while (1)
    {
    /*
     * GCT_receive will attempt to receive messages
     * from the task's message queue and block until
     * a message is ready.
     */
      if ((h = GCT_receive(mapu_mod_id)) != 0)
	{
	  //printf("h received in gct_receiver pthread  = %p\n", h);
	  write(fd2[1], &h, 8);
	  //printf("after write to pipe!\n");
	}
    }

  return SUCCESS;
}

int MAPU_create_msg() {


}



int MAPU_send_msg(struct order *ptr) {

  MSG *m;
  u8 *pptr;
  u16 ptype = 0; /*parameter type */
/*
   * Allocate a message (MSG) to send:
   */
  
  if ((m = getm((u16)ptr->msg_type, ptr->dlg_id, NO_RESPONSE, (u16)(ptr->payload_length))) != 0)
  {
    m->hdr.src = mapu_mod_id;
    m->hdr.dst = map_mod_id;
  
    /*
     * Format the parameter area of the message
     *
     * Primitive type   = Open response
     * Parameter name   = result_tag
     * Parameter length = 1
     * Parameter value  = result
     * Parameter name   = applic_context_tag
     * parameter length = len
     * parameter data   = applic_context
     * EOC_tag
     */
    pptr = get_param(m);
       /*  pptr[0] = MAPDT_OPEN_RSP;
    pptr[1] = MAPPN_result;
    pptr[2] = 0x01;
    pptr[3] = result;
    pptr[4] = MAPPN_applic_context;
    pptr[5] = (u8)dlg_info->ac_len; */
    memcpy(pptr, &ptr->payload[0], ptr->payload_length);
    /*pptr[6+dlg_info->ac_len] = 0x00; */

    ptype = *pptr;
    /*
     * Now send the message
     */

  MAPU_disp_msg("MAPU Tx:", m);
  
  //printf("%s:\n",__PRETTY_FUNCTION__);

  //GCT_set_instance((unsigned int)instance, (HDR*)m);

  //MTR_trace_msg("MTR Tx:", m);

  /*
   * Now try to send the message, if we are successful then we do not need to
   * release the message.  If we are unsuccessful then we do need to release it.
   */

  //if (GCT_send(m->hdr.dst, (HDR *)m) != 0)
  //{
  // if (mtr_trace)
  //  fprintf(stderr, "*** failed to send message ***\n");
  // relm((HDR *)m);
  // }

  /* if message send then we need check should we send DELIMIT or MAP_CLOSE */

  }
  else
    printf("getm error!\n");

  
  return 0;
}

int mapu_erl_send(MSG *m)
{

  ETERM *erl_tuple_obj[3];
  ETERM *emsg;
  
  u16  ic_dlg_id = 0; 
  u8   *pptr;                   /* Parameter Pointer */
  u16  ptype = 0;               /* Parameter Type */

  ic_dlg_id = m->hdr.id;

  pptr = get_param(m);

  ptype = *pptr;

  
  //erl_tuple_obj[0] = erl_mk_atom("dlg_ind_open");
  erl_tuple_obj[1] = erl_mk_uint(ic_dlg_id);
  erl_tuple_obj[2] = erl_mk_binary( pptr, m->len);

  if  (m->hdr.type == MAP_MSG_DLG_IND)
    {
       //	      case MAP_MSG_DLG_IND:
       //	mapu_dlg_ind(m);
       //	break;
		
       //     case MAP_MSG_SRV_IND:
       //	mapu_srv_ind(m);
		//smsrouter_srv_ind(m);
       //	break;
       //     }
      switch (ptype)
	{
	case MAPDT_OPEN_IND:
	  erl_tuple_obj[0] = erl_mk_atom("dlg_ind_open");
	  break;
	case MAPDT_DELIMITER_IND:
	  erl_tuple_obj[0] = erl_mk_atom("delimit_ind");
	  break;
	case MAPDT_CLOSE_IND:
	  erl_tuple_obj[0] = erl_mk_atom("mapdt_close_ind");
	  break;
	case MAPDT_OPEN_CNF:
	  erl_tuple_obj[0] = erl_mk_atom("mapdt_open_cnf");
	  break;

	default:
	  break;
	}
    }
  else /*msg type = MAP_MSG_SRV_IND */
    {

      erl_tuple_obj[0] = erl_mk_atom("srv_ind");

    }

   emsg = erl_mk_tuple(erl_tuple_obj, 3);

  if (!erl_reg_send(fd, "broker", emsg))
printf("couldn't send msg to erlang!/n");
  else
    printf("send msg to erlang\n");

//Q1
// how to transfer message type - binary, integer or like atom
//first choice - use atoms
 
// id_tuple[2] = erl_mk_binary( (unsigned char *)&payload, sizeof(payload));

  

  return 0;
}

int mapu_srv_ind(MSG *m) {


  return 0;
}

/**********************************************************************
*
* main function
* like a dispatcher, receive messages from gctload/erlang and make decision
* send messages to gctload - in main
* send messages to erlang - in main
**********************************************************************/
int main() {
  ErlConnect conn;                         /* Connection data */
  int listen;
  int port = 6666;
  //emsg
  //int fd;
  unsigned char buf[BUFSIZE];              /* Buffer for incoming message */
  ErlMessage emsg1;                         /* Incoming message */

  struct order *p_order;  


  MSG *m;
  HDR *h;
 //u16  ic_dlg_id = 0; 

  int nbytes;
  
  erl_init(NULL, 0);


  int ret = erl_connect_init(1,ERL_COOKIE,0);


  if ((
     fd = erl_connect(ERL_NODE)
     ) < 0)
  //erl_err_quit("erl_connect");
  fprintf(stderr, "Error while connecting to erlang\n");  


  
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

/* this should be done in test build or something like test
 
 unsigned char payload[] ={0x02, 0x01, 0x0d, 0x13, 0x35, 0x37, 0x06, 0x00, 0x11, 0x04, 0x97, 0x05, 0x66, 0x15, 0x20, 0x09, 0x03, 0x0d, 0x13, 0x3c, 0x37, 0x08, 0x00, 0x11, 0x04, 0x97, 0x05, 0x66, 0x15, 0x10, 0x00, 0x0b, 0x09, 0x06, 0x07, 0x04, 0x00, 0x00, 0x01, 0x00, 0x14, 0x03, 0x00 };

 unsigned char payload_sri_sm[] = {0x02, 0x0e, 0x01, 0xb5, 0x0f, 0x07, 0x91, 0x97, 0x93, 0x93, 0x43, 0x81, 0xf3, 0x10, 0x01, 0x01, 0x11, 0x07, 0x91, 0x97, 0x05, 0x66, 0x15, 0x10, 0xf0, 0x00};

 unsigned char payload_delimit_ind[] = {0x06, 0x00};
 
*/
// unsigned char mtype[] = {2, 4 , 6 , 8};

 //arr[0] = SELF(sockfd);

 //printf(" mtype 0 pos = %d\n", (unsigned char) mtype);
 //printf(" mtype 1 pos = %d\n", * ((unsigned char *) &mtype + 1));
 ///printf("sizeof payload = %d\n", sizeof (payload));
 
 //return 0;

 /*
  * map_user will send {Msg_Type, DlgId, BinaryData} to erlang broker
  */

 /*
 dlg_ind_tuple[0] = erl_mk_atom("type");
dlg_ind_tuple[1] = erl_mk_atom("dlg_ind");

 int id = 32768;
 id_tuple[0]  = erl_mk_atom("dlg_ind_open");
 id_tuple[1]  =  erl_mk_uint(id);
 */
//Q1
// how to transfer message type - binary, integer or like atom
//first choice - use atoms
 
// id_tuple[2] = erl_mk_binary( (unsigned char *)&payload, sizeof(payload));
//emsg = erl_mk_binary( &payload[0], sizeof (payload) );
// emsg = erl_mk_tuple(id_tuple, 3);
// TBD - reciever should be changed on broker
//if (!erl_reg_send(fd, "broker", emsg))
//printf("couldn't send msg to erlang!/n");
//erl_free_term(emsg);


//test sending sri_sm to erlang
//id_tuple[0]  = erl_mk_atom("srv_ind");
// id_tuple[2] = erl_mk_binary( (unsigned char *)&payload_sri_sm[0], sizeof(payload_sri_sm));

// emsg = erl_mk_tuple(id_tuple, 3);
// if (!erl_reg_send(fd, "broker", emsg))
//printf("couldn't send msg to erlang!/n");
//erl_free_term(emsg);


//test sending delimit_ind to erlang
// id_tuple[0]  = erl_mk_atom("delimit_ind");
//id_tuple[2] = erl_mk_binary( (unsigned char *)&payload_delimit_ind[0], sizeof(payload_delimit_ind));


// emsg = erl_mk_tuple(id_tuple, 3);
// if (!erl_reg_send(fd, "broker", emsg))
//printf("couldn't send msg to erlang!/n");
//erl_free_term(emsg);


 
 int result1, result2;
 
result1 = pipe (fd1);
   if (result1 < 0){
       perror("pipe ");
       exit(1);
   }

   result2 = pipe (fd2);
   if (result2 < 0){
       perror("pipe ");
       exit(1);
   }

 
  pthread_t thread;
  pthread_t thread2;
    int status;
    int status_addr;
 
    status = pthread_create(&thread, NULL, erl_receiver, &fd);
    if (status != 0) {
        printf("main error: can't create thread, status = %d\n", status);
        exit(ERROR_CREATE_THREAD);
    }
status = pthread_create(&thread2, NULL, gct_receiver, NULL);
    if (status != 0) {
        printf("main error: can't create thread, status = %d\n", status);
        exit(ERROR_CREATE_THREAD);
    }

struct timeval tv;
    fd_set readfds;

    //tv.tv_sec = 20;
    //tv.tv_usec = 500000;

    //    FD_ZERO(&readfds);
    //FD_SET(fd1[0], &readfds);
    //FD_SET(fd2[0], &readfds);

    int maxfd;
    unsigned char buffer[512];

    maxfd = fd2[0] > fd1[0] ? fd2[0] : fd1[0];
    while (1)
      {
 tv.tv_sec = 20;
    tv.tv_usec = 500000;

    
    FD_ZERO(&readfds);
    FD_SET(fd1[0], &readfds);
    FD_SET(fd2[0], &readfds);

	
    // writefds и exceptfds нам не важны:
    select(maxfd+1, &readfds, NULL, NULL, &tv);

    if (FD_ISSET(fd1[0], &readfds)) /* received data from Erlang */
      {
	nbytes = read(fd1[0], buffer, sizeof (struct order));
	p_order = (struct order *) &buffer[0];
        printf("%s:rcv from erlang=%x\n", __PRETTY_FUNCTION__, p_order->msg_type);
	switch(p_order->msg_type)
	  {
	  case MAP_MSG_SRV_REQ:
	  case MAP_MSG_SRV_IND: 
	  case MAP_MSG_DLG_REQ:
	  case MAP_MSG_DLG_IND:
	    MAPU_send_msg(p_order);
	    break;
	  }
      }
    else if (FD_ISSET(fd2[0], &readfds)) /*receive data from gct env */
      {
	//printf("sizeof int = %d\n", sizeof(&h));
	nbytes = read(fd2[0], &h, 8);
	if (nbytes == -1)
	  {
	    perror("read:");
	    //printf("received in child h = %p\n", h);
	    exit(0);
	  }

	m = (MSG *)h;
	
	if (m != NULL)
	  {
	    MAPU_disp_msg("MAPU Rx from GCT:", m);

	    mapu_erl_send(m);
	    /*
	    switch (m->hdr.type)
	      {
	      case MAP_MSG_DLG_IND:
		mapu_dlg_ind(m);
		break;
		
	      case MAP_MSG_SRV_IND:
		mapu_srv_ind(m);
		//smsrouter_srv_ind(m);
		break;
	      }
	    */
	    
        /*
         * Once we have finished processing the message
         * it must be released to the pool of messages.
         */
        relm(h);
      }
	
	
	//printf("%s: fd2 received = %c\n", __PRETTY_FUNCTION__, buffer[0]);
      }
	else
        printf("Timed out.n");
    
      }

    //if (!erl_reg_send(fd, "broker", emsg))
    //printf("couldn't send msg to erlang!/n");


    //if (!erl_reg_send(fd, "broker", emsg))
    //printf("couldn't send msg to erlang!/n");
    

    //erl_free_term(emsg);


 status = pthread_join(thread, (void**)&status_addr);
    if (status != SUCCESS) {
        printf("main error: can't join thread, status = %d\n", status);
        exit(ERROR_JOIN_THREAD);
    }
 
//  while(1)
//  {

// got = erl_receive_msg(fd, buf, BUFSIZE, &emsg1);

// if (got == ERL_TICK) {
//    printf("ERL_TICK received\n");
      /* ignore */
//  }
      

//  }
    
  

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

/*
 * MAPU_send_msg sends a MSG to gct system. On failure the
 * message is released and the user notified.
 *
 * Always returns zero.
 *
 * TBD - analyze and uncomment!
 */
//static int MAPU_send_msg(instance, m)
//  u16   instance;       /* Destination instance */
//  MSG   *m;             /* MSG to send */
//{
//  GCT_set_instance((unsigned int)instance, (HDR*)m);
//
//  MTR_trace_msg("MTR Tx:", m);
//
//  /*
//   * Now try to send the message, if we are successful then we do not need// to
//   * release the message.  If we are unsuccessful then we do need to relea//se it.
//   */
//
//  if (GCT_send(m->hdr.dst, (HDR *)m) != 0)
//  {
//    if (mtr_trace)
//      fprintf(stderr, "*** failed to send message ***\n");
//    relm((HDR *)m);
//  }
//  return(0);
//}

