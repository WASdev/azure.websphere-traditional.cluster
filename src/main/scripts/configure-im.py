#      Copyright (c) Microsoft Corporation.
#      Copyright (c) IBM Corporation.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Usage method
def usage():
    print ""
    print "Usage to configure IM:"
    print "  wsadmin -lang jython -f configure-im.py nodename webserver" 
    sys.exit()

# Init the global variables
ischanged = 0

# Next get the policy set, node and cell
try:
    nodename = sys.argv[0]
    webserver = sys.argv[1]
except:
    print 'Missing parms.'
    usage()

try:
    attrs = '-node "' + nodename + '" -webserver "' + webserver + '"'
    AdminTask.enableIntelligentManagement([attrs]) 
    ischanged = 1
except:
    print "Unexpected error:", sys.exc_info()[0], sys.exc_info()[1], sys.exc_info()[2]
    print "Enable failed"

# Save after the action is done
if 1 == ischanged:
    print "Saving configuration ..."
    AdminConfig.save()

else:
    AdminConfig.reset()
    print "Not Saving configuration. No Changes To Save"
