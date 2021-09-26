#!/bin/bash

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

LOG_FILE=/tmp/deployment.log

# Remove musl libc as IBM Java binaries only run on glibc
echo "$(date): Start to uninstall musl libc." > ${LOG_FILE}
output=$(apk del libc6-compat)
echo $output >> ${LOG_FILE}

# Install glibc by referencing to https://github.com/ibmruntimes/ci.docker/blob/master/ibmjava/8/jre/alpine/Dockerfile
echo "$(date): Musl libc uninstalled, start to install glibc." >> ${LOG_FILE}
output=$(apk add --no-cache --virtual .build-deps curl binutils \
    && GLIBC_VER="2.30-r0" \
    && ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" \
    && GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-8.2.1%2B20180831-1-x86_64.pkg.tar.xz" \
    && GCC_LIBS_SHA256=e4b39fb1f5957c5aab5c2ce0c46e03d30426f3b94b9992b009d417ff2d56af4d \
    && curl -fLs https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /tmp/sgerrand.rsa.pub \
    && cp /tmp/sgerrand.rsa.pub /etc/apk/keys \
    && curl -fLs ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/${GLIBC_VER}.apk \
    && apk add /tmp/${GLIBC_VER}.apk \
    && curl -fLs ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.xz \
    && echo "${GCC_LIBS_SHA256}  /tmp/gcc-libs.tar.xz" | sha256sum -c - \
    && mkdir /tmp/gcc \
    && tar -xf /tmp/gcc-libs.tar.xz -C /tmp/gcc \
    && mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib \
    && strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* \
    && apk del --purge .build-deps \
    && apk add --no-cache ca-certificates openssl \
    && rm -rf /tmp/${GLIBC_VER}.apk /tmp/gcc /tmp/gcc-libs.tar.xz /var/cache/apk/* /tmp/*.pub)
echo $output >> ${LOG_FILE}

# Define const variables for IM installation
IM_INSTALL_KIT_URL=https://public.dhe.ibm.com/ibmdl/export/pub/software/im/zips/agent.installer.linux.gtk.x86_64.zip
IM_INSTALL_KIT=/tmp/agent.installer.linux.gtk.x86_64.zip
IM_INSTALL_KIT_UNPACK=/tmp/im_installer
IM_INSTALL_DIRECTORY=/tmp/IBM/InstallationManager/V1.9
WAS_ND_VERSION_ENTITLED=ND.v90_9.0.5007
NO_PACKAGES_FOUND="No packages were found"

echo "$(date): Glibc installed, start to install IBM Installation Manager." >> ${LOG_FILE}

# Create installation directories
mkdir -p ${IM_INSTALL_KIT_UNPACK} && mkdir -p ${IM_INSTALL_DIRECTORY}

# Install IBM Installation Manager
wget -O ${IM_INSTALL_KIT} ${IM_INSTALL_KIT_URL} -q
unzip -q ${IM_INSTALL_KIT} -d ${IM_INSTALL_KIT_UNPACK}
output=$(${IM_INSTALL_KIT_UNPACK}/userinstc -log im_install_log -acceptLicense -installationDirectory ${IM_INSTALL_DIRECTORY})
echo $output >> ${LOG_FILE}

echo "$(date): IBM Installation Manager installed, start to check entitlement." >> ${LOG_FILE}

# Save credentials to a secure storage file
output=$(${IM_INSTALL_DIRECTORY}/eclipse/tools/imutilsc saveCredential -secureStorageFile storage_file \
    -userName "$IBM_USER_ID" -userPassword "$IBM_USER_PWD" -passportAdvantage)
echo $output >> ${LOG_FILE}

# Check whether IBMid is entitled or not
if [ $? -ne 0 ]; then
    echo "Cannot connect to Passport Advantage while saving the credential to the secure storage file." >> ${LOG_FILE}
fi

result=0
output=$(${IM_INSTALL_DIRECTORY}/eclipse/tools/imcl listAvailablePackages -cPA -secureStorageFile storage_file)
if echo $output | grep -q "$WAS_ND_VERSION_ENTITLED"; then
    echo "Entitled" >> ${LOG_FILE}
else
    result=1
    if echo $output | grep -q "$NO_PACKAGES_FOUND"; then
        echo "Undefined" >> ${LOG_FILE}
        echo "No WebSphere Application Server installation packages were found. This is likely due to a temporary issue with the installation repository. Try again and open an IBM Support issue if the problem persists."
    else
        echo "Unentitled" >> ${LOG_FILE}
        echo "The provided IBM ID does not have entitlement to install WebSphere Application Server. Please contact the primary or secondary contacts for your IBM Passport Advantage site to grant you access or follow steps at IBM eCustomer Care (https://ibm.biz/IBMidEntitlement) for further assistance."
    fi
fi

# Remove temporary files
rm -rf storage_file && rm -rf im_install_log

echo "$(date): Entitlement check completed." >> ${LOG_FILE}

# Output outputs
errInfo="Unentitled user"
outputJson=$(jq -n -c --arg errInfo $errInfo '{test: $errInfo}')
echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH

[ $result -eq 1 ] && exit 1
