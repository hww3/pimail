/*
    IMAP.pmod - IMAP client module for Pike 
     
    Copyright (C) 1999 Mikael Brandström
    Copyright (C) 2005-2014 Bill Welliver

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


    If you like this piece of software, you are welcome to send me a
    postcard to the adress below.

    The author may be reached via email at mikael@unix.pp.se or
    Mikael Brandström
    Lindsbergsg. 7B
    S-752 40 UPPSALA
    SWEDEN
*/

string cvs_version="$Id: IMAPclient2.pmod,v 1.4 2003/03/19 12:00:03 kiwi Exp $";
string ver_string="IMAP.pmod $Revision: 1.4 $";


//#define IMAP_PARSER_DEBUG
//#define IMAP_IMAPIO_DEBUG
//#define IMAP_TIME
//#define IMAP_CLIENT_DEBUG

#ifdef IMAP_PARSER_DEBUG
#define _IM_P_DEBUG(X) Stdio.stderr->write("ImapP: " + ( X )[..70] + "(" + sizeof(X) + ")\n")
#else
#define _IM_P_DEBUG(X) /* X */
#endif

#ifdef IMAP_IMAPIO_DEBUG
#define _IM_IO_DEBUG(X) Stdio.stderr->write("ImapIO: " + X + "\n")
#else
#define _IM_IO_DEBUG(X) /* X */
#endif

#ifdef IMAP_CLIENT_DEBUG
#define _IM_C_DEBUG(X) Stdio.stderr->write("ImapC: " + X + "\n")
#else
#define _IM_C_DEBUG(X) /* X */
#endif

#define THROW(X) throw(({X,backtrace()}))

#define HAPPYEND ((sizeof(u)&&(u==" "||u==")"||u=="]"||u=="\r"||u=="\n"))||((in->left()-n)==0&&!f))

/***************************************************************************
   MACRO:
   In(X,Y) 
   DESCRIPTION
   is true if X is in Y
*/
#define CRLF (< "\r", "\n" >)
#define DIGIT (< "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" >)
#define DQUOTE (< "\"" >)
#define SP (< " " >)
#define LIST_WILDCARDS (< "%", "*" >)
#define QUOTED_SPECIALS DQUOTE + (< "\\" >)
#define CTL (<"\0","\1","\2","\3","\4","\5","\6","\7","\b","\t","\13","\14","\16","\17","\20","\21","\22","\23","\24","\25","\26","\27","\30","\31","\32","\33","\34","\35","\36","\37" >)
// Genrated with: lambda(){array ret=({ }); int i; for(i=0;i<=31;i++) ret += ({ sprintf("%c",i) }); ret -= ({ "\n" }); ret -= ({ "\r" }); return ret; }()
#define ATOM_SPECIALS (< "(", ")", "{", "[", "]" >) + SP + LIST_WILDCARDS + QUOTED_SPECIALS + CTL + CRLF
#define EIGHTBIT  (<"\177","\200","\201","\202","\203","\204","\205","\206","\207","\210","\211","\212","\213","\214","\215","\216","\217","\220","\221","\222","\223","\224","\225","\226","\227","\230","\231","\232","\233","\234","\235","\236","\237","\240","\241","\242","\243","\244","\245","\246","\247","\250","\251","\252","\253","\254","\255","\256","\257","\260","\261","\262","\263","\264","\265","\266","\267","\270","\271","\272","\273","\274","\275","\276","\277","\300","\301","\302","\303","\304","\305","\306","\307","\310""\311","\312","\313","\314","\315","\316","\317","\320","\321","\322","\323","\324","\325","\326","\327","\330","\331","\332","\333","\334","\335","\336","\337","\340","\341","\342","\343","\344","\345","\346","\347","\350","\351","\352","\353","\354","\355","\356","\357","\360","\361","\362","\363","\364","\365","\366","\367","\370","\371","\372","\373","\374","\375","\376","\377" >)
// Generated with: lambda(){array ret=({ }); int i; for(i=127;i<=255;i++) ret += ({ sprintf("%c",i) }); return ret; }()


// "[" and "]" are actually not members of atom-specials, but, making them
// members makes the parsing easier.
// int querty=0
/*
int In(string s, array what){
  string t;
  if(search(what,s)==-1) return 0;
  else return 1;
//  write(s + " " + ++qwerty + " " + tid + "\n");
  return 0;
}
*/
#define In(X,Y) ((Y)[X])

/***************************************************************************
   CLASS
   my_string(string in)
   DESCRIPTION
   my_string: a class to make it easier to process a string. Makes a string 
   behave like som kind of stream. The string is read-only.
   Provided methods are:
   void create(string s) initiate the instance with the contents in s
   string peek(void|int n,void|int o) like peek on any stream, an optional 
                           first argument tells how far to peek, an optional
			   second argument tells offset from beginning to look.
   string eat(int n) remove n characters from the front of the string
   string get(void|int n) return and remove the first or n first characters
   int left() returns how many characters which are available
*/

static class my_string {
  private string b;
  private int p;
  private int l;

  void create(string in){
    _IM_P_DEBUG("my_string created: "+in);
    b=in;
    p=0;
    l=sizeof(b);
  }

  void destroy(){
    _IM_P_DEBUG("my_string destroyed: "+(string)left()+" charachters were "
                "not used");
  }

  string peek(void|int n,void|int o) {
    if(n<0||o<0)
      THROW("argument out of range\n");
    if(p<0)
      return "";
    o=p+o;
    int m=l-o;
    if(n==0)
      n=1;
    if(n>m)
      n=m;
    return b[o..o+n-1];
  }

  void eat(int n) {
    if(n<0)
      THROW("argument out of range\n");
    if(p<0)
      return;
    if(p+n<l)
      p+=n;
    else
      p=-1;
  }

  void uneat(int n){
    if(n<0)
      THROW("argument out of range\n");
    if(p<0)
      p=l-n;
    else
      if(p-n<0)
        p=0;
      else
        p-=n;
  }

  string peekto(string to, void|int n){
    if(!to)
      return 0;
    if(p<0)
      return 0;
    string s=b[p..];
    if(n==0){
      int m=search(s,to);
      if(m==-1)
        return 0;
      else
        return s[..m-1];
    }else{
      array t=(s/to);
      if(sizeof(t)>1)
        return t[n];
      else
        return 0;

    }

  }

  string get(void|int n) {
    string r=peek(n);
    if(n==0) n=1;
    eat(n);
    return r;
  }

  string cast(string to){
    if(to!="string")
      THROW("unable to cast my_string to " + to + "\n");
    if(p<0)
      return "";
    return b[p..];
  }

  string all() {
    return b;
  }

  void reset() {
    p=0;
  }

  int left() {
    if(p<0)
      return 0;
    return l - p;
  }

};


/***************************************************************************
  CLASS(es)
  DataItem, Atom, Number, String, ParenList, Flag, ReturnCode, Text
  DESCRIPTION
  These classes are used to represent a reply from the IMAP-server.
*/

static class DataItem {
  int Nilp()         { return 0; }
  int Atomp()        { return 0; }
  int Numberp()      { return 0; }
  int Stringp()      { return 0; }
  int Flagp()        { return 0; }
  int ParenListp()   { return 0; }
  int ReturnCodep()  { return 0; }
  int TextP()        { return 0; }
  string Type() { return "DataItem"; }
  mixed data;

  void create(object(my_string) in){
    THROW("This object cannot be created\n");
  }

  /*
     This is the main parser, used by all classes which inherit this class.
     It is a recursive parser which parses until it reaches the end of
     the supplied data. Data, which actually is a string, must be supplied
     as an object of type my_string
  */
  array parse(object(my_string) in, void|string end) {
    array res=0;
    object reg;

    while(1){
      object n;
#ifdef IMAP_PARSER_DEBUG
      _IM_P_DEBUG(sprintf("Parse: trying to parse:%O",(string)in));
#endif
      if(end)
        _IM_P_DEBUG(sprintf("Parse: end is %O",end));

      if(in->left()==0){
        _IM_P_DEBUG("End of string");
        return res;
      }
      string peek=in->peek();
      if(peek==end)
        return res;

      if(peek=="\n"||peek=="\r"){
        _IM_P_DEBUG("End of line");
        return res;
      }

      switch(peek){
      case "(":
        if(n=ParenList(in)){
          _IM_P_DEBUG("Parenthesized list found");
        }
        break;
      case "[":
        if(n=ReturnCode(in)){
          _IM_P_DEBUG("Return code found");
        }
        break;
      case "\\":
        if(n=Flag(in)){
          _IM_P_DEBUG("Flag found:" + n->GetContents());
        }
        break;
      case "\"":
        {
          in->eat(1); // This is destructive
          int c=0;
          string t="";
          do{
            t+=in->peekto("\"",c)+"\"";
            c++;
          }while(t[sizeof(t)-1..]=="\\");
          t=t[..sizeof(t)-2];
          int cnt=sizeof(t) + 1;
          n=String(replace(t,({"\\\\","\\\""}),({"\\","\""})));
          in->eat(cnt);
        }
        _IM_P_DEBUG("String found: " + n->GetContents());
        break;
      case "{":
        if(n=String(in)){
          _IM_P_DEBUG("String found: " + n->GetContents());
        }
        break;
      default:
        // Pick the string whichever is smallest
        string t,t1,t2,t3;
        array a=({ }),b=({});
        if(t1=in->peekto(end)){
          a+=({t1});
          b+=({sizeof(t1)});
        }
        if(t2=in->peekto(" ")){
          a+=({t2});
          b+=({sizeof(t2)});
        }
        if(t3=in->peekto("\r")){
          a+=({t3});
          b+=({sizeof(t3)});
        }
        sort(b,a);
        if(a==({ }))
          t=(string)in;
        else
          t=a[0];
        if(t){
          if(t=="NIL"){
            n=Nil();
            _IM_P_DEBUG("NIL found.");
            in->eat(3);
            break;
          }
          reg = Regexp("^[0-9]+$");
          if(reg->match(t)){
            n=Number((int)t);
            _IM_P_DEBUG("Number found: " + n->GetContents());
            in->eat(sizeof(t));
            break;
          }
          reg = Regexp("^[-a-zA-Z0-9!#$&'=+,./:;<>?~|^_`]+$");
          if(reg->match(t)){
            n=Atom(t);
            _IM_P_DEBUG("Atom found: "  + n->GetContents());
            in->eat(sizeof(t));
            break;
          }
        }

        if(n=Text(in)){
          _IM_P_DEBUG("Text found (should only be in the end of answer): "
                      + n->GetContents());
        }else{
          _IM_P_DEBUG("Unable to identify the following: " +
                      sprintf("%O",(string)in));
          _IM_P_DEBUG("Leaving it.");
          return res;
        }
      }

      if(in->peek()==" ")
        in->eat(1);

      if(res==0) res=({ });

      res +=({n});
    }
  }


  string cast(string to){
    if(to!="string"){
      THROW("Unable to cast to " + to);
    }

    return (string)data;
  }

}

static class Nil {
  inherit DataItem;
  int Nilp() { return 1; };
  string Type() { return "Nil"; }
  mixed data="NIL";

  void create(void|object(my_string) in){
    if(!objectp(in))
      return;

    _IM_P_DEBUG("Trying to create NIL of " + sprintf("%O",(string)in));
    if(in->peek(4)=="NIL "||(in->peek(3)=="NIL" && in->left()==3)){
      // There must be a space after (i believe)
      // _IM_P_DEBUG("NIL created");
      in->eat(4);
    }else{
      destruct(this_object());
    }
  }

  string GetContents() { return "NIL"; }
};

static class Atom {
  inherit DataItem;
  int Atomp() { return 1; }
  string Type() { return "Atom"; }

  mixed data;

  void create(string|object(my_string) in){
    if(stringp(in)){
      data=in;
      return;
    }
    _IM_P_DEBUG("Trying to create Atom of " + sprintf("%O",(string)in));
    // This does actually not put all the restrictions there should
    // be on an atom on the input, but, since it is the last try
    // there shoudn't be any real bad effects of this
    int n=0,f=0;
    string t="",u;
    do{
      n++;
      u=in->peek(1,n-1);
      if(In(u,ATOM_SPECIALS)){
        n--;
        f=1;
        break;
      }
      t+=u;
    }while(in->left()-n);

    // Why did we break out of the loop?
    if(!HAPPYEND){
      // We encountered an invalid atom-char
      destruct(this_object());
      return;
    }
    data=t;
    in->eat(n);
    if(in->peek()==" ")
      in->eat(1);
  }

string GetContents(){ return data; }
  string GetLCContents() { return lower_case(data); }
};

static class Number {
  inherit DataItem;
  int Numberp() { return 1; }
  string Type() { return "Number"; }

  mixed data;

  void create(int|object(my_string) in){
    if(intp(in)){
      data=in;
      return;
    }

    _IM_P_DEBUG("Trying to create Number of " + sprintf("%O",(string)in));
    int n=0,f=0;
    string t="",u;
    do{
      n++;
      u=in->peek(1,n-1);
      if(!In(u,DIGIT)){
        f=1;
        n--;
        break;
      }
      t+=u;
    }while(in->left()-n);
    // Check what we got
    if(!HAPPYEND){
      // Not a Number
      destruct(this_object());
      return;
    }

    data=(int)t;
    in->eat(n);
    if(in->peek()==" ")
      in->eat(1);
  }

int GetContents() { return data; }
};

static class String { // Can be a literal och quoted string
  inherit DataItem;
  int Stringp() { return 1; }
  string Type() { return "String"; }

  mixed data;

  // Lowlevel parsers create()
  array get_quoted(object(my_string) in){
    int n=1, // Skip the first "\"" which already is detected
          f=1,b=0;
    string s,t="",u;
    do{
      n++;
      u=in->peek(1,n-1);
      // When to break out of the loop.
      switch(b){
      case 0: // No active "\\"
        if(In(u,QUOTED_SPECIALS)){
          if(u=="\\"){
            b=1;
          }else{ // Ok, an "\"" found
            f=0;
          }
        }else{
          t+=u;
        }
        break;
      case 1: // "\\" active, only some characters valid.
        if(In(u,QUOTED_SPECIALS)){
          // This is ok
          b=0;
          t+=u;
        }else{
          // This is not ok
          f=0;
          break;
        }
      }
      // Ok, we have passed this far. Finally check CRLF
      if(In(u,CRLF))
        break;

    }while(in->left()-n&&f);

    // The only valid end of this loop is if the last character is DQUOTE

    if(u!="\"")
      return 0; // We failed

    // Success, eat the string from the buffer
    return ({t,n});
  }

  array get_literal(object(my_string) in){
    int n=1; // The first "{" already found.
    int num,cnt;
    int stage=0,fail=0,f=1;
    string t="",u;
    do{
      n++;
      u=in->peek(1,n-1);
      switch(stage){
      case 0: // We are reading the digits
        if(In(u,DIGIT)){
          t+=u;
        }else{
          if(u=="}"){
            num=(int)t;
            cnt=0;
            t="";
            stage=1;
          }else{
            fail=1;
            f=0;
          }
        }
        break;
      case 1: // We want an CR
        if(u=="\r"){
          stage=2;
        }else{
          fail=1;
          f=0;
        }
        break;
      case 2: // We want an LF
        if(u=="\n"){
          f=0;
        }else{
          fail=1;
          f=0;
        }
        break;
      }

    }while(in->left()-n&&f);
    if(fail)
      // Something went wrong
      return 0;
    // Now read from current position to current + num
    t=in->peek(num,n);
    if(sizeof(t)!=num)
      THROW("Literal too short");
    n+=num;

    return ({ t, n });
  }
  // End subroutines


  void create(string|object(my_string) in){
    if(stringp(in)){
      data=in;
      return;
    }

    _IM_P_DEBUG("Trying to create String of " + sprintf("%O",(string)in));
    if(in->peek()!="\"" && in->peek()!="{"){
      // Not a string
      destruct(this_object());
      return;
    }
    // Ok, we have the beginning of a string. Handle the two cases
    array tmp;
    switch(in->peek()){
    case "\"":
      tmp = get_quoted(in);
      break;
    case "{":
      tmp = get_literal(in);
      break;
    }

    if(tmp==0){
      // Creation failed for some reason.
      destruct(this_object());
      return;
    }

    data=tmp[0];
    in->eat(tmp[1]);
    if(in->peek()==" ")
      in->eat(1);

  }

string GetContents() { return data; }
  string GetLCContents() { return lower_case(data); }

  string cast(string to){
    if(to!="string"){
      THROW("Cannot cast to " + to );
    }

    if(data==""){
      return "\"\"";
    }

    int i,f=0;
    object reg=Regexp(".*[\"\\\\\r\n].*");
    if(reg->match(data)) f=1;
    /*for(i=0;i<sizeof(data);i++){
      if(In(data[i..i],ATOM_SPECIALS + EIGHTBIT )){
    f=1;
    break;
      }
      }*/
    if(f)
      return "{" + (string)sizeof(data) + "}\r\n\0" + data ;
    else
      return "\"" + data + "\"";
  }


};

static class Flag {
  inherit DataItem;
  int Flagp() { return 1; }
  string Type() { return "Flag"; }

  mixed data;



  void create(string|object(my_string) in){
    if(stringp(in)){
      data=in;
      return;
    }

    _IM_P_DEBUG("Trying to create Flag of " + sprintf("%O",(string)in));
    if(in->peek()!="\\"){
      destruct(this_object());
      return;
    }
    int n=1,f=0;
    string t="",u;
    do{
      n++;
      u=in->peek(1,n-1);
      if(In(u,(ATOM_SPECIALS) - (<"*">) )){ // Bloff
        //A flag is almost an atom with an "\\" in front
        f=1;
        n--;
        break;
      }
      t+=u;
    }while(in->left()-n);

    // Why did we break out of the loop?
    if(!HAPPYEND){
      // We encountered an invalid atom-char
      destruct(this_object());
      return;
    }
    data=t;
    in->eat(n);
    if(in->peek()==" ")
      in->eat(1);
  }

string GetContents() { return data; }
  string GetLCContents() { return lower_case(data); }

  string cast(string to){ return "\\" + ::cast(to); }
};

static class ParenList {
  inherit DataItem;
  int ParenListp() { return 1; }
  string Type() { return "ParenList"; }

  mixed data;

  void create(array|object(my_string) in){
    if(arrayp(in)){
      data=in;
      return;
    }

    _IM_P_DEBUG("Trying to create ParenList of " + sprintf("%O",(string)in));
    if(in->peek()!="("){
      destruct(this_object());
      return;
    }
    int n=1;
    int eaten=0,cn;
    if(in->peek(2)=="( ")
      n++;
    in->eat(n);
    eaten+=n;
    cn=in->left();
    data=parse(in,")");
    if(in->peek()!=")"){
      // Argh.. no end paranthesis..
      in->uneat(eaten+cn-in->left());
      destruct(this_object());
      return;
    }
    if(in->peek()==")")
      in->eat(1);
    if(in->peek()==" ")
      in->eat(1);

  }

array(object) GetContents () { return data; }

  string cast(string to){
    if(to!="string"){
      THROW("Cannot cast to " + to);
    }

    string res="(";
    object t;
    if(data!=0){
      foreach(data,t){
        res+=(string)t + " ";

      }
      res=res[..sizeof(res)-2];
    }
    res+=")";
    return res;
  }

};

static class ReturnCode {
  inherit DataItem;
  int ReturnCodep() { return 1; }
  string Type() { return "ReturnCode"; }

  mixed data;

  void create(array|object(my_string) in){
    if(arrayp(in)){
      data=in;
      return;
    }

    _IM_P_DEBUG("Trying to create ReturnCode of " + sprintf("%O",(string)in));
    if(in->peek()!="["){
      destruct(this_object());
      return;
    }
    int n=1;
    int eaten=0,cn;
    if(in->peek(2)=="[ ")
      n++;
    in->eat(n);
    eaten+=n;
    cn=in->left();
    data=parse(in,"]");
    if(in->peek()!="]"){
      // Argh.. no end paranthesis..
      in->uneat(eaten+cn-in->left());
      destruct(this_object());
      return;
    }
    if(in->peek()=="]")
      in->eat(1);
    if(in->peek()==" ")
      in->eat(1);

  }


array(object) GetContents () { return data; }

  string cast(string to){
    if(to!="string"){
      THROW("Cannot cast to " + to);
    }

    string res="[";
    object t;
    foreach(data,t){
      res+=(string)t + " ";
    }
    res=res[..sizeof(res)-2];
    res+="]";
    return res;
  }


};

static class Text {
  inherit DataItem;
  int Textp() { return 1; }
  string Type() { return "Text"; }

  mixed data;

  void create(string|object(my_string) in){
    if(stringp(in)){
      data=in;
      return;
    }

    _IM_P_DEBUG("Trying to create Text of " + sprintf("%O",(string)in));
    int n=0;
    string t="",u;
    do{
      n++;
      u=in->peek(1,n-1);
      if(In(u,CRLF)){
        break;
      }
      t+=u;
    }while(in->left()-n);
    if(!sizeof(t)){
      // If we get anything we are successfull.
      destruct(this_object());
      return;
    }

    data=t;
    in->eat(n-1);
    if(in->peek()==" ")
      in->eat(1);
  }

string GetContents() { return data; }

}

/***************************************************************************
  CLASS
  ImapLine(string in)
  DESCRIPTION
  This class represents the answer from the IMAP server in a way nicer
  to use when trying to extract relevant data from what the IMAP server
  sends. It does not check more than basic syntax, and requires that the 
  submitted string is exactly one "line". If parsing fails it will raise
  an exception.
*/


static class ImapLine {
  inherit DataItem; // We need it for the parser

  Atom tag;
  mixed data;
  int type; // 0=untagged,1=tagged,2=cont.req
  string Type() {
    switch(type){
    case 0: return "Untagged";
    case 1: return "Tagged";
    case 2: return "ContReq";
    }
  }
int Untaggedp() { return type==0?1:0; };
int Taggedp() { return type==1?1:0; };
int ContReqp() { return type==2?1:0; };

  void create(object ms, void|array ind){
#ifdef IMAP_TIME
    float tid=gauge{
#endif
              if(arrayp(ind)){
              tag=ms;
              type=1;
              data=ind;
            }else{
              tag=0;
              switch(ms->peek()){
                case "+": // Continuation request
                    type=2;
                  ms->eat(2);
                  data = ({ Text(ms) });
                  break;
                case "*": // Untagged
                  type=0;
                  ms->eat(2);
                  data = parse(ms);
                  break;
                default:
                  type=1;
                  tag=Atom(ms);
                  data=parse(ms);
                  break;
                }
              }
#ifdef IMAP_TIME
};

    Stdio.stderr->write("Create: %O\n", tid);
#endif
  }

  string cast(string to){
    string res="";
#ifdef IMAP_TIME
    float tid=gauge{
#endif
              if(to!="string"){
              THROW("Cannot cast to " + to);
              }
              switch(type){
            case 0:
              res +="* ";
              break;
            case 1:
              if(tag)
                  res +=(string)tag + " ";
                break;
              case 2:
                res +="+ ";
                break;
              }

              object t;
              foreach(data,t){
                res +=(string)t + " ";
              }
              res=res[0..sizeof(res)-2];
#ifdef IMAP_TIME
            };
    Stdio.stderr->write("Cast: " + tid + "\n");
#endif
    return res + "\r\n";
  }

  array GetContents() { return data; }

  string GetTag() { if(type==1) return tag->GetContents(); else return 0;}

};


/* **************************************************************************
  CLASS
  ImapIO(string host, 
    int port,
    function tagged, 
    function untagged,
    function close)
    
  DESCRIPTION
  This module does all the lowlevel io for the imap-client. It buffers replys
  and calls a call_back function once it has got a complete reply-line.

  ARGUMENTS
  host         - which host to connect to
  port         - which port to connect to
  tagged       - Will be called whenever a tagged response arrives
  untagged     - Will be called whenever an untagged response arrives
  close        - Will be called if the server prematurely closes the connection
                 Probably there will be an untagged "BYE" before that.

  METHODS
  void write(object(ImapLine) data)
    puts data on the write-queue and writes it to the IMAP-connection.
  void set_untagged_callback(function callback)
    sets the untagged callback to callback
  void set_tagged_callback(function callback)
    sets the tagged callback to callback
  void set_close_callback(function callback)
    sets the close callback to callback
*/

static class ImapIO {
  object socket;
  string input,output;
  int tbr;
  object reg;
  array write_queue;
  function tagged_cb;
  function untagged_cb;
  function close_cb;
  int port;
  string host;

  int in_progress;

  void process_input(){
    object ms=my_string(input);
    object o;
    while(ms->left()){
      // Continue as long as we have a
      // line with end.
mixed el;
      if(el = catch(o=ImapLine(ms)))
{
       throw(el);
        break; // If there is an error, just leave the loop.
}
//werror("line: %O\n", o);
      if(ms->peek(2)=="\r\n") ms->eat(2);
      else break; // If there isn't an end of line left here, we haven't got the whole answer.
      // Read one more block..
      if(o->Untaggedp()){
        _IM_IO_DEBUG("Trying to call untagged callback with: " +
                     sprintf("%O",(string)o));
        if(untagged_cb) untagged_cb(o);
      }
      if(o->Taggedp()){
        in_progress=0;
        _IM_IO_DEBUG("Trying to call tagged callback with: " +
                     sprintf("%O",(string)o));
        if(tagged_cb) tagged_cb(o);
        process_queue();
      }
      if(o->ContReqp()){
        _IM_IO_DEBUG("Continuation request: " +
                     sprintf("%O",(string)o));
        process_queue(1);
      }
      input=(string)ms; // Save what's left. (If we break out of the loop prematurely.)
    }
  }

  void process_queue(void|int cr){
    if(write_queue==({ })){
      _IM_IO_DEBUG("Nothing to write in queue");
      return;
    }
    if(output!=""){
      _IM_IO_DEBUG("Still things to be written");
      return;
    }
    array t=write_queue[0];
    if(t[1]==1&&cr==0){
      _IM_IO_DEBUG("Waiting for a continuation request");
      return;
    }
    if(cr==0 && in_progress){
      _IM_IO_DEBUG("Command in progress, queue not processed");
      return;
    }

    if(t[1]==cr){
      output=t[0];
      write_queue=write_queue[1..];
      write_some();
    }
  }


  void read_some(mixed id, string data){
    input +=data;
    if(tbr){
      tbr-=sizeof(data);
      if(tbr<=0)
        tbr=0;
      else
        return;
    }else{
      if(reg->match(data)){
        array spl=reg->split(data);
        tbr=(int)spl[1]-sizeof(spl[2]);
        if(tbr>0)
          return;
        else
          tbr=0;
      }
    }
//werror("input: %O\n", input);
    if(!has_suffix(input, "\r\n"))
      return;
    process_input();
  }

  void write_some(){
    int written;
    if(output=="")
      // Check if there is something pending to be written
      process_queue();
    if(output=="")
      return; // Appearently not
    in_progress=1;
    written=socket->write(output);
    if(written<0) THROW("Unable to write to socket\n");
    output=output[written..];
  }

  void close(){ // If the close callback was set, call it.
    _IM_IO_DEBUG("Calling close callback");
    if(close_cb){
      close_cb();
    }
  }

  void create(string h, int p, function tcb, function utcb, function cl){
    host=h;
    port=p;
    tagged_cb=tcb;
    untagged_cb=utcb;
    close_cb=cl;

    input="";
    output="";
    tbr=0;
    reg=Regexp("(.*){([0-9]+)}\r\n(.+)");
    write_queue=({ });
    socket=Stdio.File();
    if(!socket->open_socket())
      THROW("Unable to open socket");

    int res = socket->connect(host,port);
    werror("connect: %O\n", res);
    socket->set_nonblocking(read_some,write_some,close);
  }

import SSL;
void start_tls(int|void blocking, int|void async)
{
object context;
object con = socket;
#ifdef HTTP_QUERY_DEBUG
  werror("start_tls(%d)\n", blocking);
#endif
#if constant(SSL.Cipher.CipherAlgorithm)
  if( !context )
  {
    // Create a context
    context = SSL.context();
    context->random; 
Crypto.Random.random_string;
  }

  object read_callback=con->query_read_callback();
  object write_callback=con->query_write_callback();
  object close_callback=con->query_close_callback();

  SSL.sslfile ssl = SSL.sslfile(con, context, 1, blocking);
  if(!blocking) {
    if (async) {
//      ssl->set_nonblocking(0,async_connected,async_failed);
    } else {
      ssl->set_read_callback(read_callback);
      ssl->set_write_callback(write_callback);
      ssl->set_close_callback(close_callback);
    }
  }
  socket=ssl;
#else
  error ("HTTPS not supported (Nettle support is required).\n");
#endif
}

  void write(object(ImapLine) data){
    array tmp=((string)data)/"\0";
    array res=({({tmp[0],0})});
    if(sizeof(tmp)>1){
      int i;
      for(i=1;i<sizeof(tmp);i++){
        res+=({({tmp[i],1})});
      }
    }
    write_queue+=res;
    process_queue();
  }

  void set_untagged_callback(function cb){
    untagged_cb=cb;
  }

  void set_tagged_callback(function cb){
    tagged_cb=cb;
  }

  void set_close_callback(function cb){
    close_cb=cb;
  }

};



/* ***************************************************************************
   CLASS
   Client(string host,
          int port)

*/

class Client {
  // Internal data:
  static object con; // The ImapIO connection
  static string pwd,usrn;
  static int tagcnt; // Tag-counter
  static int ustate,tstate; // 1 when the server has said that it is ready
  static int idling;
  int can_idle = 0;
  // store
  static array untagged_responses;

  // callbacks
  static function bye_cb;
  static function close_cb;
  static function state_cb;
  static function ready_cb;
  static mapping tagged_cb;

  // The Constructor

  void create( string host,
               int port,
               string username,
               string passwd,
               function state_callback,
               function close_callback,
               function bye_callback,
               function ready_callback
             ){
    state_cb=state_callback;
    close_cb=close_callback;
    bye_cb=bye_callback;
    ready_cb=ready_callback;
    con=ImapIO(host,port,tagged,untagged,close);
    pwd=passwd;
    usrn=username;
    tagcnt=0xA00000;
    ustate=0;
    tstate=0;
    untagged_responses=({});
    tagged_cb=([ ]);
  }

  static object GetTag(){
    return Atom(sprintf("%6.6x",tagcnt++));
  }

  static void tagged(object line){
    if(tstate==0){
      if(line->GetTag()=="Stls"&&line->GetContents()[0]->GetLCContents()=="ok"){
werror("starting tls.\n");
        con->start_tls(0);
        con->write(ImapLine(Atom("LoGIn"),({Atom("LOGIN"),String(usrn),String(pwd)})));
      }
      else if(line->GetTag()=="LoGIn"&&line->GetContents()[0]->GetLCContents()=="ok"){
        tstate==1;
        _IM_C_DEBUG("Server ready");
        if(ready_cb){
          if(sizeof(untagged_responses)){
            if(untagged_responses[0][1]->ReturnCodep()
                && untagged_responses[0][1]->GetContents()[0]->GetLCContents()=="alert"){
              if(ready_cb)
                ready_cb(1,(untagged_responses[0][2..]->cast("string"))*" ");
            }
          }else
            if(ready_cb)
              ready_cb(1);

        }
        untagged_responses=({ });
        tstate=1;
      }else{
        if(ready_cb)
          ready_cb(0,"Login failed");
      }
    }else{
      _IM_C_DEBUG("Got tagged response");
      string tag=line->GetTag();
      array cb;
      if((cb=tagged_cb[tag])==0)
        THROW("Unknown tag: " + tag + "\n");
tagged_cb-=([tag:0]); // This will rebuild the whole thing..
      cb[0](line,cb[1]);
    }
    int ur=-1;
    catch(ur=sizeof(untagged_responses));
    _IM_C_DEBUG("Number of untagged responses left: " + ur);
  }

  // Helper for untagged -- parsing of envelope
  static array mk_as_array(object in){
    if(in->Nilp())
      return 0;
    if(!in->ParenListp()){
      THROW("ParenList needed");
    }
    array ret=({ });
    object o;
    foreach(in->GetContents(),o){
      array ar;
      string a=0,b=0,c=0,d=0;
      ar=o->GetContents();
      a=ar[0]->Nilp()?0:(string)ar[0]->GetContents();
      b=ar[1]->Nilp()?0:(string)ar[1]->GetContents();
      c=ar[2]->Nilp()?0:(string)ar[2]->GetContents();
      d=ar[3]->Nilp()?0:(string)ar[3]->GetContents();
      ret+=({({a,b,c,d})});
    }
    return ret;

  }



  static void untagged(object line){
  int starttls = 0;
  int login = 0;
    if(ustate==0){
      foreach(line->GetContents();;object c)
      {
  
        if(c->ReturnCodep())
        {
          foreach(c->GetContents();; object atom)
          {
            if((string)atom == "STARTTLS") starttls = 0;
            else if(((string)atom - " ") == "AUTH=PLAIN") login = 1; 
            else if((string)atom == "IDLE") can_idle = 1;
          }
        }
      }
      if(lower_case((string)line->GetContents()[0])=="ok"){ // The server is ready.
          ustate=1;
        if(!login) throw(Error.Generic("IMAP Server does not support AUTH=LOGIN."));
        if(starttls)
        {
           con->write(ImapLine(Atom("Stls"),({Atom("STARTTLS")})));
           return;
        }
        if(login)
          con->write(ImapLine(Atom("LoGIn"),({Atom("LOGIN"),String(usrn),String(pwd)})));
      } else
        if(ready_cb)
          ready_cb(0,"Imap-Server not accepting connections or not an Imap server\n");
    }else{
      _IM_C_DEBUG("Got untagged response.");
      // Normal handling of untagged responses

      // First check if it is a status change of the mailbox
      array li=line->GetContents();
      // Check for bye
      if(li[0]->Atomp()
          && li[0]->GetLCContents()=="bye"
          && li[1]->ReturnCodep()
          && li[1]->GetContents()[0]->Atomp()
          && li[1]->GetContents()[0]->GetLCContents()=="alert"
        ){
        _IM_C_DEBUG("Got untagged BYE");
        if(bye_cb){
          bye_cb((li[2..]->cast("string"))*" ");
        }
        return;
      }
      if(li[0]->Numberp() && li[1]->Atomp()){
        switch(li[1]->GetLCContents()){
        case "recent":
          _IM_C_DEBUG("Number of recent messages: " + li[0]->GetContents());
          if(state_cb)
            state_cb("recent",li[0]->GetContents());
          return;
        case "exists":
          _IM_C_DEBUG("Number of messages in mailbox: " + li[0]->GetContents());
          if(state_cb)
            state_cb("exists",li[0]->GetContents());
          return;
        case "expunge":
          _IM_C_DEBUG("Message number " + (string)li[0] + " expunged");
          if(state_cb)
            state_cb("expunge",li[0]->GetContents());
          return;
        case "fetch":
          _IM_C_DEBUG("Fetch " + (string)li[0]);
          mapping ret=([ ]);
          ret->msg_no=li[0]->GetContents();
          int i;
          for(i=0;i<sizeof(li[2]->GetContents());i+=2){
            switch(li[2]->GetContents()[i]->GetLCContents()){
            case "rfc822.size":
              ret->size=li[2]->GetContents()[i+1]->GetContents();
              break;
            case "uid":
              ret->uid=li[2]->GetContents()[i+1]->GetContents();
              break;
            case "rfc822":
              ret->rfc822=li[2]->GetContents()[i+1]->GetContents();
              break;
            case "internaldate":
              ret->internaldate=li[2]->GetContents()[i+1]->GetContents();
              break;
            case "flags":
              ret->flags=(< >);
              array a=li[2]->GetContents()[i+1]->GetContents();
              if(a!=0)
                a=a->GetLCContents();
              else
                break;
              string b;
              foreach(a,b)
              ret->flags[b]=1;
              break;
            case "envelope":
              mapping out_env=([ ]);
              array in_env=li[2]->GetContents()[i+1]->GetContents();
              out_env->date=in_env[0]->GetContents();
              out_env->subject=in_env[1]->GetContents();
              out_env->in_reply_to=in_env[8]->Nilp()
                                   ?0:in_env[8]->GetContents();
              out_env->message_id=in_env[9]->Nilp()
                                  ?0:in_env[9]->GetContents();
              out_env->from=mk_as_array(in_env[2]);
              out_env->sender=mk_as_array(in_env[3]);
              out_env->reply_to=mk_as_array(in_env[4]);
              out_env->to=mk_as_array(in_env[5]);
              out_env->cc=mk_as_array(in_env[6]);
              out_env->bcc=mk_as_array(in_env[7]);

              ret->envelope=out_env;
              break;
            default:
              _IM_C_DEBUG(li[2]->GetContents()[i]->GetLCContents() +
                          " not implemented.");
            }
          }
          state_cb("fetch",ret);
          return;
        }
      }

      // If we reach this far the result will be handled by some coming tagged handler.
      untagged_responses+=({li});
    }
  }

  static void close(){
    _IM_C_DEBUG("Connection closed by foreign host");
    if(close_cb)
      close_cb();
  }

  static void send_line(object line, function handler, function ext_cb){
    if(idling)
    {
       idling = 0;
       con->write("DONE\r\n");
    }
    tagged_cb+=([line->GetTag():({handler,ext_cb})]);
    con->write(line);
  }

  static array getall(string resp){
    int i;
    array res=({ });
    for(i=0;i<sizeof(untagged_responses);i++){
      if(untagged_responses[i][0]->Atomp()&&untagged_responses[i][0]->GetLCContents()==resp){
        res+=untagged_responses[i..i];
        untagged_responses[i]=0;
      }else if(untagged_responses[i][0]->Numberp() &&
               untagged_responses[i][1]->Atomp() &&
               untagged_responses[i][1]->GetLCContents()==resp){
        res+=untagged_responses[i..i];
        untagged_responses[i]=0;
      }
    }
    untagged_responses-=({ 0 });
    return res;
  }

  static void noop_handler(object line, function ext_cb){
    _IM_C_DEBUG("NOOP done");
    if(ext_cb){
      ext_cb(line->GetTag(),1);
    }
  }

  string noop(void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("NOOP")}));
    send_line(line,noop_handler,cb);
    _IM_C_DEBUG("Sent noop");
    return (string)tag;
  }

  static void logout_handler(object line, function ext_cb){
    getall("bye");
    _IM_C_DEBUG("LOGOUT done");
    if(ext_cb){
      ext_cb(line->GetTag(),1);
    }
  }

  string logout(void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("LOGOUT")}));
    send_line(line,logout_handler,cb);
    _IM_C_DEBUG("Sent logout");
    return (string)tag;
  }

  static void select_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }

    mapping res=([ ]);
    array t;
    if(line->GetContents()[1]->GetContents()[0]->GetLCContents()=="read-write"){
      res["read_write"]=1;
    }else{
      _IM_C_DEBUG("Selecting read-only mailbox");
      res["read_write"]=0;
    }

    // Any exists or recent response is catched higher up and sent to the state callback.
    // Pick flags.
    t=getall("flags");
    if(sizeof(t)!=0){
      array a=(t[0][1]->GetContents())->GetLCContents();
      res["flags"]=(< >);
      string b;
      foreach(a,b)
      res->flags[b]=1;
    }

    // Pick all untagged "ok" responses
    t=getall("ok");
    array a;
    foreach(t,a){
      if(a[1]->ReturnCodep())
        switch(a[1]->GetContents()[0]->GetLCContents()){
        case "permanentflags":
          res["permanentflags"]=(< >);
          array b=(a[1]->GetContents()[1]->GetContents())->GetLCContents();
          string c;
          foreach(b,c)
          res->permanentflags[c]=1;
          break;
        case "unseen":
          res["unseen"]=a[1]->GetContents()[1]->GetContents();
          break;
        case "uidvalidity":
          res["uidvalidity"]=a[1]->GetContents()[1]->GetContents();
          break;
        }
    }


    _IM_C_DEBUG("Select done");
    if(ext_cb){
      ext_cb(line->GetTag(),res);
    }
  }

  string select(string mbox, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("SELECT"),String(mbox)}));
    send_line(line,select_handler,cb);
    _IM_C_DEBUG("Sent SELECT " + mbox);
    return (string)tag;
  }

  static void get_hiersep_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }

    array res=getall("list");
    if(sizeof(res)!=1)
      _IM_C_DEBUG("Ehh.. multiple commands in progres?");
    _IM_C_DEBUG("Hierarchy separator is " + (string)res[0][2]);
    if(ext_cb)
      ext_cb(line->GetTag(), (string)res[0][2]);
  }

  string get_hiersep(void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("LIST"),String(""),String("")}));
    send_line(line,get_hiersep_handler,cb);
    _IM_C_DEBUG("Sent LIST \"\" \"\"");
    return (string)tag;
  }

  static void list_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }


    array ret=({}),res=getall("list");
    int i;
    object t;
    for(i=0;i<sizeof(res);i++){
      if(res[i][1]->GetContents()!=0){
        int f=1;
        foreach(res[i][1]->GetContents(),t){
          if(t->GetLCContents()=="noselect"){
            f=0;
            break;
          }
        }
        if(f)
          ret+=({res[i][3]->GetContents()});
      }else
        ret+=({res[i][3]->GetContents()});
    }
    _IM_C_DEBUG("LIST succesful, got " + sizeof(ret) + " entries.");
    if(ext_cb)
      ext_cb(line->GetTag(),ret);
  }


  string list(string refer, string mbox, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("LIST"),String(refer),String(mbox)}));
    send_line(line,list_handler,cb);
    _IM_C_DEBUG("Sent LIST \""+refer+"\" \""+mbox+"\"");
    return (string)tag;
  }

  static void status_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }

    array res=getall("status")[0]; // There should only be one status to get.
    array a=res[2]->GetContents();
    if(sizeof(a)!=6)
      THROW("Did status generate a non-rfc answer?\n");

    mapping ret=([ ]);
    int i;
    for(i=0;i<6;i+=2)
      ret[a[i]->GetLCContents()]=a[i+1]->GetContents();
    ret->mboxname=res[1]->GetContents();


    if(ext_cb)
      ext_cb(line->GetTag(),ret);
  }


  string status(string mbox, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("STATUS"),String(mbox),
                               ParenList( ({Atom("MESSAGES"),Atom("RECENT"),Atom("UNSEEN")}) )
                              }));
    send_line(line,status_handler,cb);
    _IM_C_DEBUG("Sent STATUS " + mbox);
    return (string)tag;
  }

  static void new_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("CREATE successful");
    if(ext_cb){
      ext_cb(line->GetTag(),1);
    }
  }

  // Argh.. why is the constructor in pike called 'create'? ;)
  string new(string mbox, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("CREATE"),String(mbox)}));
    send_line(line,new_handler,cb);
    _IM_C_DEBUG("Sent CREATE " + mbox);
    return (string)tag;
  }

  static void delete_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("DELETE successful");
    if(ext_cb){
      ext_cb(line->GetTag(),1);
    }
  }

  string delete(string mbox, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("DELETE"),String(mbox)}));
    send_line(line,delete_handler,cb);
    _IM_C_DEBUG("Sent DELETE " + mbox);
    return (string)tag;
  }

  static void rename_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("RENAME successful");
    if(ext_cb){
      ext_cb(line->GetTag(),1);
    }
  }

  string rename(string ombox, string nmbox, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("RENAME"),String(ombox),String(nmbox)}));
    send_line(line,rename_handler,cb);
    _IM_C_DEBUG("Sent RENAME " + ombox + " " + nmbox);
    return (string)tag;
  }

  static void append_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("APPEND successful");
    if(ext_cb){
      ext_cb(line->GetTag());
    }
  }

  string append(string mbox, array flags, string data, void|function cb){
    object tag=GetTag();
    array flist=({});
    foreach(flags,string t)
    flist+=({Flag(t)});
    object line=ImapLine(tag,({Atom("APPEND"),String(mbox),
                               ParenList(flist),String(data)}));
    send_line(line,append_handler,cb);
    _IM_C_DEBUG("Sent APPEND " + mbox + " data");
    return (string)tag;
  }

  static void fetch_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("FETCH successful");
    if(ext_cb){
      ext_cb(line->GetTag());
    }
  }

  static void idle_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("IDLE successful");
    if(ext_cb){
      ext_cb(line->GetTag());
    }
  }

  string fetch(int|string seqno, string|array(string) what, void|function cb){
    object tag=GetTag();
    array list=({ });
    if(stringp(what))
      what=({ what });

    string t;
    foreach(what,t){
      switch(lower_case(t)){
      case "envelope":
      case "rfc822":
      case "rfc822.size":
      case "internaldate":
      case "flags":
        break;
      default:
        THROW("Don't kow how to fetch " + t + "\n");
      }
      list+=({ Atom(lower_case(t)) });
    }

    object fetch_what;
    if(intp(seqno))
      fetch_what = Number(seqno);
    else
      fetch_what = Atom(seqno);

    object line=ImapLine(tag,({Atom("FETCH"),fetch_what,
                               ParenList(list)}));
    send_line(line,fetch_handler,cb);
    _IM_C_DEBUG("Sent FETCH");
    return (string)tag;
  }

  string idle(function cb)
  {
    if(!can_idle) throw(Error.Generic("server does not support IDLE.\n"));
    object tag=GetTag();
    idling = 1;
    object line=ImapLine(tag,({Atom("IDLE")}));
    send_line(line,idle_handler,cb);
    _IM_C_DEBUG("Sent IDLE");
    return (string)tag;
  }

  static void expunge_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("EXPUNGE sucessful");
    if(ext_cb){
      ext_cb(line->GetTag());
    }
  }

  string expunge(void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("EXPUNGE")}));
    send_line(line,expunge_handler,cb);
    _IM_C_DEBUG("Sent EXPUNGE");
    return (string)tag;
  }

  static void store_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("STORE successful");
    if(ext_cb){
      ext_cb(line->GetTag());
    }
  }

  string store(int seqno, string what, array flags,void|function cb){
    object tag=GetTag();
    switch(what){
    case "set":
      what="FLAGS";
      break;
    case "add":
      what="+FLAGS";
      break;
    case "remove":
      what="-FLAGS";
      break;
    default:
      THROW("Don't know how to " + what +" a flag\n");
    }
    array flist=({ });
    foreach(flags,string t)
    flist+=({Flag(t)});

    object line=ImapLine(tag,({Atom("STORE"),Number(seqno),Atom(what),
                               ParenList(flist)}));
    send_line(line,expunge_handler,cb);
    _IM_C_DEBUG("Sent STORE");
    return (string)tag;
  }


  static void copy_handler(object line, function ext_cb){
    if(line->GetContents()[0]->GetLCContents()!="ok"){
      if(ext_cb)
        ext_cb(line->GetTag(),0,(line->GetContents()->cast("string"))*" ");
      return;
    }
    _IM_C_DEBUG("COPY sucessful");
    if(ext_cb){
      ext_cb(line->GetTag());
    }
  }

  string copy(int seqno, string to, void|function cb){
    object tag=GetTag();
    object line=ImapLine(tag,({Atom("COPY"),Number(seqno),String(to)}));
    send_line(line,expunge_handler,cb);
    _IM_C_DEBUG("Sent COPY " + seqno +" " + to);
    return (string)tag;
  }

  void destroy(){
    _IM_C_DEBUG("Destroyed");
  }
};
