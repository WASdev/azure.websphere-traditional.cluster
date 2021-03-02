#      Copyright (c) Microsoft Corporation.
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

def getObjectCustomProperty(object_id, propname):
    x = AdminConfig.showAttribute(object_id,'properties')
    if len(x) == 0:
        return None

    if x.startswith("["):
        propsidlist = x[1:-1].split(' ')
    else:
        propsidlist = [x]
    for id in propsidlist:
        name = AdminConfig.showAttribute(id, 'name')
        if name == propname:
            return AdminConfig.showAttribute(id, 'value')
    return None

import sys
cellName = sys.argv[0]
propName = sys.argv[1]

cell = AdminConfig.getid('/Cell:%s/' % cellName)
propValue = getObjectCustomProperty(cell, propName)
print '[{0}:{1}]'.format(propName, propValue)
