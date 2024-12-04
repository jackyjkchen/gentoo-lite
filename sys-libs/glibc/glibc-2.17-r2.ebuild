# Copyright 2022-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION=""
HOMEPAGE=""
SRC_URI="
	https://github.com/jackyjkchen/binaries/releases/download/glibc-2.17/glibc-2.17-multilib-x86_64.tar.xz
	https://github.com/jackyjkchen/binaries/releases/download/tzdata-2024a/tzdata-2024a.tar.xz
	"

LICENSE=""
SLOT="2.2"
KEYWORDS="amd64"
IUSE="multilib +rpc"
DEPEND="sys-apps/locale-gen
	sys-libs/timezone-data"

S=${WORKDIR}/glibc-${PV}

src_unpack() {
	mkdir -p "${S}" || die
	tar -pxf "${DISTDIR}"/glibc-${PV}-multilib-x86_64.tar.xz -C "${S}" || die
}

src_prepare() {
	pushd "${S}" > /dev/null
	default
	popd > /dev/null
}

src_configure() {
	pushd "${S}" > /dev/null
	popd > /dev/null
}

src_compile() {
	pushd "${S}" > /dev/null
	popd > /dev/null
}

src_install() {
	pushd "${S}" > /dev/null
	CHOST="x86_64-glibc217-linux-gnu"
	if [[ ${CATEGORY} == cross-* ]] ; then
		mkdir -p "${ED}"/usr/${CHOST}/ || die
		cp -ax . "${ED}"/usr/${CHOST}/ || die
		find "${ED}" | grep -w 'libcrypt\|crypt.h' | xargs rm || die
		rm -v "${ED}"/usr/bin/{makedb,memusagestat}
	else
		cp -ax . "${ED}" || die
		find "${ED}" | grep -w 'libcrypt\|crypt.h' | xargs rm || die
		rm -v "${ED}"/usr/bin/{makedb,memusagestat}
	fi
	rm -rf "${ED}"/usr/share/doc
	ln -s en_US "${ED}"/usr/share/i18n/locales/C || die
	find "${ED}"/usr/share | grep -w gz | xargs gunzip || die
	mkdir -p "${ED}"/etc/env.d/ && echo 'LDPATH="include ld.so.conf.d/*.conf"' > "${ED}"/etc/env.d/00glibc || die
	popd > /dev/null
}
