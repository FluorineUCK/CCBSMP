using System;
using System.IO;
using System.Net.Sockets;
using System.Text;

public static class BackupRcon {
    static byte[] ReadExact(NetworkStream s, int n) {
        byte[] b=new byte[n]; int p=0;
        while(p<n) {int k=s.Read(b,p,n-p);if(k==0)throw new IOException("RCON connection closed");p+=k;}
        return b;
    }
    static void Send(NetworkStream s, int id, int type, string message) {
        byte[] text=Encoding.UTF8.GetBytes(message);
        using(var m=new MemoryStream())using(var w=new BinaryWriter(m)) {
            w.Write(text.Length+10);w.Write(id);w.Write(type);w.Write(text);w.Write((byte)0);w.Write((byte)0);
            byte[] b=m.ToArray();s.Write(b,0,b.Length);
        }
    }
    static string Receive(NetworkStream s, out int id, out int type) {
        int n=BitConverter.ToInt32(ReadExact(s,4),0);
        if(n<10 || n>4194304)throw new IOException("Invalid RCON packet length");
        byte[] b=ReadExact(s,n);id=BitConverter.ToInt32(b,0);type=BitConverter.ToInt32(b,4);
        if(b[n-1]!=0 || b[n-2]!=0)throw new IOException("Malformed RCON packet");
        return Encoding.UTF8.GetString(b,8,n-10);
    }
    public static string Run(string host,int port,string password,string command,int timeoutMs) {
        using(var c=new TcpClient()) {
            var connect=c.ConnectAsync(host,port);
            if(!connect.Wait(timeoutMs))throw new TimeoutException("RCON connect timeout");
            c.ReceiveTimeout=timeoutMs;c.SendTimeout=timeoutMs;
            using(var s=c.GetStream()) {
                s.ReadTimeout=timeoutMs;s.WriteTimeout=timeoutMs;
                Send(s,1,3,password); bool authenticated=false;
                for(int i=0;i<3;i++) {
                    int id,type;Receive(s,out id,out type);
                    if(id==-1)throw new IOException("RCON authentication rejected");
                    if(id==1 && type==2){authenticated=true;break;}
                }
                if(!authenticated)throw new IOException("Missing RCON authentication response");
                Send(s,2,2,command);
                int replyId,replyType;string reply=Receive(s,out replyId,out replyType);
                if(replyId!=2 || replyType!=0)throw new IOException("Unexpected RCON command response");
                return reply;
            }
        }
    }
    public static string UnescapeProperty(string s) {
        var b=new StringBuilder();
        for(int i=0;i<s.Length;i++) {
            if(s[i]!='\\'){b.Append(s[i]);continue;}
            if(++i>=s.Length)throw new FormatException("Unsupported multiline properties value");
            char c=s[i];
            if(c=='u'){if(i+4>=s.Length)throw new FormatException("Invalid unicode escape");b.Append((char)Convert.ToInt32(s.Substring(i+1,4),16));i+=4;}
            else if(c=='n')b.Append('\n');else if(c=='r')b.Append('\r');else if(c=='t')b.Append('\t');else if(c=='f')b.Append('\f');else b.Append(c);
        }
        return b.ToString();
    }
}
