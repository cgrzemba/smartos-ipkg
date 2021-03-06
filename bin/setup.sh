#!/bin/ksh -e

set -x

ZONEPATH=$1
OUTPATH=$2
VERSION=${3:-2017.0.0.0}

if [[ -z $ZONEPATH || -z $OUTPATH ]]; then
    print -u2 "Usage: $0 <zone root> <output file> [version]"
    print -u2 "  Output is a moderately bzip2'd ZFS stream"
    exit 2
fi

PKGLIST="pkg:/compress/bzip2 pkg:/compress/gzip pkg:/developer/dtrace pkg:/developer/linker"
PKGLIST="${PKGLIST} pkg:/editor/vim pkg:/network/ftp pkg:/network/ssh pkg:/network/ssh/ssh-key"
PKGLIST="${PKGLIST} pkg:/package/pkg pkg:/service/network/ssh"
PKGLIST="${PKGLIST} pkg:/shell/bash pkg:/system/extended-system-utilities"
PKGLIST="${PKGLIST} pkg:/system/file-system/autofs pkg:/system/file-system/nfs"
PKGLIST="${PKGLIST} pkg:/system/network pkg:/system/network/routing pkg:/service/network/network-clients pkg:/security/sudo"
PKGLIST="${PKGLIST} pkg:/text/doctools"
# LDAP-Client
PKGLIST="${PKGLIST} pkg:/system/mozilla-nss pkg:/system/network/nis"
# developer tools
PKGLIST="${PKGLIST} pkg:/developer/versioning/git"
PKGLIST="${PKGLIST} pkg:/developer/documentation-tool/doxygen"
PKGLIST="${PKGLIST} pkg:/developer/gcc-5@ pkg:/developer/build/autoconf" 
PKGLIST="${PKGLIST} pkg:/network/rsync"

ZROOT=$ZONEPATH/root

echo "=== Creating root"
ZPATHSET=$(zfs list -Ho name $(dirname $ZONEPATH))
if [[ -z $ZPATHSET ]]; then
    print -u2 "$ZONEPATH is not directly in a ZFS dataset"
    exit 1
fi
zfs create $ZPATHSET/$(basename $ZONEPATH)
mkdir $ZROOT

echo "=== Creating image and doing base install"

pkg image-create -f --zone --full $ZROOT
export PKG_IMAGE=$ZROOT
pkg set-publisher -g http://pkg.openindiana.org/hipster openindiana.org
[[ -d /var/pkg/download ]] && export PKG_CACHEDIR=/var/pkg/download

pkg install --no-refresh --no-index entire@0.5.11-${VERSION}
# We pipe through cat to get the happily logable output
pkg install --no-refresh --no-index SUNWcs SUNWcsd ${PKGLIST} | cat

echo "=== Setting up SMF profiles & repository"
ln -s ns_files.xml $ZROOT/var/svc/profile/name_service.xml
ln -s generic_limited_net.xml $ZROOT/var/svc/profile/generic.xml
ln -s inetd_generic.xml $ZROOT/var/svc/profile/inetd_services.xml
ln -s platform_none.xml $ZROOT/var/svc/profile/platform.xml

cp ${ZROOT}/lib/svc/seed/nonglobal.db ${ZROOT}/etc/svc/repository.db

chmod 0600 ${ZROOT}/etc/svc/repository.db
chown root:sys ${ZROOT}/etc/svc/repository.db

echo "=== Correcting root user" 

# Make root NP rather than having an empty password
gsed -i -e "1s/^root::/root:NP:/"  ${ZROOT}/etc/shadow

echo "=== Priming first-boot configuration"

echo /usr/sbin/sysidconfig -b $ZROOT -a /lib/svc/method/sshd

echo "=== Archiving"
ZPATHFS=$(zfs list -Ho name ${ZONEPATH})
zfs snapshot ${ZPATHFS}@save
zfs send ${ZPATHFS}@save | bzip2 -c6 | pv -N "zfs send" > ${OUTPATH}
