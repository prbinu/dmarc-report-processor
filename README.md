Script to pull DMARC records, process and pass it to splunk.
 
**imap-client.py** - Pull attachments from mail imap server and store
it in the given directory. This is a generic program that can be used to
fetch emails and/or attachments using IMAP protocol.

**dmarc-parser.py** - Convert the xml files to comma-seperated key=value
 pair (line oriented output for splunk). This script can handle large xml files

**dmarc-convertor.sh** - An uber script to manage the workflow end-to-end:
  1. Download attachments from mail server
  2. Unzip the attachments
  3. Parse unzipped xml files and convert it line oriented format for splunk

### Usage

#### imap-client.py

``` 
imap-client.py [-h] [-v] [--attachmentsonly] [--disablereadonly]
                      [--quiet] -s HOST [-p PORT] -c CACERTS -u USER -f FOLDER
                      -o OUTDIR [-S SEARCH] [-P PWDFILE]

optional arguments:
  -h, --help            show this help message and exit
  -v, --verbose         increase output verbosity
  --attachmentsonly     download attachments only
  --disablereadonly     enable state changes on server; Default readonly
  --quiet               supress all comments (stdout)
  -s HOST, --host HOST  imap server; eg. imap.mail.yahoo.com
  -p PORT, --port PORT  imap server port; Default is 993
  -c CACERTS, --cacerts CACERTS
                        CA certificates, which are used to validate
                        certificates passed from imap server
  -u USER, --user USER  user's email id
  -f FOLDER, --folder FOLDER
                        mail folder from which the mail to retrieve
  -o OUTDIR, --outdir OUTDIR
                        directory to output
  -S SEARCH, --search SEARCH
                        search criteria, defined in IMAP RFC 3501; eg. "SINCE
                        \"8-Sep-2014\""
  -P PWDFILE, --pwdfile PWDFILE
                        A file that stores IMAP user password. If not set, the
                        user is prompted to provide a passwd

Example: 
  % imap-client.py -s imap.example.com -c ./cacert.pem -u dmarc@example.com -f inbox -o ./mymail -S "SINCE \"8-Sep-2014\"" -P
./paswdfile
```

#### dmarc-parser.py

```
dmarc-parser.py [-h] dmarcfile

positional arguments:
  dmarcfile   dmarc file in XML format

optional arguments:
  -h, --help  show this help message and exit

Example: 
  % dmarc-parser.py dmarc-xml-file 1> outfile.csv
```

#### dmarc-convertor.sh

```
dmarc-convertor.sh -u user_emailid -s imapserver -c cacertfile [-p port] [-P pwdfile] [-h] 
Options:
    -u   User email id
    -P   File that contains user password. Default: The user will be 
         prompted to provide password if you leave this option.
         WARNING: The file should be with permission
         0400 or 0440 (ie should NOT be world readable)
    -s   IMAP server name
    -p   IMAP port number. Default: 993
    -c   CA certificate file (eg. cacert.pem), used to validate certificates
         passed from IMAP server
    -h   Help

Example:
  % dmarc-convertor.sh -u dmarc@example.com -P ./pwd -s imap.example.com -p 993 -c ./cacert.pem
```

The

```
	dmarcReportProcessor.service
	dmarcReportProcessor.timer
```

shows a possible systemd call to execute the report collection. The env RUAFOLDER defines the IMAP folder where the reports are.


*NOTE* The above script expects `imap-client.py` and `dmarc-parser.py` available in $ROOT/bin. You may change the path by modifiying `dmarc-convertor.sh`. 

Tested on python 2.7
