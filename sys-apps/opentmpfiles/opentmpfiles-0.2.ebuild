# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit prefix

SRC_URI="https://github.com/openrc/${PN}/archive/${PV}.tar.gz ->
	${P}.tar.gz"
KEYWORDS="alpha amd64 hppa m68k sh"

DESCRIPTION="A standalone utility to process systemd-style tmpfiles.d files"
HOMEPAGE="https://github.com/openrc/opentmpfiles"

LICENSE="BSD-2"
SLOT="0"
IUSE="selinux"

RDEPEND="!<sys-apps/openrc-0.23
	selinux? ( sec-policy/selinux-base-policy )"

src_prepare() {
	default
	hprefixify tmpfiles
}
src_install() {
	emake DESTDIR="${ED}" install
	einstalldocs
	cd openrc
	for f in opentmpfiles-dev opentmpfiles-setup; do
		newconfd ${f}.confd ${f}
		newinitd ${f}.initd ${f}
	done
}

add_service() {
	local initd=$1
	local runlevel=$2

	elog "Auto-adding '${initd}' service to your ${runlevel} runlevel"
	mkdir -p "${EROOT}"etc/runlevels/${runlevel}
	ln -snf /etc/init.d/${initd} "${EROOT}"etc/runlevels/${runlevel}/${initd}
}

pkg_postinst() {
	if [[ -z $REPLACING_VERSIONS ]]; then
		add_service opentmpfiles-dev sysinit
		add_service opentmpfiles-setup boot
	fi
}
