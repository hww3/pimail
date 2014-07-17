constant FETCH_MSG = 1;
constant FETCH_FOLDER = 2;

mapping parse(object id)
{
  object c;

  if(!id->misc->session_variables)
    return Caudium.HTTP.string_answer("no session support present. unable to continue.");

  if(!id->misc->session_variables->imap)
  {
    c = client();
    id->misc->session_variables->imap = c;
  }
  else
  {
    c = id->misc->session_variables->imap;
  }

  id->do_not_disconnect = 1;

  if(id->variables->read)
    c->new_request(id, FETCH_MSG, id->variables->read);
  else
    c->new_request(id, FETCH_FOLDER, "INBOX");

  return Caudium.HTTP.pipe_in_progress();
}

class client
{
  mixed cid;
  int fetch_id;
  string fetch_content;
  int count;
  array seq = ({});
  array unread = ({});
  mapping msgs = ([]);
  object c;
  object id;
  string box;
  int box_selected;
  int server_ready; 

  static void create()
  {
    c = .IMAPclient.Client("server", 143, "user", "password", state, close, bye, ready);
  }

  void destroy()
  {
    if(id) id->misc->session_variables->imap = 0;
    id = 0;
    remove_call_out(cid);
  }

  void new_request(object _id, int type, mixed ... args)
  {
    if(id)
      throw(Error.Generic("Request already in flight.\n"));

    id = _id;
    cid = call_out(fetch_envelope, 45);

    fetch_id = 0;

    if(type == FETCH_MSG)
      fetch_id = msgs[args[0]];
    else if(type == FETCH_FOLDER)
      box = args[0];
 
    if(server_ready)
    {
      if(type == FETCH_FOLDER)
      {
        select_box(box);
      }
      else if(type == FETCH_MSG)
      {
        fetch_message(fetch_id);
      }
    }
  }

void state(string type, mixed ... args)
{
  if(type == "exists")
  {
    count = args[0];
    werror("count = %O\n", count);
  }
  if(type == "fetch" && args[0]->rfc822)
  {
    fetch_content = "<pre>" + args[0]->rfc822 + "</pre>";
  }
  else if(type == "fetch")
  {    
    if(seq && !args[0]->flags->seen)
     seq += ({(string)args[0]->msg_no});

    else if(!seq)
    {
      string email;
      string msg_no = 
        String.string2hex(Crypto.MD5()->update((string)random(1000000) 
        + (string)time())->update((string)args[0]->msg_no)->digest());
      if(!msgs)
        msgs = ([]);
      msgs[msg_no] = args[0]->msg_no;
      email = args[0]->envelope->sender[0][0] + " &lt;" + args[0]->envelope->sender[0][2] + "@" + args[0]->envelope->sender[0][3] + "&gt;";
      unread += ({sprintf("<tr><td>U</td><td>%s</td><td>%s <a href='/_up/imap.pike?read=%s'>%50s</a></td></tr>\n", 
                 args[0]->envelope->date, email, msg_no, args[0]->envelope->subject)});
    }
  }
}

void fetch_message(mixed fetch_id)
{
  if(fetch_id)
    c->fetch(fetch_id, "rfc822", fetch_envelope);

}
void close(mixed ... args)
{
  werror("close: %O\n", args);
  destruct(this);
}

void bye(mixed ... args)
{
  werror("bye: %O\n", args);
  destruct(this);
}

void ready(mixed yes)
{
  if(yes && box && !box_selected)
  {
    select_box(box);
    server_ready = 1;
  } 
  else if(yes)
    server_ready = 1;
}

void select_box(string box)
{
  seq = ({});
  c->select(box, selected);
}

void selected(mixed tag, mixed data)
{
   box_selected = 1;
  werror("selected!\n");
   if(fetch_id)
     c->fetch(fetch_id, "rfc822", fetch_envelope);
   else
     c->fetch("1:" + count, "flags", fetch_box);
}

void fetch_envelope(mixed ... args)
{
  remove_call_out(cid);
  string resp;
  if(!fetch_id) resp = "<table>" + (reverse(unread) * "") + "</table>";
  else resp = fetch_content;
  fetch_content = 0;
  fetch_id = 0;
  unread = ({});
  catch {
    id->my_fd->write("HTTP/1.0 200 OK\r\nContent-type: text/html\r\n"
      "Content-length: " + sizeof(resp) + "\r\n\r\n");
    id->do_not_disconnect = 0;
    id->file = ([]);
    id->my_fd->write(resp);
    id->do_log();
  };

  id = 0;
}

void fetch_box(mixed ... args)
{
  if(sizeof(seq))
  {
    c->fetch(seq*",", "envelope", fetch_envelope);
    seq = 0;
  }
}

void list(mixed ... args)
{
  werror("list: %O\n", args);
}

}

