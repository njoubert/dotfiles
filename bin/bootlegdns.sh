 #!/bin/bash
 dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}' | ssh njoubert@njoubert.com 'cat > macmini.local'
