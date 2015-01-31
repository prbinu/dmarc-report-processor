#!/usr/bin/python
#
# Copyright (c) 2014, Yahoo! Inc.
# Copyrights licensed under the New BSD License. See the
# accompanying LICENSE.txt file for terms.
#
# Author Binu P. Ramakrishnan
# Created 09/12/2014
# 
# An easy to use python script that
#  1. Dumps emails from a given IMAP folder to a local folder.  
#  2. A option to dump mail attachments only (not contents) 
#  3. Support search criteria. Eg. all mail SINCE '10-Sep-2014'
#

import sys
import os
import socket
import ssl
import imaplib, email
import argparse
import getpass
import datetime

# Override IMAP4_SSL to validate server identity (CA cert validation)
class IMAP4_SSL_Ex(imaplib.IMAP4_SSL):
  def __init__(self, host = '', port = imaplib.IMAP4_SSL_PORT,
                                ca_certs = None, cert_reqs = ssl.CERT_REQUIRED,
                                ssl_version = ssl.PROTOCOL_TLSv1):
    self.cert_reqs = cert_reqs
    self.ca_certs = ca_certs
    self.ssl_version = ssl_version
    imaplib.IMAP4_SSL.__init__(self, host, port, keyfile = None, certfile = None)

  def open(self, host = '', port = imaplib.IMAP4_SSL_PORT):
    self.host = host
    self.port = port
    self.sock = socket.create_connection((host, port))
    self.sslobj = ssl.wrap_socket(self.sock, self.keyfile, 
                          self.certfile, 
                          cert_reqs=self.cert_reqs,
                          ssl_version=self.ssl_version,
                          ca_certs=self.ca_certs)
    self.file = self.sslobj.makefile('rb')

# global object
args = ""

def vprint(msg):
  global args
  if args.quiet: return
  if args.verbose: print msg;

def process_mailbox(mail):
  # dumps emails/attachments in the folder to output directory.
  global args
  count=0
  vprint(args.search)

  ret, data = mail.search(None, '(' + args.search + ')')
  if ret != 'OK':
    print >> sys.stderr, "ERROR: No messages found"
    return 1

  if not os.path.exists(args.outdir):
    os.makedirs(args.outdir)

  for num in data[0].split():
    ret, data = mail.fetch(num, '(RFC822)')
    if ret != 'OK':
	print >> sys.stderr, "ERROR getting message from IMAP server", num
	return 1

    if not args.attachmentsonly:
      vprint ("Writing message "+ num)
      fp = open('%s/%s.eml' %(args.outdir, num), 'wb')
      fp.write(data[0][1])
      fp.close()
      count = count + 1
      print args.outdir+"/"+num+".eml"

    else:
      m = email.message_from_string(data[0][1])
      if m.get_content_maintype() == 'multipart' or \
      m.get_content_type() == 'application/zip' or \
      m.get_content_type() == 'application/gzip': 
	for part in m.walk():

	  #find the attachment part
	  if part.get_content_maintype() == 'multipart': continue
	  if part.get('Content-Disposition') is None: continue

	  #save the attachment in the given directory
	  filename = part.get_filename()
	  if not filename: continue
	  filename = args.outdir+"/"+filename
	  fp = open(filename, 'wb')
	  fp.write(part.get_payload(decode=True))
	  fp.close()
	  print filename
          count = count + 1
    
  if args.attachmentsonly:
    print "\nTotal attachments downloaded: ", count
  else:
    print "\nTotal mails downloaded: ", count

def main():
  global args
  options = argparse.ArgumentParser(epilog='Example: \
  %(prog)s  -s imap.example.com -c ./cacert.pem -u dmarc@example.com -f inbox -o ./mymail -S \"SINCE \\\"8-Sep-2014\\\"\" -P ./paswdfile')
  options.add_argument("-v", "--verbose", help="increase output verbosity", action="store_true")
  options.add_argument("--attachmentsonly", help="download attachments only", action="store_true")
  options.add_argument("--disablereadonly", help="enable state changes on server; Default readonly", action="store_true")
  options.add_argument("--quiet", help="supress all comments (stdout)", action="store_true")
  options.add_argument("-s", "--host", help="imap server; eg. imap.mail.yahoo.com", required=True)
  options.add_argument("-p", "--port", help="imap server port; Default is 993", default=993)
  options.add_argument("-c", "--cacerts", help="CA certificates, which are used to validate certificates passed from imap server", required=True)
  options.add_argument("-u", "--user", help="user's email id", required=True)
  options.add_argument("-f", "--folder", help="mail folder from which the mail to retrieve", required=True)
  options.add_argument("-o", "--outdir", help="directory to output", required=True)
  options.add_argument("-S", "--search", help="search criteria, defined in IMAP RFC 3501; eg. \"SINCE \\\"8-Sep-2014\\\"\"", default="ALL")
  options.add_argument("-P", "--pwdfile", help="A file that stores IMAP user password. If not set, the user is prompted to provide a passwd")
  args = options.parse_args()

  # redirect stdout to /dev/null
  if args.quiet:
    f = open(os.devnull, 'w')
    sys.stdout = f

  if args.pwdfile:
    infile = open(args.pwdfile, 'r')
    firstline = infile.readline()
    args.pwd = firstline
  else:
    args.pwd = getpass.getpass()  

  mail = IMAP4_SSL_Ex(args.host, args.port, args.cacerts)
  mail.login(args.user, args.pwd)
  ret, data = mail.select(args.folder, True)
  if ret == 'OK':
    vprint("Processing mailbox: " + args.folder)
    if process_mailbox(mail):
      mail.close()
      mail.logout()
      sys.exit(1)
      
    mail.close()
  else:
    print >> sys.stderr, "ERROR: Unable to open mailbox ", rv
    mail.logout()
    sys.exit(1)

  mail.logout()

# entry point
if __name__ == "__main__":
  main()

